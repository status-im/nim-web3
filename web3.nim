import macros, strutils, options, math, json
from os import getCurrentDir, DirSep, sleep
import
  nimcrypto, stint, httputils, chronicles, chronos, json_rpc/rpcclient
import web3/[ethtypes, ethprocs, stintjson, ethhexstrings]

template sourceDir: string = currentSourcePath.rsplit(DirSep, 1)[0]

## Generate client convenience marshalling wrappers from forward declarations
createRpcSigs(RpcHttpClient, sourceDir & DirSep & "web3" & DirSep & "ethcallsigs.nim")

type
  Sender*[T] = ref object
    contract: T
    address: array[20, byte]
    ip: string
    port: int

  Receiver*[T] = ref object
    contract: T
    ip: string
    port: int

  EventListener*[T] = ref object
    receiver: Receiver[T]
    lastBlock: string

  EncodeResult* = tuple[dynamic: bool, data: string]

#proc initWeb3*(address: string, port: int): Web3 =
#  ## Just creates a simple dummy wrapper object for now. Functionality should
#  ## increase as the web3 interface is fleshed out.
#  var client = newRpcHttpClient()
#  client.httpMethod(MethodPost)
#
#  waitFor client.connect(address, Port(port))
#  result = new Web3
#  result.eth = client

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

func decode*[bits: static[int]](input: string, to: type Stuint[bits]): Stuint[bits] =
  fromHex(to, input)

func decode*[bits: static[int]](input: string, to: type Stint[bits]): Stint[bits] =
  cast[Stint[bits]](fromHex(Stuint[bits], input))


macro makeTypeEnum(): untyped =
  ## This macro creates all the various types of Solidity contracts and maps
  ## them to the type used for their encoding. It also creates an enum to
  ## identify these types in the contract signatures, along with encoder
  ## functions used in the generated procedures.
  result = newStmtList()
  var fields: seq[NimNode]
  var lastpow2: int
  for i in countdown(256, 8, 8):
    let
      identUint = newIdentNode("Uint" & $i)
      identInt = newIdentNode("Int" & $i)
    if ceil(log2(i.float)) == floor(log2(i.float)):
      lastpow2 = i
    result.add quote do:
      type
        `identUint`* = Stuint[`lastpow2`]
        `identInt`* = Stint[`lastpow2`]
    fields.add ident("Uint" & $i)
    fields.add ident("Int" & $i)
  let
    identAddress = ident("Address")
    identUint = ident("Uint")
    identInt = ident("Int")
    identBool = ident("Bool")
  result.add quote do:
    type
      `identAddress`* = Uint160
      `identUint`* = Uint256
      `identInt`* = Int256
      `identBool`* = distinct Int256
    func encode*(x: `identBool`): EncodeResult = encode(Int256(x))
    func decode*(input: string, x: `identBool`): `identBool` = `identBool`(decode(input, Stint[256]))
  fields.add [
    identAddress,
    identUint,
    identInt,
    identBool
  ]
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

      func to*(x: `identInt`, `identT`: typedesc[`identFixed`]): `identT` =
        T(x)

      func to*(x: `identUint`, `identT`: typedesc[`identUfixed`]): `identT` =
        T(x)

      func encode*[N: static[int]](x: `identFixed`[N]): EncodeResult =
        encode(`identInt`(x) * (10 ^ N).to(`identInt`))

      func encode*[N: static[int]](x: `identUfixed`[N]): EncodeResult =
        encode(`identUint`(x) * (10 ^ N).to(`identUint`))

      func decode*[N: static[int]](input: string, to: `identFixed`[N]): `identFixed`[N] =
        decode(input, `identInt`) div / (10 ^ N).to(`identInt`)

      func decode*[N: static[int]](input: string, to: `identUfixed`[N]): `identFixed`[N] =
        decode(input, `identUint`) div / (10 ^ N).to(`identUint`)

    fields.add ident("Fixed" & $m)
    fields.add ident("Ufixed" & $m)
  let
    identFixed = ident("Fixed")
    identUfixed = ident("Ufixed")
  fields.add identFixed
  fields.add identUfixed
  result.add quote do:
    type
      `identFixed`* = distinct Int128
      `identUfixed`* = distinct Uint128
  for i in 1..32:
    let
      identBytes = ident("Bytes" & $i)
      identResult = ident "result"
    fields.add identBytes
    result.add quote do:
      type
        `identBytes`* = array[0..(`i`-1), byte]
      func encode(x: `identBytes`): EncodeResult =
        `identResult`.dynamic = false
        `identResult`.data = ""
        for y in x:
          `identResult`.data &= y.toHex.toLower
        `identResult`.data &= "00".repeat(32 - x.len)
      func fromHex*(x: type `identBytes`, s: string): `identBytes` =
        for i in 0..(`i`-1):
          `identResult`[i] = parseHexInt(s[i*2..i*2+1]).uint8
      func decode*(input: string, to: type `identBytes`): `identBytes` =
        fromHex(to, input)

  fields.add [
    ident("Function"),
    ident("Bytes"),
    ident("String")
  ]
  let
    identBytes = ident "Bytes"
    identResult = ident "result"
  result.add quote do:
    type
      `identBytes`* = seq[byte]
    func encode(x: `identBytes`): EncodeResult =
      `identResult`.dynamic = false
      `identResult`.data = x.len.toHex(64).toLower
      for y in x:
        `identResult`.data &= y.toHex.toLower
      `identResult`.data &= "00".repeat(32 - (x.len mod 32))
    func fromHex*(x: type `identBytes`, s: string): `identBytes` =
      fromHex(s)
    func decode*(input: string, to: type `identBytes`): `identBytes` =
      fromHex(to, input)

  result.add newEnum(ident "FieldKind", fields, public = true, pure = true)
  echo result.repr

makeTypeEnum()

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
  SequenceKind = enum
    single, fixed, dynamic
  FunctionInputOutput = object
    name: string
    kind: FieldKind
    case sequenceKind: SequenceKind
    of single, dynamic: discard
    of fixed:
      count: int
  EventInput = object
    name: string
    kind: FieldKind
    indexed: bool
    case sequenceKind: SequenceKind
    of single, dynamic: discard
    of fixed:
      count: int
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

proc getMethodSignature(function: FunctionObject): string =
  var signature = function.name & "("
  for i, input in function.inputs:
    signature.add(
      case input.kind:
      of FieldKind.Uint: "uint256"
      of FieldKind.Int: "int256"
      else: ($input.kind).toLower
    )
    if i != function.inputs.high:
      signature.add ","
  signature.add ")"
  return signature

proc getEventSignature(event: EventObject): string =
  var signature = event.name & "("
  for i, input in event.inputs:
    signature.add(
      (case input.kind:
      of FieldKind.Uint: "uint256"
      of FieldKind.Int: "int256"
      else: ($input.kind).toLower) &
      (case input.sequenceKind:
      of single: ""
      of dynamic: "[]"
      of fixed: "[" & $input.count & "]")
    )
    if i != event.inputs.high:
      signature.add ","
  signature.add ")"
  return signature

proc parseContract(body: NimNode): seq[InterfaceObject] =
  proc parseOutputs(outputNode: NimNode): seq[FunctionInputOutput] =
    #if outputNode.kind == nnkIdent:
    #  result.add FunctionInputOutput(
    #    name: "",
    #    kind: parseEnum[FieldKind]($outputNode.ident)
    #  )
    case outputNode.kind:
    of nnkBracketExpr:
      result.add FunctionInputOutput(
        name: "",
        kind: parseEnum[FieldKind]($outputNode[0].ident),
        sequenceKind: if outputNode.len == 1:
          dynamic
        else:
          fixed
      )
      if outputNode.len == 2:
        result[^1].count = outputNode[1].intVal.int
    of nnkIdent:
      result.add FunctionInputOutput(
        name: "",
        kind: parseEnum[FieldKind]($outputNode.ident),
        sequenceKind: single
      )
    else:
      discard
  proc parseInputs(inputNodes: NimNode): seq[FunctionInputOutput] =
    for i in 1..<inputNodes.len:
      let input = inputNodes[i]
      if input.kind == nnkIdentDefs:
        echo input.repr
        echo input.treerepr
        if input[1].kind == nnkBracketExpr:
          result.add FunctionInputOutput(
            name: $input[0].ident,
            kind: parseEnum[FieldKind]($input[1][0].ident),
            sequenceKind: if input[1].len == 1:
              dynamic
            else:
              fixed
          )
          if input[1].len == 2:
            result[^1].count = input[1][1].intVal.int
        else:
          result.add FunctionInputOutput(
            name: $input[0].ident,
            kind: parseEnum[FieldKind]($input[1].ident),
            sequenceKind: single
          )
  proc parseEventInputs(inputNodes: NimNode): seq[EventInput] =
    for i in 1..<inputNodes.len:
      let input = inputNodes[i]
      if input.kind == nnkIdentDefs:
        case input[1].kind:
        of nnkIdent:
          result.add EventInput(
            name: $input[0].ident,
            kind: parseEnum[FieldKind]($input[1].ident),
            indexed: false
          )
        of nnkBracketExpr:
          #doAssert($input[1][0].ident == "indexed",
          #  "Only `indexed` is allowed as option for event inputs")
          if $input[1][0].ident == "indexed":
            result.add EventInput(
              name: $input[0].ident,
              kind: parseEnum[FieldKind]($input[1][1].ident),
              indexed: true
            )
          else:
            result.add EventInput(
              name: $input[0].ident,
              kind: parseEnum[FieldKind]($input[1][0].ident),
              indexed: false,
              sequenceKind: if input[1].len == 1:
                dynamic
              else:
                fixed
            )
            if input[1].len != 1:
              result[^1].count = input[1][1].intVal.int
        else:
          doAssert(false,
            "Can't have anything but ident or bracket expression here")
  echo body.treeRepr
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
  echo constructor
  echo functions
  echo events
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
      #`cname` = distinct Contract
      `cname` = ref object
        `address`: array[20, byte]
        `client`: RpcHttpClient
        #callbacks: tuple[
        #  Transfer: seq[proc (fromAddr: Address, toAddr: Address, value: Uint256)]
        #]
  var
    callbacks = nnkTupleTy.newTree()
    argParse = nnkIfExpr.newTree()

  for obj in objects:
    case obj.kind:
    of function:
      echo obj.functionObject.outputs
      let
        signature = getMethodSignature(obj.functionObject)
        procName = ident obj.functionObject.name
        senderName = ident "sender"
        output =
          if obj.functionObject.stateMutability in {payable, nonpayable}:
            ident "Address"
          else:
            if obj.functionObject.outputs.len != 1:
              ident "void"#newEmptyNode()
            else:
              ident $obj.functionObject.outputs[0].kind
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
            encoding.data.len)
          `encodings`.add encoding
        #encodedParams = nnkInfix.newTree(
        #  ident "&",
        #  encodedParams,
        #  nnkCall.newTree(ident "encode", ident input.name)
        #)
      encoder.add quote do:
        for encoding in `encodings`:
          if encoding.dynamic:
            `encodedParams` &= `offset`.toHex(64).toLower
            `offset` += encoding.data.len
            `dataBuf` &= encoding.data
          else:
            `encodedParams` &= encoding.data
        `encodedParams` &= `dataBuf`
      var procDef = quote do:
        proc `procName`(`senderName`: Sender[`cname`]): Future[`output`] {.async.} =
          `senderName`.contract.`client`.httpMethod(MethodPost)
          await `senderName`.contract.`client`.connect(`senderName`.ip, Port(`senderName`.port))
      for input in obj.functionObject.inputs:
        procDef[3].add nnkIdentDefs.newTree(
          ident input.name,
          (case input.sequenceKind:
          of single: ident $input.kind
          of dynamic: nnkBracketExpr.newTree(ident "seq", ident $input.kind)
          of fixed:
            nnkBracketExpr.newTree(
              ident "array",
              nnkInfix.newTree(
                ident "..",
                newLit(0),
                newLit(input.count)
              ),
              ident $input.kind
            )
          ),
          newEmptyNode()
        )
      case obj.functionObject.stateMutability:
      of view:
        let cc = ident "cc"
        procDef[6].add quote do:
          var `cc`: EthCall
          `cc`.source = some(`senderName`.address)
          #cc.to = `senderName`.contract.Contract.address
          `cc`.to = `senderName`.contract.address
          `encoder`
          `cc`.data = some("0x" & ($keccak_256.digest(`signature`))[0..<8].toLower & `encodedParams`)
          echo `cc`.data
        if output != ident "void":
          procDef[6].add quote do:
            let response = await `senderName`.contract.`client`.eth_call(`cc`, "latest")
            echo response
            return response[2..^1].decode(`output`)
        else:
          procDef[6].add quote do:
            await `senderName`.contract.`client`.eth_call(`cc`, "latest")
      else:
        procDef[6].add quote do:
          var cc: EthSend
          cc.source = `senderName`.address
          #cc.to = some(`senderName`.contract.Contract.address)
          cc.to = some(`senderName`.contract.address)
          `encoder`
          cc.data = "0x" & ($keccak_256.digest(`signature`))[0..<8].toLower & `encodedParams`
          echo cc.data
          let response = await `senderName`.contract.`client`.eth_sendTransaction(cc)
          return response
      result.add procDef
    of event:
      if not obj.eventObject.anonymous:
        let callback = genSym(nskForVar)
        var
          params = nnkFormalParams.newTree(newEmptyNode())
          argParseBody = newStmtList()
          arguments: seq[NimNode]
          i = 1
          call = nnkCall.newTree(callback)
        for ii, input in obj.eventObject.inputs:
          params.add nnkIdentDefs.newTree(
            ident input.name,
            ident $input.kind,
            newEmptyNode()
          )
          let
            argument = genSym(nskLet)
            kind = ident $input.kind
            inputData = if input.indexed:
              quote do:
                `receipt`.topics[`i`]
            else:
              quote do:
                `receipt`.data[(`ii` - `i` + 1)*64+2..<(`ii` - `i` + 2)*64+2]
          if input.indexed:
            i += 1
          arguments.add argument
          argParseBody.add quote do:
            let `argument` = fromHex(`kind`, `inputData`)
          call.add argument
        let cbident = ident obj.eventObject.name
        callbacks.add nnkIdentDefs.newTree(
          cbident,
          nnkBracketExpr.newTree(
            ident "seq",
            nnkProcTy.newTree(
              params,
              newEmptyNode()
            )
          ),
          newEmptyNode()
        )
        let signature = getEventSignature(obj.eventObject)
        argParse.add nnkElifExpr.newTree(quote do:
          `receipt`.topics[0] == "0x" & ($keccak_256.digest(`signature`)).toLower
        , quote do:
          `argParseBody`
          for `callback` in `eventListener`.receiver.contract.callbacks.`cbident`:
            `call`
        )
    else:
      discard
  if callbacks.len != 0:
    result[0][0][2][0][2].add nnkIdentDefs.newTree(
      ident "callbacks",
      callbacks,
      newEmptyNode()
    )
    result.add quote do:
      proc initEventListener(`receiver`: Receiver[`cname`]): EventListener[`cname`] =
        `receiver`.contract.client.httpMethod(MethodPost)
        waitFor `receiver`.contract.client.connect(`receiver`.ip, Port(`receiver`.port))
        var lastBlock = "0x" & (parseHexInt((waitFor `receiver`.contract.client.eth_blockNumber())[2..^1]) + 1).toHex[^2..^1]
        EventListener[`cname`](receiver: `receiver`, lastBlock: lastBlock)

      proc listen(`eventListener`: EventListener[`cname`]) {.async.} =
        await `eventListener`.receiver.contract.client.connect(`eventListener`.receiver.ip, Port(`eventListener`.receiver.port))
        let response = await `eventListener`.receiver.contract.client.eth_getLogs(FilterOptions(fromBlock: some(`eventListener`.lastBlock), toBlock: none(string), address: some(`eventListener`.receiver.contract.address.toStr), topics: none(seq[string])))
        if response.len > 0:
          `eventListener`.lastBlock = "0x" & (parseHexInt(response[^1].blockNumber[2..^1]) + 1).toHex[^2..^1]
        for `receipt` in response:
          `argParse`

  echo argParse.repr
  echo result.repr

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

proc initSender*[T](contract: T, ip: string, port: int, address: array[20, byte]): Sender[T] =
  Sender[T](contract: contract, address: address, ip: ip, port: port)

proc initReceiver*[T](contract: T, ip: string, port: int): Receiver[T] =
  Receiver[T](contract: contract, ip: ip, port: port)

#proc sendCoin(sender: Sender[MyContract], receiver: Address, amount: Uint): Bool =
#  echo "Hello world"
#  return 1.to(Stint[256]).Bool
#
proc `$`*(b: Bool): string =
  $(Stint[256](b))

macro toAddress*(input: string): untyped =
  let a = $input
  result = nnkBracket.newTree()
  for c in countup(0, a.high, 2):
    result.add nnkDotExpr.newTree(
      newLit(parseHexInt(a[c..c+1])),
      ident "byte"
    )

#proc eventListen(input: tuple[contractAddr: string, callback: proc(receipt: LogObject)]) =
#  var client = newRpcHttpClient()
#  client.httpMethod(MethodPost)
#  waitFor client.connect("127.0.0.1", Port(8545))
#  var lastBlock = "0x" & (parseHexInt((waitFor client.eth_blockNumber())[2..^1]) + 1).toHex[^2..^1]
#  while true:
#    waitFor client.connect("127.0.0.1", Port(8545))
#    let response = waitFor client.eth_getLogs(FilterOptions(fromBlock: some(lastBlock), toBlock: none(string), address: some(input.contractAddr), topics: none(seq[string])))
#    if response.len > 0:
#      lastBlock = "0x" & (parseHexInt(response[^1].blockNumber[2..^1]) + 1).toHex[^2..^1]
#    for receipt in response:
#      input.callback(receipt)
#      case receipt.topics[0]:
#      of "0x100":
#        discard
#      else:
#        discard
#    sleep(1000)

#var thr: Thread[tuple[contractAddr: string, callback: proc(receipt: LogObject)]]
#createThread[tuple[contractAddr: string, callback: proc(receipt: LogObject)]](thr, eventListen, (contractAddr: "0x254dffcd3277C0b1660F6d42EFbB754edaBAbC2B".toLower, callback: (proc(receipt: LogObject) =
#  echo receipt
#))
#)

