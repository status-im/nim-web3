import macros, strutils, options, math, json
from os import getCurrentDir, DirSep
import
  nimcrypto, stint, httputils, chronicles, asyncdispatch2, json_rpc/rpcclient
import ethtypes, ethprocs, stintjson, ethhexstrings

template sourceDir: string = currentSourcePath.rsplit(DirSep, 1)[0]

## Generate client convenience marshalling wrappers from forward declarations
createRpcSigs(RpcHttpClient, sourceDir & DirSep & "ethcallsigs.nim")

type
  Sender[T] = ref object
    contract: T
    address: array[20, byte]
    ip: string
    port: int

  Contract = ref object
    address: array[20, byte]

#proc initWeb3*(address: string, port: int): Web3 =
#  ## Just creates a simple dummy wrapper object for now. Functionality should
#  ## increase as the web3 interface is fleshed out.
#  var client = newRpcHttpClient()
#  client.httpMethod(MethodPost)
#
#  waitFor client.connect(address, Port(port))
#  result = new Web3
#  result.eth = client

func encode[bits: static[int]](x: Stuint[bits]): string =
  ## Encodes a `Stuint` to a textual representation for use in the JsonRPC
  ## `sendTransaction` call.
  '0'.repeat((256 - bits) div 4) & x.dumpHex

func encode[bits: static[int]](x: Stint[bits]): string =
  ## Encodes a `Stint` to a textual representation for use in the JsonRPC
  ## `sendTransaction` call.
  if x.isNegative:
    'f'.repeat((256 - bits) div 4) & x.dumpHex
  else:
    '0'.repeat((256 - bits) div 4) & x.dumpHex

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
    func encode*(x: `identBool`): string = encode(Int256(x))
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
        `identFixed`[N: static[int]] = distinct `identInt`
        `identUfixed`[N: static[int]] = distinct `identUint`

      func to*(x: `identInt`, `identT`: typedesc[`identFixed`]): `identT` =
        T(x)

      func to*(x: `identUint`, `identT`: typedesc[`identUfixed`]): `identT` =
        T(x)

      func encode*[N: static[int]](x: `identFixed`[N]): string =
        encode(`identInt`(x) * (10 ^ N).to(`identInt`))

      func encode*[N: static[int]](x: `identUfixed`[N]): string =
        encode(`identUint`(x) * (10 ^ N).to(`identUint`))

    fields.add ident("Fixed" & $m)
    fields.add ident("Ufixed" & $m)
  let
    identFixed = ident("Fixed")
    identUfixed = ident("Ufixed")
  fields.add identFixed
  fields.add identUfixed
  result.add quote do:
    type
      `identFixed` = distinct Int128
      `identUfixed` = distinct Uint128
  for i in 1..32:
    let
      identBytes = ident("Bytes" & $i)
      identResult = ident "result"
    fields.add identBytes
    result.add quote do:
      type
        `identBytes` = array[0..(`i`-1), byte]
      func encode(x: `identBytes`): string =
        `identResult` = ""
        for y in x:
          `identResult` &= y.toHex.toLower
        `identResult` &= "00".repeat(32 - x.len)

  fields.add [
    ident("Function"),
    ident("Bytes"),
    ident("String")
  ]
  result.add quote do:
    type
      Bytes = seq[byte]
  result.add newEnum(ident "FieldKind", fields, public = true, pure = true)
  echo result.repr

makeTypeEnum()

type
  InterfaceObjectKind = enum
    function, constructor, event
  MutabilityKind = enum
    pure, view, nonpayable, payable
  FunctionInputOutput = object
    name: string
    kind: FieldKind
  EventInput = object
    name: string
    kind: FieldKind
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

proc parseContract(body: NimNode): seq[InterfaceObject] =
  proc parseOutputs(outputNode: NimNode): seq[FunctionInputOutput] =
    if outputNode.kind == nnkIdent:
      result.add FunctionInputOutput(
        name: "",
        kind: parseEnum[FieldKind]($outputNode.ident)
      )
  proc parseInputs(inputNodes: NimNode): seq[FunctionInputOutput] =
    for i in 1..<inputNodes.len:
      let input = inputNodes[i]
      if input.kind == nnkIdentDefs:
        result.add FunctionInputOutput(
          name: $input[0].ident,
          kind: parseEnum[FieldKind]($input[1].ident)
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
          doAssert($input[1][0].ident == "indexed",
            "Only `indexed` is allowed as option for event inputs")
          result.add EventInput(
            name: $input[0].ident,
            kind: parseEnum[FieldKind]($input[1][1].ident),
            indexed: true
          )
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

macro contract(cname: untyped, body: untyped): untyped =
  var objects = parseContract(body)
  result = newStmtList()
  result.add quote do:
    type
      `cname` = distinct Contract
  for obj in objects:
    if obj.kind == function:
      echo obj.functionObject.outputs
      let
        signature = getMethodSignature(obj.functionObject)
        procName = ident obj.functionObject.name
        senderName = ident "sender"
        client = ident "client"
        output =
          if obj.functionObject.stateMutability in {payable, nonpayable}:
            ident "Address"
          else:
            if obj.functionObject.outputs.len != 1:
              newEmptyNode()
            else:
              ident $obj.functionObject.outputs[0].kind
      var encodedParams = newLit("")
      for input in obj.functionObject.inputs:
        encodedParams = nnkInfix.newTree(
          ident "&",
          encodedParams,
          nnkCall.newTree(ident "encode", ident input.name)
        )
      var procDef = quote do:
        proc `procName`(`senderName`: Sender[`cname`]): `output` =
          var `client` = newRpcHttpClient()
          `client`.httpMethod(MethodPost)
          waitFor `client`.connect(`senderName`.ip, Port(`senderName`.port))
      for input in obj.functionObject.inputs:
        procDef[3].add nnkIdentDefs.newTree(
          ident input.name,
          ident $input.kind,
          newEmptyNode()
        )
      case obj.functionObject.stateMutability:
      of view:
        procDef[6].add quote do:
          var cc: EthCall
          cc.source = some(`senderName`.address)
          cc.to = `senderName`.contract.Contract.address
          cc.data = some("0x" & ($keccak_256.digest(`signature`))[0..<8].toLower & `encodedParams`)
          let response = waitFor `client`.eth_call(cc, "latest")
          return response
      else:
        procDef[6].add quote do:
          var cc: EthSend
          cc.source = `senderName`.address
          cc.to = some(`senderName`.contract.Contract.address)
          cc.data = "0x" & ($keccak_256.digest(`signature`))[0..<8].toLower & `encodedParams`
          let response = waitFor `client`.eth_sendTransaction(cc)
          return response
      result.add procDef
  echo result.repr

contract(TestContract):
  proc sendCoin(receiver: Address, amount: Uint): Bool
  proc getBalance(address: Address): Uint {.view.}
  proc Transfer(fromAddr: indexed[Address], toAddr: indexed[Address], value: Uint256) {.event.}

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

proc sender[T](contract: T, ip: string, port: int, address: array[20, byte]): Sender[T] =
  Sender[T](contract: contract, address: address, ip: ip, port: port)

#proc sendCoin(sender: Sender[MyContract], receiver: Address, amount: Uint): Bool =
#  echo "Hello world"
#  return 1.to(Stint[256]).Bool
#
proc `$`(b: Bool): string =
  $(Stint[256](b))

macro toAddress(input: string): untyped =
  let a = $input
  result = nnkBracket.newTree()
  for c in countup(0, a.high, 2):
    result.add nnkDotExpr.newTree(
      newLit(parseHexInt(a[c..c+1])),
      ident "byte"
    )

var x = Contract(address: "254dffcd3277C0b1660F6d42EFbB754edaBAbC2B".toAddress).TestContract

echo x.sender("127.0.0.1", 8545, "90f8bf6a479f320ead074411a4b0e7944ea8c9c1".toAddress).getBalance(
  fromHex(Stuint[256], "ffcf8fdee72ac11b5c542428b35eef5769c409f0")
)

echo toHex(x.sender("127.0.0.1", 8545, "90f8bf6a479f320ead074411a4b0e7944ea8c9c1".toAddress).sendCoin(
  fromHex(Stuint[256], "ffcf8fdee72ac11b5c542428b35eef5769c409f0"),
  100000.to(Stuint[256])
))

echo x.sender("127.0.0.1", 8545, "90f8bf6a479f320ead074411a4b0e7944ea8c9c1".toAddress).getBalance(
  fromHex(Stuint[256], "ffcf8fdee72ac11b5c542428b35eef5769c409f0")
)
#echo "0x" & $keccak_256.digest("Transfer(address,address,uint256)")
