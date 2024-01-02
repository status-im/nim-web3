import
  std/[macros, strutils, options, json],
  nimcrypto/keccak,
  ./[encoding, primitives],
  stint,
  stew/byteutils

type
  ContractInvocation*[TResult, TSender] = object
    data*: seq[byte]
    sender*: TSender

  ContractInstance*[TContract, TSender] = object
    sender*: TSender

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

proc keccak256Bytes(s: string): seq[byte] {.inline.} =
  @(keccak256.digest(s).data)

proc initContractInvocation[TSender](TResult: typedesc, sender: TSender, data: seq[byte]): ContractInvocation[TResult, TSender] {.inline.} =
  ContractInvocation[TResult, TSender](data: data, sender: sender)

proc joinStrings(s: varargs[string]): string = join(s)

proc unknownType() = discard # Used for informative errors

template seqType[T](s: typedesc[seq[T]]): typedesc = T

proc typeSignature(T: typedesc): string =
  when T is string:
    "string"
  elif (T is DynamicBytes) or (T is seq[byte]):
    "bytes"
  elif T is FixedBytes:
    "bytes" & $T.N
  elif T is StUint:
    "uint" & $T.bits
  elif T is Address:
    "address"
  elif T is bool:
    "bool"
  elif T is seq:
    typeSignature(seqType(T)) & "[]"
  else:
    unknownType(T)

proc getSignature(function: FunctionObject | EventObject): NimNode =
  result = newCall(bindSym"joinStrings")
  result.add(newLit(function.name & "("))
  for i, input in function.inputs:
    result.add(newCall(bindSym"typeSignature", input.typ))
    if i != function.inputs.high:
      result.add(newLit(","))
  result.add(newLit(")"))

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
        funcParamsTuple = newNimNode(nnkTupleConstr)

      for input in obj.functionObject.inputs:
        funcParamsTuple.add(ident input.name)

      var procDef = quote do:
        proc `procName`*[TSender](`senderName`: ContractInstance[`cname`, TSender]): ContractInvocation[`output`, TSender] =
          discard
      for input in obj.functionObject.inputs:
        procDef[3].add nnkIdentDefs.newTree(
          ident input.name,
          input.typ,
          newEmptyNode()
        )
      procDef[6].add quote do:
        return initContractInvocation(
            `output`, `senderName`.sender,
            static(keccak256Bytes(`signature`)[0..<4]) & encode(`funcParamsTuple`))

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
              discard decode(hexToSeqByte(`jsonIdent`["topics"][`i`].getStr), 0, 0, `argument`)
            i += 1
          else:
            if not offsetInited:
              argParseBody.add quote do:
                var `inputData` = hexToSeqByte(`jsonIdent`["data"].getStr)
                var `offset` = 0

              offsetInited = true

            argParseBody.add quote do:
              var `argument`: `kind`
              `offset` += decode(`inputData`, 0, `offset`, `argument`)
          call.add argument
          callWithRawData.add argument
        let
          eventName = obj.eventObject.name
          cbident = ident eventName
          procTy = nnkProcTy.newTree(params, newEmptyNode())
          signature = getSignature(obj.eventObject)

        # generated with dumpAstGen - produces "{.raises: [], gcsafe.}"
        let pragmas = nnkPragma.newTree(
          nnkExprColonExpr.newTree(
            newIdentNode("raises"),
            nnkBracket.newTree()
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
          type `cbident`* = object

          template eventTopic*(T: type `cbident`): seq[byte] =
            const r = keccak256Bytes(`signature`)
            r

          proc subscribe[TSender](s: ContractInstance[`cname`, TSender],
                         t: type `cbident`,
                         options: JsonNode,
                         `callbackIdent`: `procTy`,
                         errorHandler: SubscriptionErrorHandler,
                         withHistoricEvents = true): Future[Subscription] {.used.} =
            proc eventHandler(`jsonIdent`: JsonNode) {.gcsafe, raises: [].} =
              try:
                `argParseBody`
                `call`
              except CatchableError as err:
                errorHandler err[]

            s.sender.subscribeForLogs(options, eventTopic(`cbident`), eventHandler, errorHandler, withHistoricEvents)

          proc subscribe[TSender](s: ContractInstance[`cname`, TSender],
                         t: type `cbident`,
                         options: JsonNode,
                         `callbackIdent`: `procTyWithRawData`,
                         errorHandler: SubscriptionErrorHandler,
                         withHistoricEvents = true): Future[Subscription] {.used.} =
            proc eventHandler(`jsonIdent`: JsonNode) {.gcsafe, raises: [].} =
              try:
                `argParseBody`
                `callWithRawData`
              except CatchableError as err:
                errorHandler err[]

            s.sender.subscribeForLogs(options, eventTopic(`cbident`), eventHandler, errorHandler, withHistoricEvents)

    else:
      discard

  when defined(debugMacros) or defined(debugWeb3Macros):
    echo result.repr
