import
  macros, strutils, options, math, json, tables, uri, strformat

from os import DirSep, AltSep

import
  nimcrypto, stint, httputils, chronicles, chronos,
  json_rpc/[rpcclient, jsonmarshal], stew/byteutils, eth/keys,
  web3/[ethtypes, conversions, ethhexstrings, transaction_signing, encoding]

template sourceDir: string = currentSourcePath.rsplit({DirSep, AltSep}, 1)[0]

## Generate client convenience marshalling wrappers from forward declarations
createRpcSigs(RpcClient, sourceDir & "/web3/ethcallsigs.nim")

export UInt256, Int256, Uint128, Int128
export ethtypes, conversions, encoding

type
  Web3* = ref object
    provider*: RpcClient
    subscriptions*: Table[string, Subscription]
    defaultAccount*: Address
    privateKey*: Option[PrivateKey]
    lastKnownNonce*: Option[Nonce]
    onDisconnect*: proc() {.gcsafe, raises: [Defect].}

  Sender*[T] = ref object
    web3*: Web3
    contractAddress*: Address

  EncodeResult* = tuple[dynamic: bool, data: string]

  SubscriptionEventHandler* = proc (j: JsonNode) {.gcsafe, raises: [Defect].}
  SubscriptionErrorHandler* = proc (err: CatchableError) {.gcsafe, raises: [Defect].}

  BlockHeaderHandler* = proc (b: BlockHeader) {.gcsafe, raises: [Defect].}

  Subscription* = ref object
    id*: string
    web3*: Web3
    eventHandler*: SubscriptionEventHandler
    errorHandler*: SubscriptionErrorHandler
    pendingEvents: seq[JsonNode]
    historicalEventsProcessed: bool
    removed: bool

  ContractCallBase = ref object of RootObj
    web3: Web3
    data: string
    to: Address
    value: UInt256

  ContractCall*[T] = ref object of ContractCallBase

proc handleSubscriptionNotification(w: Web3, j: JsonNode) =
  let s = w.subscriptions.getOrDefault(j{"subscription"}.getStr())
  if not s.isNil and not s.removed:
    if s.historicalEventsProcessed:
      s.eventHandler(j{"result"})
    else:
      s.pendingEvents.add(j)

proc newWeb3*(provider: RpcClient): Web3 =
  result = Web3(provider: provider)
  result.subscriptions = initTable[string, Subscription]()
  let r = result
  provider.setMethodHandler("eth_subscription") do(j: JsonNode):
    r.handleSubscriptionNotification(j)

proc newWeb3*(
    uri: string, getHeaders: GetJsonRpcRequestHeaders = nil):
    Future[Web3] {.async.} =
  let u = parseUri(uri)
  var provider: RpcClient
  case u.scheme
  of "http", "https":
    let p = newRpcHttpClient(getHeaders = getHeaders)
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

proc getHistoricalEvents(s: Subscription, options: JsonNode) {.async.} =
  try:
    let logs = await s.web3.provider.eth_getLogs(options)
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

proc subscribe*(w: Web3, name: string, options: JsonNode,
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
  let id = if options.isNil:
    await w.provider.eth_subscribe(name)
  else:
    await w.provider.eth_subscribe(name, options)

  result = Subscription(id: id,
                        web3: w,
                        eventHandler: eventHandler,
                        errorHandler: errorHandler)

  w.subscriptions[id] = result

proc subscribeForLogs*(w: Web3, options: JsonNode,
                       logsHandler: SubscriptionEventHandler,
                       errorHandler: SubscriptionErrorHandler,
                       withHistoricEvents = true): Future[Subscription]
                      {.async.} =
  result = await subscribe(w, "logs", options, logsHandler, errorHandler)
  if withHistoricEvents:
    discard getHistoricalEvents(result, options)
  else:
    result.historicalEventsProcessed = true

proc subscribeForBlockHeaders*(w: Web3,
                               blockHeadersCallback: proc(b: BlockHeader) {.gcsafe, raises: [Defect].},
                               errorHandler: SubscriptionErrorHandler): Future[Subscription]
                              {.async.} =
  proc eventHandler(json: JsonNode) {.gcsafe, raises: [Defect].} =
    var blk: BlockHeader
    try:
      fromJson(json, "result", blk)
      blockHeadersCallback(blk)
    except CatchableError as err:
      errorHandler(err[])

  # `nil` options so that we skip sending an empty `{}` object as an extra argument
  # to geth for `newHeads`: https://github.com/ethereum/go-ethereum/issues/21588
  result = await subscribe(w, "newHeads", nil, eventHandler, errorHandler)
  result.historicalEventsProcessed = true

proc unsubscribe*(s: Subscription): Future[void] {.async.} =
  s.web3.subscriptions.del(s.id)
  s.removed = true
  discard await s.web3.provider.eth_unsubscribe(s.id)

proc unknownType() = discard # Used for informative errors

template typeSignature(T: typedesc): string =
  when T is string:
    "string"
  elif T is DynamicBytes:
    "bytes"
  elif T is FixedBytes:
    "bytes" & $T.N
  elif T is StUint:
    "uint" & $T.bits
  elif T is Address:
    "address"
  elif T is Bool:
    "bool"
  else:
    unknownType(T)

proc initContractCall[T](web3: Web3, data: string, to: Address): ContractCall[T] {.inline.} =
  ContractCall[T](web3: web3, data: data, to: to)

type
  InterfaceObjectKind = enum
    function, constructor, event
  MutabilityKind = enum
    pure, view, nonpayable, payable
  FunctionInputOutput = object
    name: string
    typ: NimNode
  EventInput = object
    name: string
    typ: NimNode
    indexed: bool
  FunctionObject = object
    name: string
    stateMutability: MutabilityKind
    inputs: seq[FunctionInputOutput]
    outputs: seq[FunctionInputOutput]
  ConstructorObject = object
    stateMutability: MutabilityKind
    inputs: seq[FunctionInputOutput]
    outputs: seq[FunctionInputOutput]
  EventObject = object
    name: string
    inputs: seq[EventInput]
    anonymous: bool

  InterfaceObject = object
    case kind: InterfaceObjectKind
    of function: functionObject: FunctionObject
    of constructor: constructorObject: ConstructorObject
    of event: eventObject: EventObject

proc joinStrings(s: varargs[string]): string = join(s)

proc getSignature(function: FunctionObject | EventObject): NimNode =
  result = newCall(bindSym"joinStrings")
  result.add(newLit(function.name & "("))
  for i, input in function.inputs:
    result.add(newCall(bindSym"typeSignature", input.typ))
    if i != function.inputs.high:
      result.add(newLit(","))
  result.add(newLit(")"))
  result = newCall(ident"static", result)

proc addAddressAndSignatureToOptions(options: JsonNode, address: Address, signature: string): JsonNode =
  result = options
  if result.isNil:
    result = newJObject()
  if "address" notin result:
    result["address"] = %address
  var topics = result{"topics"}
  if topics.isNil:
    topics = newJArray()
    result["topics"] = topics
  topics.elems.insert(%signature, 0)

proc parseContract(body: NimNode): seq[InterfaceObject] =
  proc parseOutputs(outputNode: NimNode): seq[FunctionInputOutput] =
    result.add FunctionInputOutput(typ: (if outputNode.kind == nnkEmpty: ident"void" else: outputNode))

  proc parseInputs(inputNodes: NimNode): seq[FunctionInputOutput] =
    for i in 1..<inputNodes.len:
      let input = inputNodes[i]
      input.expectKind(nnkIdentDefs)
      let typ = input[^2]
      for j in 0 .. input.len - 3:
        let arg = input[j]
        result.add(FunctionInputOutput(
          name: $arg,
          typ: typ,
        ))

  proc parseEventInputs(inputNodes: NimNode): seq[EventInput] =
    for i in 1..<inputNodes.len:
      let input = inputNodes[i]
      input.expectKind(nnkIdentDefs)
      let typ = input[^2]
      for j in 0 .. input.len - 3:
        let arg = input[j]
        case typ.kind:
        of nnkBracketExpr:
          if $typ[0] == "indexed":
            result.add EventInput(
              name: $arg,
              typ: typ[1],
              indexed: true
            )
          else:
            result.add EventInput(name: $arg, typ: typ)
        else:
          result.add EventInput(name: $arg, typ: typ)

  var
    constructor: Option[ConstructorObject]
    functions: seq[FunctionObject]
    events: seq[EventObject]
  for procdef in body:
    doAssert(procdef.kind == nnkProcDef,
      "Contracts can only be built with procedures")
    let
      isconstructor = procdef[4].findChild(it.strVal == "constructor") != nil
      isevent = procdef[4].findChild(it.strVal == "event") != nil
    doAssert(not (isconstructor and constructor.isSome),
      "Contract can only have a single constructor")
    doAssert(not (isconstructor and isevent),
      "Can't be both event and constructor")
    if not isevent:
      let
        ispure = procdef[4].findChild(it.strVal == "pure") != nil
        isview = procdef[4].findChild(it.strVal == "view") != nil
        ispayable = procdef[4].findChild(it.strVal == "payable") != nil
      doAssert(not (ispure and isview),
        "can't be both `pure` and `view`")
      doAssert(not ((ispure or isview) and ispayable),
        "can't be both `pure` or `view` while being `payable`")
      if isconstructor:
        constructor = some(ConstructorObject(
          stateMutability: if ispure: pure elif isview: view elif ispayable: payable else: nonpayable,
          inputs: parseInputs(procdef[3]),
          outputs: parseOutputs(procdef[3][0])
        ))
      else:
        functions.add FunctionObject(
          name: procdef[0].strVal,
          stateMutability: if ispure: pure elif isview: view elif ispayable: payable else: nonpayable,
          inputs: parseInputs(procdef[3]),
          outputs: parseOutputs(procdef[3][0])
        )
    else:
      let isanonymous = procdef[4].findChild(it.strVal == "anonymous") != nil
      doAssert(procdef[3][0].kind == nnkEmpty,
        "Events can't have return values")
      events.add EventObject(
        name: procdef[0].strVal,
        inputs: parseEventInputs(procdef[3]),
        anonymous: isanonymous
      )

  if constructor.isSome:
    result.add InterfaceObject(kind: InterfaceObjectKind.constructor, constructorObject: constructor.unsafeGet)
  for function in functions:
    result.add InterfaceObject(kind: InterfaceObjectKind.function, functionObject: function)
  for event in events:
    result.add InterfaceObject(kind: InterfaceObjectKind.event, eventObject: event)

macro contract*(cname: untyped, body: untyped): untyped =
  var objects = parseContract(body)
  result = newStmtList()
  let
    address = ident "address"
    client = ident "client"
    receipt = genSym(nskForVar)
    receiver = ident "receiver"
    eventListener = ident "eventListener"
  result.add quote do:
    type
      `cname`* = object

  for obj in objects:
    case obj.kind:
    of function:
      let
        signature = getSignature(obj.functionObject)
        procName = ident obj.functionObject.name
        senderName = ident "sender"
        output = if obj.functionObject.outputs.len != 1:
            ident "void"
          else:
            obj.functionObject.outputs[0].typ
      var
        encodedParams = genSym(nskVar)#newLit("")
        offset = genSym(nskVar)
        dataBuf = genSym(nskVar)
        encodings = genSym(nskVar)
        encoder = newStmtList()
      encoder.add quote do:
        var
          `offset` = 0
          `encodedParams` = ""
          `dataBuf` = ""
          `encodings`: seq[EncodeResult]
      for input in obj.functionObject.inputs:
        let inputName = ident input.name
        encoder.add quote do:
          let encoding = encode(`inputName`)
          `offset` += (if encoding.dynamic:
            32
          else:
            encoding.data.len div 2)
          `encodings`.add encoding
      encoder.add quote do:
        for encoding in `encodings`:
          if encoding.dynamic:
            `encodedParams` &= `offset`.toHex(64).toLower
            `dataBuf` &= encoding.data
          else:
            `encodedParams` &= encoding.data
          `offset` += encoding.data.len div 2

        `encodedParams` &= `dataBuf`
      var procDef = quote do:
        proc `procName`*(`senderName`: Sender[`cname`]): ContractCall[`output`] =
          discard
      for input in obj.functionObject.inputs:
        procDef[3].add nnkIdentDefs.newTree(
          ident input.name,
          input.typ,
          newEmptyNode()
        )
      procDef[6].add quote do:
        `encoder`
        return initContractCall[`output`](
            `senderName`.web3,
            ($keccak256.digest(`signature`))[0..<8].toLower & `encodedParams`,
            `senderName`.contractAddress)

      result.add procDef
    of event:
      if not obj.eventObject.anonymous:
        let callbackIdent = ident "callback"
        let jsonIdent = ident "j"
        var
          params = nnkFormalParams.newTree(newEmptyNode())
          paramsWithRawData = nnkFormalParams.newTree(newEmptyNode())

          argParseBody = newStmtList()
          i = 1
          call = nnkCall.newTree(callbackIdent)
          callWithRawData = nnkCall.newTree(callbackIdent)
          offset = ident "offset"
          inputData = ident "inputData"

        var offsetInited = false

        for input in obj.eventObject.inputs:
          let param = nnkIdentDefs.newTree(
            ident input.name,
            input.typ,
            newEmptyNode()
          )
          params.add param
          paramsWithRawData.add param
          let
            argument = genSym(nskVar)
            kind = input.typ
          if input.indexed:
            argParseBody.add quote do:
              var `argument`: `kind`
              discard decode(strip0xPrefix(`jsonIdent`["topics"][`i`].getStr), 0, `argument`)
            i += 1
          else:
            if not offsetInited:
              argParseBody.add quote do:
                var `inputData` = strip0xPrefix(`jsonIdent`["data"].getStr)
                var `offset` = 0

              offsetInited = true

            argParseBody.add quote do:
              var `argument`: `kind`
              `offset` += decode(`inputData`, `offset`, `argument`)
          call.add argument
          callWithRawData.add argument
        let
          eventName = obj.eventObject.name
          cbident = ident eventName
          procTy = nnkProcTy.newTree(params, newEmptyNode())
          signature = getSignature(obj.eventObject)

        # generated with dumpAstGen - produces "{.raises: [Defect], gcsafe.}"
        let pragmas = nnkPragma.newTree(
          nnkExprColonExpr.newTree(
            newIdentNode("raises"),
            nnkBracket.newTree(
              newIdentNode("Defect")
            )
          ),
          newIdentNode("gcsafe")
        )

        procTy[1] = pragmas

        callWithRawData.add jsonIdent
        paramsWithRawData.add nnkIdentDefs.newTree(
          jsonIdent,
          bindSym "JsonNode",
          newEmptyNode()
        )

        let procTyWithRawData = nnkProcTy.newTree(paramsWithRawData, newEmptyNode())
        procTyWithRawData[1] = pragmas

        result.add quote do:
          type `cbident` = object

          template eventTopic*(T: type `cbident`): string =
            "0x" & toLowerAscii($keccak256.digest(`signature`))

          proc subscribe(s: Sender[`cname`],
                         t: type `cbident`,
                         options: JsonNode,
                         `callbackIdent`: `procTy`,
                         errorHandler: SubscriptionErrorHandler,
                         withHistoricEvents = true): Future[Subscription] =
            let options = addAddressAndSignatureToOptions(options, s.contractAddress, eventTopic(`cbident`))

            proc eventHandler(`jsonIdent`: JsonNode) {.gcsafe, raises: [Defect].} =
              try:
                `argParseBody`
                `call`
              except CatchableError as err:
                errorHandler err[]

            s.web3.subscribeForLogs(options, eventHandler, errorHandler, withHistoricEvents)

          proc subscribe(s: Sender[`cname`],
                         t: type `cbident`,
                         options: JsonNode,
                         `callbackIdent`: `procTyWithRawData`,
                         errorHandler: SubscriptionErrorHandler,
                         withHistoricEvents = true): Future[Subscription] =
            let options = addAddressAndSignatureToOptions(options, s.contractAddress, eventTopic(`cbident`))

            proc eventHandler(`jsonIdent`: JsonNode) {.gcsafe, raises: [Defect].} =
              try:
                `argParseBody`
                `callWithRawData`
              except CatchableError as err:
                errorHandler err[]

            s.web3.subscribeForLogs(options, eventHandler, errorHandler, withHistoricEvents)

    else:
      discard

  when defined(debugMacros) or defined(debugWeb3Macros):
    echo result.repr

proc getJsonLogs*(s: Sender,
                  EventName: type,
                  fromBlock, toBlock = none(RtBlockIdentifier),
                  blockHash = none(BlockHash)): Future[JsonNode] =
  mixin eventTopic

  var options = newJObject()
  options["address"] = %s.contractAddress
  var topics = newJArray()
  topics.elems.insert(%eventTopic(EventName), 0)
  options["topics"] = topics
  if blockHash.isSome:
    doAssert fromBlock.isNone and toBlock.isNone
    options["blockhash"] = %blockHash.unsafeGet
  else:
    if fromBlock.isSome:
      options["fromBlock"] = %fromBlock.unsafeGet
    if toBlock.isSome:
      options["toBlock"] = %toBlock.unsafeGet

  s.web3.provider.eth_getLogs(options)

proc nextNonce*(web3: Web3): Future[Nonce] {.async.} =
  if web3.lastKnownNonce.isSome:
    inc web3.lastKnownNonce.get
    return web3.lastKnownNonce.get
  else:
    let fromAddress = web3.privateKey.get().toPublicKey().toCanonicalAddress.Address
    result = int(await web3.provider.eth_getTransactionCount(fromAddress, "latest"))
    web3.lastKnownNonce = some result

proc send*(web3: Web3, c: EthSend): Future[TxHash] {.async.} =
  if web3.privateKey.isSome():
    var cc = c
    if cc.nonce.isNone:
      cc.nonce = some(await web3.nextNonce())
    let t = "0x" & encodeTransaction(cc, web3.privateKey.get())
    return await web3.provider.eth_sendRawTransaction(t)
  else:
    return await web3.provider.eth_sendTransaction(c)

proc send*(c: ContractCallBase,
           value = 0.u256,
           gas = 3000000'u64,
           gasPrice = 0): Future[TxHash] {.async.} =
  let
    web3 = c.web3
    gasPrice = if web3.privateKey.isSome() or gasPrice != 0: some(gasPrice)
               else: none(int)
    nonce = if web3.privateKey.isSome(): some(await web3.nextNonce())
            else: none(Nonce)

    cc = EthSend(
      data: "0x" & c.data,
      source: web3.defaultAccount,
      to: some(c.to),
      gas: some(Quantity(gas)),
      value: some(value),
      nonce: nonce,
      gasPrice: gasPrice)

  return await web3.send(cc)

proc call*[T](c: ContractCall[T],
              value = 0.u256,
              gas = 3000000'u64,
              blockNumber = high(uint64)): Future[T] {.async.} =
  var cc: EthCall
  cc.data = some("0x" & c.data)
  cc.source = some(c.web3.defaultAccount)
  cc.to = c.to
  cc.gas = some(Quantity(gas))
  cc.value = some(value)
  let response = strip0xPrefix:
    if blockNumber != high(uint64):
      await c.web3.provider.eth_call(cc, &"0x{blockNumber:X}")
    else:
      await c.web3.provider.eth_call(cc, "latest")

  if response.len > 0:
    var res: T
    discard decode(response, 0, res)
    return res
  else:
    raise newException(CatchableError, "No response from the Web3 provider")

proc getMinedTransactionReceipt*(web3: Web3, tx: TxHash): Future[ReceiptObject] {.async.} =
  ## Returns the receipt for the transaction. Waits for it to be mined if necessary.
  # TODO: Potentially more optimal solution is to subscribe and wait for appropriate
  # notification. Now we're just polling every 500ms which should be ok for most cases.
  var r: Option[ReceiptObject]
  while r.isNone:
    r = await web3.provider.eth_getTransactionReceipt(tx)
    if r.isNone:
      await sleepAsync(500.milliseconds)
  result = r.get

proc exec*[T](c: ContractCall[T], value = 0.u256, gas = 3000000'u64): Future[T] {.async.} =
  let h = await c.send(value, gas)
  let receipt = await c.web3.getMinedTransactionReceipt(h)

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
  Sender[T](web3: web3, contractAddress: toAddress)

proc isDeployed*(s: Sender, atBlock: RtBlockIdentifier): Future[bool] {.async.} =
  let
    codeFut = case atBlock.kind
      of bidNumber:
        s.web3.provider.eth_getCode(s.contractAddress, atBlock.number)
      of bidAlias:
        s.web3.provider.eth_getCode(s.contractAddress, atBlock.alias)
    code = await codeFut

  # TODO: Check that all methods of the contract are present by
  #       looking for their ABI signatures within the code:
  #       https://ethereum.stackexchange.com/questions/11856/how-to-detect-from-web3-if-method-exists-on-a-deployed-contract
  return code.len > 0

proc subscribe*(s: Sender, t: typedesc, cb: proc): Future[Subscription] {.inline.} =
  subscribe(s, t, newJObject(), cb, SubscriptionErrorHandler nil)

proc `$`*(b: Bool): string =
  $(StInt[256](b))
