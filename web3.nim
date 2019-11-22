import macros, strutils, options, math, json, tables, uri
from os import DirSep
import
  nimcrypto, stint, httputils, chronicles, chronos, json_rpc/rpcclient,
  stew/byteutils, eth/keys

import web3/[ethtypes, ethprocs, conversions, ethhexstrings, transaction_signing]

template sourceDir: string = currentSourcePath.rsplit(DirSep, 1)[0]

## Generate client convenience marshalling wrappers from forward declarations
createRpcSigs(RpcClient, sourceDir & DirSep & "web3" & DirSep & "ethcallsigs.nim")

export UInt256, Int256, Uint128, Int128
export ethtypes, conversions

type
  Web3* = ref object
    provider*: RpcClient
    subscriptions*: Table[string, Subscription]
    defaultAccount*: Address
    privateKey*: PrivateKey
    onDisconnect*: proc() {.gcsafe.}

  Sender*[T] = ref object
    web3*: Web3
    contractAddress*: Address

  EncodeResult* = tuple[dynamic: bool, data: string]

  Subscription* = ref object
    id*: string
    web3*: Web3
    callback*: proc(j: JsonNode) {.gcsafe.}
    pendingEvents: seq[JsonNode]
    historicalEventsProcessed: bool
    removed: bool

  ContractCallBase = object {.pure, inheritable.}
    web3: Web3
    data: string
    to: Address
    value: Uint256

  ContractCall*[T] = object of ContractCallBase

proc handleSubscriptionNotification(w: Web3, j: JsonNode) =
  let s = w.subscriptions.getOrDefault(j{"subscription"}.getStr())
  if not s.isNil and not s.removed:
    if s.historicalEventsProcessed:
      try:
        s.callback(j{"result"})
      except Exception as e:
        echo "Caught exception in handleSubscriptionNotification: ", e.msg
        echo e.getStackTrace()
    else:
      s.pendingEvents.add(j)

proc newWeb3*(provider: RpcClient): Web3 =
  result = Web3(provider: provider)
  result.subscriptions = initTable[string, Subscription]()
  let r = result
  provider.setMethodHandler("eth_subscription") do(j: JsonNode):
    r.handleSubscriptionNotification(j)

proc newWeb3*(uri: string): Future[Web3] {.async.} =
  let u = parseUri(uri)
  var provider: RpcClient
  case u.scheme
  of "http", "https":
    let p = newRpcHttpClient()
    await p.connect(uri)
    provider = p
  of "ws", "wss":
    let p = newRpcWebSocketClient()
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
      s.callback(l)
    s.historicalEventsProcessed = true
    var i = 0
    while i < s.pendingEvents.len: # Mind reentrancy
      if s.removed: break
      s.callback(s.pendingEvents[i])
      inc i
    s.pendingEvents = @[]
  except Exception as e:
    echo "Caught exception in getHistoricalEvents: ", e.msg
    echo e.getStackTrace()

proc subscribe*(w: Web3, name: string, options: JsonNode, callback: proc(j: JsonNode) {.gcsafe.}): Future[Subscription] {.async.} =
  var options = options
  if options.isNil: options = newJNull()
  let id = await w.provider.eth_subscribe(name, options)
  result = Subscription(id: id, web3: w, callback: callback)
  w.subscriptions[id] = result

proc subscribeToLogs*(w: Web3, options: JsonNode, callback: proc(j: JsonNode) {.gcsafe.}): Future[Subscription] {.async.} =
  result = await subscribe(w, "logs", options, callback)
  discard getHistoricalEvents(result, options)

proc unsubscribe*(s: Subscription): Future[void] {.async.} =
  s.web3.subscriptions.del(s.id)
  s.removed = true
  discard await s.web3.provider.eth_unsubscribe(s.id)

func encode*[bits: static[int]](x: Stuint[bits]): EncodeResult =
  ## Encodes a `Stuint` to a textual representation for use in the JsonRPC
  ## `sendTransaction` call.
  (dynamic: false, data: '0'.repeat((256 - bits) div 4) & x.dumpHex)

func encode*[bits: static[int]](x: Stint[bits]): EncodeResult =
  ## Encodes a `Stint` to a textual representation for use in the JsonRPC
  ## `sendTransaction` call.
  (dynamic: false,
  data:
    if x.isNegative:
      'f'.repeat((256 - bits) div 4) & x.dumpHex
    else:
      '0'.repeat((256 - bits) div 4) & x.dumpHex
  )

func decode*(input: string, offset: int, to: var Stuint): int =
  let meaningfulLen = to.bits div 8 * 2
  to = type(to).fromHex(input[offset .. offset + meaningfulLen - 1])
  meaningfulLen

func decode*[N](input: string, offset: int, to: var Stint[N]): int =
  let meaningfulLen = N div 8 * 2
  fromHex(input[offset .. offset + meaningfulLen], to)
  meaningfulLen

func fixedEncode(a: openarray[byte]): EncodeResult =
  var padding = a.len mod 32
  if padding != 0: padding = 32 - padding
  result = (dynamic: false, data: "00".repeat(padding) & byteutils.toHex(a))

func encode*[N](b: FixedBytes[N]): EncodeResult = fixedEncode(array[N, byte](b))
func encode*(b: Address): EncodeResult = fixedEncode(array[20, byte](b))


proc skip0xPrefix(s: string): int =
  if s.len > 1 and s[0] == '0' and s[1] in {'x', 'X'}: 2
  else: 0

proc strip0xPrefix(s: string): string =
  let prefixLen = skip0xPrefix(s)
  if prefixLen != 0:
    s[prefixLen .. ^1]
  else:
    s

proc fromHexAux(s: string, result: var openarray[byte]) =
  let prefixLen = skip0xPrefix(s)
  let meaningfulLen = s.len - prefixLen
  let requiredChars = result.len * 2
  if meaningfulLen > requiredChars:
    let start = s.len - requiredChars
    hexToByteArray(s[start .. s.len - 1], result)
  elif meaningfulLen == requiredChars:
    hexToByteArray(s, result)
  else:
    raise newException(ValueError, "Short hex string (" & $meaningfulLen & ") for Bytes[" & $result.len & "]")

func fromHex*[N](x: type FixedBytes[N], s: string): FixedBytes[N] {.inline.} =
  fromHexAux(s, array[N, byte](result))

func fromHex*(x: type Address, s: string): Address {.inline.} =
  fromHexAux(s, array[20, byte](result))

func decodeFixed(input: string, offset: int, to: var openarray[byte]): int =
  let meaningfulLen = to.len * 2
  var padding = to.len mod 32
  if padding != 0: padding = (32 - padding) * 2
  let offset = offset + padding
  fromHexAux(input[offset .. offset + meaningfulLen - 1], to)
  meaningfulLen + padding

func decode*[N](input: string, offset: int, to: var FixedBytes[N]): int {.inline.} =
  decodeFixed(input, offset, array[N, byte](to))

func decode*(input: string, offset: int, to: var Address): int {.inline.} =
  decodeFixed(input, offset, array[20, byte](to))

func encodeDynamic(v: openarray[byte]): EncodeResult =
  result.dynamic = true
  result.data = v.len.toHex(64).toLower
  for y in v:
    result.data &= y.toHex.toLower
  result.data &= "00".repeat(v.len mod 32)

func encode*[N](x: DynamicBytes[N]): EncodeResult {.inline.} =
  encodeDynamic(array[N, byte](x))

func fromHex*[N](x: type DynamicBytes[N], s: string): DynamicBytes[N] {.inline.} =
  fromHexAux(s, array[N, byte](result))

func decodeDynamic(input: string, offset: int, to: var openarray[byte]): int =
  var dataOffset, dataLen: UInt256
  result = decode(input, offset, dataOffset)
  discard decode(input, dataOffset.toInt * 2, dataLen)
  # TODO: Check data len, and raise?
  let meaningfulLen = to.len * 2
  let actualDataOffset = (dataOffset.toInt + 32) * 2
  fromHexAux(input[actualDataOffset .. actualDataOffset + meaningfulLen - 1], to)

func decode*[N](input: string, offset: int, to: var DynamicBytes[N]): int {.inline.} =
  decodeDynamic(input, offset, array[N, byte](to))

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
  else:
    unknownType(T)

proc initContractCall[T](web3: Web3, data: string, to: Address): ContractCall[T] {.inline.} =
  result.web3 = web3
  result.data = data
  result.to = to

macro makeTypeEnum(): untyped =
  ## This macro creates all the various types of Solidity contracts and maps
  ## them to the type used for their encoding. It also creates an enum to
  ## identify these types in the contract signatures, along with encoder
  ## functions used in the generated procedures.
  result = newStmtList()
  var lastpow2: int
  for i in countdown(256, 8, 8):
    let
      identUint = newIdentNode("Uint" & $i)
      identInt = newIdentNode("Int" & $i)
    if ceil(log2(i.float)) == floor(log2(i.float)):
      lastpow2 = i
    if i notin {256, 125}: # Int/Uint256/128 are already defined in stint. No need to repeat.
      result.add quote do:
        type
          `identUint`* = Stuint[`lastpow2`]
          `identInt`* = Stint[`lastpow2`]
  let
    identUint = ident("Uint")
    identInt = ident("Int")
    identBool = ident("Bool")
  result.add quote do:
    type
      `identUint`* = Uint256
      `identInt`* = Int256
      `identBool`* = distinct Int256

  for m in countup(8, 256, 8):
    let
      identInt = ident("Int" & $m)
      identUint = ident("Uint" & $m)
      identFixed = ident "Fixed" & $m
      identUfixed = ident "Ufixed" & $m
      identT = ident "T"
    result.add quote do:
      # Fixed stuff is not actually implemented yet, these procedures don't
      # do what they are supposed to.
      type
        `identFixed`*[N: static[int]] = distinct `identInt`
        `identUfixed`*[N: static[int]] = distinct `identUint`

      # func to*(x: `identInt`, `identT`: typedesc[`identFixed`]): `identT` =
      #   T(x)

      # func to*(x: `identUint`, `identT`: typedesc[`identUfixed`]): `identT` =
      #   T(x)

      # func encode*[N: static[int]](x: `identFixed`[N]): EncodeResult =
      #   encode(`identInt`(x) * (10 ^ N).to(`identInt`))

      # func encode*[N: static[int]](x: `identUfixed`[N]): EncodeResult =
      #   encode(`identUint`(x) * (10 ^ N).to(`identUint`))

      # func decode*[N: static[int]](input: string, to: `identFixed`[N]): `identFixed`[N] =
      #   decode(input, `identInt`) div / (10 ^ N).to(`identInt`)

      # func decode*[N: static[int]](input: string, to: `identUfixed`[N]): `identFixed`[N] =
      #   decode(input, `identUint`) div / (10 ^ N).to(`identUint`)

  let
    identFixed = ident("Fixed")
    identUfixed = ident("Ufixed")
  result.add quote do:
    type
      `identFixed`* = distinct Int128
      `identUfixed`* = distinct Uint128
  for i in 1..256:
    let
      identBytes = ident("Bytes" & $i)
      identResult = ident "result"
    result.add quote do:
      type
        `identBytes`* = DynamicBytes[`i`]

  #result.add newEnum(ident "FieldKind", fields, public = true, pure = true)

makeTypeEnum()

func encode*(x: Bool): EncodeResult = encode(Int256(x))
func decode*[N](input: string, offset: int, to: var Bool): int {.inline.} =
  decode(input, offset, Stint(to))


type
  Encodable = concept x
    encode(x) is EncodeResult

func encode*(x: seq[Encodable]): EncodeResult =
  result.dynamic = true
  result.data = x.len.toHex(64).toLower
  var
    offset = 32*x.len
    data = ""
  for i in x:
    let encoded = encode(i)
    if encoded.dynamic:
      result.data &= offset.toHex(64).toLower
      data &= encoded.data
    else:
      result.data &= encoded.data
    offset += encoded.data.len
  result.data &= data

func decode*[T](input: string, to: seq[T]): seq[T] =
  var count = input[0..64].decode(Stuint)
  result = newSeq[T](count)
  for i in 0..count:
    result[i] = input[i*64 .. (i+1)*64].decode(T)

func encode*(x: openArray[Encodable]): EncodeResult =
  result.dynamic = false
  result.data = ""
  var
    offset = 32*x.len
    data = ""
  for i in x:
    let encoded = encode(i)
    if encoded.dynamic:
      result.data &= offset.toHex(64).toLower
      data &= encoded.data
    else:
      result.data &= encoded.data
    offset += encoded.data.len

func decode*[T; I: static int](input: string, to: array[0..I, T]): array[0..I, T] =
  for i in 0..I:
    result[i] = input[i*64 .. (i+1)*64].decode(T)


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
      isconstructor = procdef[4].findChild(it.ident == !"constructor") != nil
      isevent = procdef[4].findChild(it.ident == !"event") != nil
    doAssert(not (isconstructor and constructor.isSome),
      "Contract can only have a single constructor")
    doAssert(not (isconstructor and isevent),
      "Can't be both event and constructor")
    if not isevent:
      let
        ispure = procdef[4].findChild(it.ident == !"pure") != nil
        isview = procdef[4].findChild(it.ident == !"view") != nil
        ispayable = procdef[4].findChild(it.ident == !"payable") != nil
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
          name: $procdef[0].ident,
          stateMutability: if ispure: pure elif isview: view elif ispayable: payable else: nonpayable,
          inputs: parseInputs(procdef[3]),
          outputs: parseOutputs(procdef[3][0])
        )
    else:
      let isanonymous = procdef[4].findChild(it.ident == !"anonymous") != nil
      doAssert(procdef[3][0].kind == nnkEmpty,
        "Events can't have return values")
      events.add EventObject(
        name: $procdef[0].ident,
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
      `cname` = object

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
        proc `procName`(`senderName`: Sender[`cname`]): ContractCall[`output`] =
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
            ($keccak_256.digest(`signature`))[0..<8].toLower & `encodedParams`,
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
          cbident = ident obj.eventObject.name
          procTy = nnkProcTy.newTree(params, newEmptyNode())
          signature = getSignature(obj.eventObject)

        procTy[1] = nnkPragma.newTree(ident"gcsafe") # TODO: use addPragma in nim 0.20.4 and later

        callWithRawData.add jsonIdent
        paramsWithRawData.add nnkIdentDefs.newTree(
          jsonIdent,
          bindSym "JsonNode",
          newEmptyNode()
        )

        let procTyWithRawData = nnkProcTy.newTree(paramsWithRawData, newEmptyNode())
        procTyWithRawData[1] = nnkPragma.newTree(ident"gcsafe") # TODO: use addPragma in nim 0.20.4 and later

        result.add quote do:
          type `cbident` = object
          proc subscribe(s: Sender[`cname`], t: typedesc[`cbident`], options: JsonNode, `callbackIdent`: `procTy`): Future[Subscription] =
            let options = addAddressAndSignatureToOptions(options, s.contractAddress, "0x" & toLowerAscii($keccak256.digest(`signature`)))

            s.web3.subscribeToLogs(options) do(`jsonIdent`: JsonNode):
              `argParseBody`
              `call`

          proc subscribe(s: Sender[`cname`], t: typedesc[`cbident`], options: JsonNode, `callbackIdent`: `procTyWithRawData`): Future[Subscription] =
            let options = addAddressAndSignatureToOptions(options, s.contractAddress, "0x" & toLowerAscii($keccak256.digest(`signature`)))

            s.web3.subscribeToLogs(options) do(`jsonIdent`: JsonNode):
              `argParseBody`
              `callWithRawData`

    else:
      discard

proc signatureEnabled(w: Web3): bool {.inline.} =
  var pk: PrivateKey
  w.privateKey != pk

proc send*(web3: Web3, c: EthSend): Future[TxHash] {.async.} =
  if web3.signatureEnabled():
    var cc = c
    if not cc.nonce.isSome:
      let fromAddress = web3.privateKey.getPublicKey.toCanonicalAddress.Address
      cc.nonce = some(int(await web3.provider.eth_getTransactionCount(fromAddress, "latest")))
    let t = "0x" & encodeTransaction(cc, web3.privateKey)
    return await web3.provider.eth_sendRawTransaction(t)
  else:
    return await web3.provider.eth_sendTransaction(c)

proc send*(c: ContractCallBase, value = 0.u256, gas = 3000000'u64, gasPrice = 0): Future[TxHash] =
  let web3 = c.web3
  var cc: EthSend
  cc.data = "0x" & c.data
  cc.source = web3.defaultAccount
  cc.to = some(c.to)
  cc.gas = some(Quantity(gas))
  cc.value = some(value)

  if web3.signatureEnabled() or gasPrice != 0:
    cc.gasPrice = some(gasPrice)
  web3.send(cc)

proc call*[T](c: ContractCall[T], value = 0.u256, gas = 3000000'u64): Future[T] {.async.} =
  var cc: EthCall
  cc.data = some("0x" & c.data)
  cc.source = some(c.web3.defaultAccount)
  cc.to = c.to
  cc.gas = some(Quantity(gas))
  cc.value = some(value)
  let response = await c.web3.provider.eth_call(cc, "latest")
  var res: T
  discard decode(strip0xPrefix(response), 0, res)
  return res

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

proc subscribe*(s: Sender, t: typedesc, cb: proc): Future[Subscription] {.inline.} =
  subscribe(s, t, nil, cb)

proc `$`*(b: Bool): string =
  $(Stint[256](b))
