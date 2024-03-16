# nim-web3
# Copyright (c) 2019-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[options, json, tables, uri, macros],
  stint, httputils, chronos,
  json_rpc/[rpcclient, jsonmarshal],
  json_rpc/private/jrpc_sys,
  eth/keys,
  chronos/apps/http/httpclient,
  web3/[eth_api_types, conversions, transaction_signing, encoding, contract_dsl],
  web3/eth_api

from eth/common/eth_types import ChainId

export UInt256, Int256, Uint128, Int128, ChainId
export
  eth_api_types,
  conversions,
  encoding,
  contract_dsl,
  HttpClientFlag,
  HttpClientFlags,
  eth_api

type
  Web3* = ref object
    provider*: RpcClient
    subscriptions*: Table[string, Subscription]
    defaultAccount*: Address
    privateKey*: Option[PrivateKey]
    lastKnownNonce*: Option[Quantity]
    onDisconnect*: proc() {.gcsafe, raises: [].}

  Web3SenderImpl = ref object
    web3*: Web3
    contractAddress*: Address

  Web3AsyncSenderImpl = ref object
    web3*: Web3
    contractAddress*: Address
    defaultAccount*: Address
    value*: UInt256
    gas*: uint64
    gasPrice*: int
    chainId*: Option[ChainId]
    blockNumber*: BlockNumber

  Sender*[T] = ContractInstance[T, Web3SenderImpl]
  AsyncSender*[T] = ContractInstance[T, Web3AsyncSenderImpl]

  SubscriptionEventHandler* = proc (j: JsonString) {.gcsafe, raises: [].}
  SubscriptionErrorHandler* = proc (err: CatchableError) {.gcsafe, raises: [].}

  BlockHeaderHandler* = proc (b: BlockHeader) {.gcsafe, raises: [].}

  Subscription* = ref object
    id*: string
    web3*: Web3
    eventHandler*: SubscriptionEventHandler
    errorHandler*: SubscriptionErrorHandler
    pendingEvents: seq[JsonString]
    historicalEventsProcessed: bool
    removed: bool

  ContractInvocation*[TResult, TSender] = object
    data*: seq[byte]
    sender*: TSender

proc getValue(params: RequestParamsRx, field: string, FieldType: type):
        Result[FieldType, string] {.gcsafe, raises: [].} =
  try:
    for param in params.named:
      if param.name == field:
        when FieldType is JsonString:
          return ok(param.value)
        else:
          let val = JrpcConv.decode(param.value.string, FieldType)
          return ok(val)
  except CatchableError as exc:
    return err(exc.msg)

proc toJsonString(params: RequestParamsRx):
       Result[JsonString, string] {.gcsafe, raises: [].} =
  try:
    let res = JrpcSys.encode(params.toTx)
    return ok(res.JsonString)
  except CatchableError as exc:
    return err(exc.msg)

proc handleSubscriptionNotification(w: Web3, params: RequestParamsRx):
                                Result[void, string] {.gcsafe, raises: [].} =
  let subs = params.getValue("subscription", string).valueOr:
    return err(error)
  let s = w.subscriptions.getOrDefault(subs)
  if not s.isNil and not s.removed:
    if s.historicalEventsProcessed:
      let res = params.getValue("result", JsonString).valueOr:
        return err(error)
      s.eventHandler(res)
    else:
      let par = params.toJsonString().valueOr:
        return err(error)
      s.pendingEvents.add(par)

  ok()

proc newWeb3*(provider: RpcClient): Web3 =
  result = Web3(provider: provider)
  result.subscriptions = initTable[string, Subscription]()
  let w3 = result

  provider.onProcessMessage = proc(client: RpcClient, line: string):
                                Result[bool, string] {.gcsafe, raises: [].} =
    try:
      let req = JrpcSys.decode(line, RequestRx)
      if req.`method`.isNone:
        # fallback to regular onProcessMessage
        return ok(true)

      # This could be subscription notification
      let name = req.`method`.get
      if name == "eth_subscription":
        if req.params.kind != rpNamed:
          return ok(false)
        w3.handleSubscriptionNotification(req.params).isOkOr:
          return err(error)

      # don't fallback, just quit onProcessMessage
      return ok(false)
    except CatchableError as exc:
      return err(exc.msg)

proc newWeb3*(
    uri: string,
    getHeaders: GetJsonRpcRequestHeaders = nil,
    httpFlags: HttpClientFlags = {}):
    Future[Web3] {.async.} =
  let u = parseUri(uri)
  var provider: RpcClient
  case u.scheme
  of "http", "https":
    let p = newRpcHttpClient(getHeaders = getHeaders,
                             flags = httpFlags)
    await p.connect(uri)
    provider = p
  of "ws", "wss":
    let p = newRpcWebSocketClient(getHeaders = getHeaders)
    await p.connect(uri)
    provider = p
  else:
    raise newException(CatchableError, "Unknown web3 url scheme")
  result = newWeb3(provider)
  let r = result
  provider.onDisconnect = proc() =
    r.subscriptions.clear()
    if not r.onDisconnect.isNil:
      r.onDisconnect()

proc close*(web3: Web3): Future[void] = web3.provider.close()

proc getHistoricalEvents(s: Subscription, options: FilterOptions) {.async.} =
  try:
    let logs = await s.web3.provider.eth_getJsonLogs(options)
    for l in logs:
      if s.removed: break
      s.eventHandler(l)
    s.historicalEventsProcessed = true
    var i = 0
    while i < s.pendingEvents.len: # Mind reentrancy
      if s.removed: break
      s.eventHandler(s.pendingEvents[i])
      inc i
    s.pendingEvents = @[]
  except CatchableError as e:
    echo "Caught exception in getHistoricalEvents: ", e.msg
    echo e.getStackTrace()

proc subscribe*(w: Web3, name: string, options: Option[FilterOptions],
                eventHandler: SubscriptionEventHandler,
                errorHandler: SubscriptionErrorHandler): Future[Subscription]
               {.async.} =
  ## Sets up a new subsciption using the `eth_subscribe` RPC call.
  ##
  ## May raise a `CatchableError` if the subscription is not established.
  ##
  ## Once the subscription is established, the `eventHandler` callback
  ## will be executed for each event of interest.
  ##
  ## In case of any errors or illegal behavior of the remote RPC node,
  ## the `errorHandler` will be executed with relevant information about
  ## the error.

  # Don't send an empty `{}` object as an extra argument if there are no options
  let id = if options.isNone:
    await w.provider.eth_subscribe(name)
  else:
    await w.provider.eth_subscribe(name, options.get)

  result = Subscription(id: id,
                        web3: w,
                        eventHandler: eventHandler,
                        errorHandler: errorHandler)

  w.subscriptions[id] = result

proc subscribeForLogs*(w: Web3, options: FilterOptions,
                       logsHandler: SubscriptionEventHandler,
                       errorHandler: SubscriptionErrorHandler,
                       withHistoricEvents = true): Future[Subscription]
                      {.async.} =
  result = await subscribe(w, "logs", some(options), logsHandler, errorHandler)
  if withHistoricEvents:
    discard getHistoricalEvents(result, options)
  else:
    result.historicalEventsProcessed = true

proc addAddressAndSignatureToOptions(options: FilterOptions, address: Address, topic: Topic): FilterOptions =
  result = options
  if result.address.kind == slkNull:
    result.address = AddressOrList(kind: slkSingle, single: address)
  result.topics.insert(TopicOrList(kind: slkSingle, single: topic), 0)

proc subscribeForLogs*(s: Web3SenderImpl, options: FilterOptions,
                       topic: Topic,
                       logsHandler: SubscriptionEventHandler,
                       errorHandler: SubscriptionErrorHandler,
                       withHistoricEvents = true): Future[Subscription] =
  let options = addAddressAndSignatureToOptions(options, s.contractAddress, topic)
  s.web3.subscribeForLogs(options, logsHandler, errorHandler, withHistoricEvents)

proc subscribeForBlockHeaders*(w: Web3,
                               blockHeadersCallback: proc(b: BlockHeader) {.gcsafe, raises: [].},
                               errorHandler: SubscriptionErrorHandler): Future[Subscription]
                              {.async.} =
  proc eventHandler(json: JsonString) {.gcsafe, raises: [].} =

    try:
      let blk = JrpcConv.decode(json.string, BlockHeader)
      blockHeadersCallback(blk)
    except CatchableError as err:
      errorHandler(err[])

  # `nil` options so that we skip sending an empty `{}` object as an extra argument
  # to geth for `newHeads`: https://github.com/ethereum/go-ethereum/issues/21588
  result = await subscribe(w, "newHeads", none(FilterOptions), eventHandler, errorHandler)
  result.historicalEventsProcessed = true

proc unsubscribe*(s: Subscription): Future[void] {.async.} =
  s.web3.subscriptions.del(s.id)
  s.removed = true
  discard await s.web3.provider.eth_unsubscribe(s.id)

proc getJsonLogs(s: Web3SenderImpl, topic: Topic,
                 fromBlock = none(RtBlockIdentifier),
                 toBlock = none(RtBlockIdentifier),
                 blockHash = none(BlockHash)): Future[seq[JsonString]] =

  var options = FilterOptions(
    address: AddressOrList(kind: slkSingle, single: s.contractAddress),
    topics: @[TopicOrList(kind: slkSingle, single: topic)],
  )

  if blockHash.isSome:
    doAssert fromBlock.isNone and toBlock.isNone
    options.blockHash = blockHash
  else:
    options.fromBlock = fromBlock
    options.toBlock = toBlock

  # TODO: optimize it instead of double conversion
  s.web3.provider.eth_getJsonLogs(options)

proc getJsonLogs*[TContract](s: Sender[TContract],
                  EventName: type,
                  fromBlock = none(RtBlockIdentifier),
                  toBlock = none(RtBlockIdentifier),
                  blockHash = none(BlockHash)): Future[seq[JsonString]] {.inline.} =
  mixin eventTopic
  getJsonLogs(s.sender, eventTopic(EventName), fromBlock, toBlock, blockHash)

proc nextNonce*(web3: Web3): Future[Quantity] {.async.} =
  if web3.lastKnownNonce.isSome:
    inc web3.lastKnownNonce.get
    return web3.lastKnownNonce.get
  else:
    let fromAddress = web3.privateKey.get().toPublicKey().toCanonicalAddress.Address
    result = await web3.provider.eth_getTransactionCount(fromAddress, "latest")
    web3.lastKnownNonce = some result

proc send*(web3: Web3, c: EthSend): Future[TxHash] {.async.} =
  if web3.privateKey.isSome():
    var cc = c
    if cc.nonce.isNone:
      cc.nonce = some(await web3.nextNonce())
    let t = encodeTransaction(cc, web3.privateKey.get())
    return await web3.provider.eth_sendRawTransaction(t)
  else:
    return await web3.provider.eth_sendTransaction(c)

proc send*(web3: Web3, c: EthSend, chainId: ChainId): Future[TxHash] {.async.} =
  doAssert(web3.privateKey.isSome())
  var cc = c
  if cc.nonce.isNone:
    cc.nonce = some(await web3.nextNonce())
  let t = encodeTransaction(cc, web3.privateKey.get(), chainId)
  return await web3.provider.eth_sendRawTransaction(t)

proc sendData(web3: Web3,
              contractAddress: Address,
              defaultAccount: Address,
              data: seq[byte],
              value: UInt256,
              gas: uint64,
              gasPrice: int,
              chainId = none(ChainId)): Future[TxHash] {.async.} =
  let
    gasPrice = if web3.privateKey.isSome() or gasPrice != 0: some(gasPrice.Quantity)
               else: none(Quantity)
    nonce = if web3.privateKey.isSome(): some(await web3.nextNonce())
            else: none(Quantity)

    cc = EthSend(
      data: data,
      `from`: defaultAccount,
      to: some(contractAddress),
      gas: some(Quantity(gas)),
      value: some(value),
      nonce: nonce,
      gasPrice: gasPrice,
    )

  if chainId.isNone:
    return await web3.send(cc)
  else:
    return await web3.send(cc, chainId.get)

proc send*[T](c: ContractInvocation[T, Web3SenderImpl],
           value = 0.u256,
           gas = 3000000'u64,
           gasPrice = 0): Future[TxHash] =
  sendData(c.sender.web3, c.sender.contractAddress, c.sender.web3.defaultAccount, c.data, value, gas, gasPrice)

proc send*[T](c: ContractInvocation[T, Web3SenderImpl],
           chainId: ChainId,
           value = 0.u256,
           gas = 3000000'u64,
           gasPrice = 0): Future[TxHash] =
  sendData(c.sender.web3, c.sender.contractAddress, c.sender.web3.defaultAccount, c.data, value, gas, gasPrice, some(chainId))

proc callAux(
    web3: Web3,
    contractAddress: Address,
    defaultAccount: Address,
    data: seq[byte],
    value = 0.u256,
    gas = 3000000'u64,
    blockNumber = high(BlockNumber)): Future[seq[byte]] {.async.} =
  var cc: EthCall
  cc.data = some(data)
  cc.source = some(defaultAccount)
  cc.to = some(contractAddress)
  cc.gas = some(Quantity(gas))
  cc.value = some(value)
  result =
    if blockNumber != high(BlockNumber):
      await web3.provider.eth_call(cc, blockId(blockNumber))
    else:
      await web3.provider.eth_call(cc, "latest")

proc call*[T](
    c: ContractInvocation[T, Web3SenderImpl],
    value = 0.u256,
    gas = 3000000'u64,
    blockNumber = high(BlockNumber)): Future[T] {.async.} =
  let response = await callAux(c.sender.web3, c.sender.contractAddress, c.sender.web3.defaultAccount, c.data, value, gas, blockNumber)
  if response.len > 0:
    discard decode(response, 0, 0, result)
  else:
    raise newException(CatchableError, "No response from the Web3 provider")

proc getMinedTransactionReceipt*(web3: Web3, tx: TxHash): Future[ReceiptObject] {.async.} =
  ## Returns the receipt for the transaction. Waits for it to be mined if necessary.
  # TODO: Potentially more optimal solution is to subscribe and wait for appropriate
  # notification. Now we're just polling every 500ms which should be ok for most cases.
  var r: ReceiptObject
  while r.isNil:
    r = await web3.provider.eth_getTransactionReceipt(tx)
    if r.isNil:
      await sleepAsync(500.milliseconds)
  result = r

proc exec*[T](c: ContractInvocation[T, Web3SenderImpl], value = 0.u256, gas = 3000000'u64): Future[T] {.async.} =
  let h = await c.send(value, gas)
  let receipt = await c.sender.web3.getMinedTransactionReceipt(h)

  # TODO: decode result from receipt


# This call will generate the `cc.data` part to call that contract method in the code below
#sendCoin(fromHex(Stuint[256], "e375b6fb6d0bf0d86707884f3952fee3977251fe"), 600.to(Stuint[256]))

# Set up a JsonRPC call to send a transaction
# The idea here is to let the Web3 object contain the RPC calls, then allow the
# above DSL to create helpers to create the EthSend object and perform the
# transaction. The current idea is to make all this reduce to something like:
# var
#   w3 = initWeb3("127.0.0.1", 8545)
#   myContract = contract:
#     <DSL>
#   myContract.sender("0x780bc7b4055941c2cb0ee10510e3fc837eb093c1").sendCoin(
#     fromHex(Stuint[256], "e375b6fb6d0bf0d86707884f3952fee3977251fe"),
#     600.to(Stuint[256])
#   )
# If the address of the contract on the chain should be part of the DSL or
# dynamically registered is still not decided.
#var cc: EthSend
#cc.source = [0x78.byte, 0x0b, 0xc7, 0xb4, 0x05, 0x59, 0x41, 0xc2, 0xcb, 0x0e, 0xe1, 0x05, 0x10, 0xe3, 0xfc, 0x83, 0x7e, 0xb0, 0x93, 0xc1]
#cc.to = some([0x0a.byte, 0x78, 0xc0, 0x8F, 0x31, 0x4E, 0xB2, 0x5A, 0x35, 0x1B, 0xfB, 0xA9, 0x03,0x21, 0xa6, 0x96, 0x04, 0x74, 0xbD, 0x79])
#cc.data = "0x90b98a11000000000000000000000000e375b6fb6d0bf0d86707884f3952fee3977251FE0000000000000000000000000000000000000000000000000000000000000258"

#var w3 = initWeb3("127.0.0.1", 8545)
#let response = waitFor w3.eth.eth_sendTransaction(cc)
#echo response

proc contractSender*(web3: Web3, T: typedesc, toAddress: Address): Sender[T] =
  Sender[T](sender: Web3SenderImpl(web3: web3, contractAddress: toAddress))

proc createMutableContractInvocation*(sender: Web3SenderImpl, ReturnType: typedesc, data: sink seq[byte]): ContractInvocation[ReturnType, Web3SenderImpl] {.inline.} =
  ContractInvocation[ReturnType, Web3SenderImpl](sender: sender, data: data)

proc createImmutableContractInvocation*(sender: Web3SenderImpl, ReturnType: typedesc, data: sink seq[byte]): ContractInvocation[ReturnType, Web3SenderImpl] {.inline.} =
  ContractInvocation[ReturnType, Web3SenderImpl](sender: sender, data: data)

proc contractInstance*(web3: Web3, T: typedesc, toAddress: Address): AsyncSender[T] =
  AsyncSender[T](sender: Web3AsyncSenderImpl(web3: web3, contractAddress: toAddress, defaultAccount: web3.defaultAccount, gas: 3000000, blockNumber: uint64.high))

proc createMutableContractInvocation*(sender: Web3AsyncSenderImpl, ReturnType: typedesc, data: sink seq[byte]) {.async.} =
  assert(sender.gas > 0)
  let h = await sendData(sender.web3, sender.contractAddress, sender.defaultAccount, data, sender.value, sender.gas, sender.gasPrice, sender.chainId)
  let receipt = await sender.web3.getMinedTransactionReceipt(h)
  discard receipt

proc createImmutableContractInvocation*(
    sender: Web3AsyncSenderImpl,
    ReturnType: typedesc,
    data: sink seq[byte]): Future[ReturnType] {.async.} =
  let response = await callAux(
    sender.web3, sender.contractAddress, sender.defaultAccount, data,
    sender.value, sender.gas, sender.blockNumber)
  if response.len > 0:
    discard decode(response, 0, 0, result)
  else:
    raise newException(CatchableError, "No response from the Web3 provider")

proc deployContractAux(web3: Web3, data: seq[byte], gasPrice = 0): Future[Address] {.async.} =
  var tr: EthSend
  tr.`from` = web3.defaultAccount
  tr.data = data
  tr.gas = Quantity(30000000).some
  if gasPrice != 0:
    tr.gasPrice = some(gasPrice.Quantity)

  let h = await web3.send(tr)
  let r = await web3.getMinedTransactionReceipt(h)
  return r.contractAddress.get

proc createContractDeployment*(web3: Web3, ContractType: typedesc, data: sink seq[byte]): Future[AsyncSender[ContractType]] {.async.} =
  let a = await deployContractAux(web3, data, gasPrice = 0)
  return contractInstance(web3, ContractType, a)

proc isDeployed*(s: Sender, atBlock: RtBlockIdentifier): Future[bool] {.async.} =
  let
    codeFut = case atBlock.kind
      of bidNumber:
        s.sender.web3.provider.eth_getCode(s.contractAddress, atBlock.number)
      of bidAlias:
        s.sender.web3.provider.eth_getCode(s.contractAddress, atBlock.alias)
    code = await codeFut

  # TODO: Check that all methods of the contract are present by
  #       looking for their ABI signatures within the code:
  #       https://ethereum.stackexchange.com/questions/11856/how-to-detect-from-web3-if-method-exists-on-a-deployed-contract
  return code.len > 0

proc subscribe*[TContract](s: Sender[TContract], t: typedesc, cb: proc): Future[Subscription] {.inline.} =
  subscribe(s, t, FilterOptions(), cb, SubscriptionErrorHandler nil)

proc copy[T](s: AsyncSender[T]): AsyncSender[T] =
  result = s
  result.sender.new()
  result.sender[] = s.sender[]

macro adjust*(s: AsyncSender, modifications: varargs[untyped]): untyped =
  ## Copies AsyncSender, modifying its properties. E.g.
  ## myContract.adjust(gas = 1000, value = 5.u256).myContractMethod()
  let cp = genSym(nskLet, "cp")
  result = quote do:
    block:
      let `cp` = copy(`s`)

  for s in modifications:
    s.expectKind(nnkExprEqExpr)
    let fieldName = s[0]
    let fieldVal = s[1]
    result[1].add quote do:
      `cp`.sender.`fieldName` = `fieldVal`
  result[1].add(cp)
