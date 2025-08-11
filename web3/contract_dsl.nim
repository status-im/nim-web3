import
  std/[macros, strutils],
  json_serialization,
  ./[encoding, decoding, eth_api_types],
  ./conversions,
  stint,
  stew/byteutils

type
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

  EventData* = object
    data*: seq[byte]
    topics*: seq[Bytes32]

EventData.useDefaultSerializationIn JrpcConv

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
    constructor: Opt[ConstructorObject]
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
        constructor = Opt.some(ConstructorObject(
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

proc genFunction(cname: NimNode, functionObject: FunctionObject): NimNode =
  let
    signature = getSignature(functionObject)
    procName = ident functionObject.name
    senderName = ident "sender"
    output = if functionObject.outputs.len != 1:
        ident "void"
      else:
        functionObject.outputs[0].typ
    funcParamsTuple = newNimNode(nnkTupleConstr)

  for input in functionObject.inputs:
    funcParamsTuple.add(ident input.name)

  result = quote do:
    proc `procName`*[TSender](`senderName`: ContractInstance[`cname`, TSender]): auto {.raises: [SerializationError].} =
      discard
  for input in functionObject.inputs:
    result[3].add nnkIdentDefs.newTree(
      ident input.name,
      input.typ,
      newEmptyNode()
    )
  if functionObject.stateMutability == view:
    result[6] = quote do:
      mixin createImmutableContractInvocation
      return createImmutableContractInvocation(
          `senderName`.sender, `output`,
          static(keccak256(`signature`).data[0..<4]) & Abi.encode(`funcParamsTuple`))
  else:
    result[6] = quote do:
      mixin createMutableContractInvocation
      return createMutableContractInvocation(
          `senderName`.sender, `output`,
          static(keccak256(`signature`).data[0..<4]) & Abi.encode(`funcParamsTuple`))

proc `&`(a, b: openArray[byte]): seq[byte] =
  let sza = a.len
  let szb = b.len
  result.setLen(sza + szb)
  if sza > 0:
    copyMem(addr result[0], unsafeAddr a[0], sza)
  if szb > 0:
    copyMem(addr result[sza], unsafeAddr b[0], szb)

proc genConstructor(cname: NimNode, constructorObject: ConstructorObject): NimNode =
  let
    sender = genSym(nskParam, "sender")
    contractCode = genSym(nskParam, "contractCode")
    funcParamsTuple = newNimNode(nnkTupleConstr)

  for input in constructorObject.inputs:
    funcParamsTuple.add(ident input.name)

  result = quote do:
    proc deployContract*[TSender](`sender`: TSender, contractType: typedesc[`cname`], `contractCode`: openArray[byte]): auto =
      discard
  for input in constructorObject.inputs:
    result[3].add nnkIdentDefs.newTree(
      ident input.name,
      input.typ,
      newEmptyNode()
    )
  result[6] = quote do:
    mixin createContractDeployment
    return createContractDeployment(`sender`, `cname`, `contractCode` & Abi.encode(`funcParamsTuple`))

proc genEvent(cname: NimNode, eventObject: EventObject): NimNode =
  if not eventObject.anonymous:
    let callbackIdent = ident "callback"
    let jsonIdent = ident "j"
    let eventData = ident "eventData"
    var
      params = nnkFormalParams.newTree(newEmptyNode())
      paramsWithRawData = nnkFormalParams.newTree(newEmptyNode())

      argParseBody = newStmtList()
      i = 1
      call = nnkCall.newTree(callbackIdent)
      callWithRawData = nnkCall.newTree(callbackIdent)

    argParseBody.add quote do:
      let `eventData` = JrpcConv.decode(`jsonIdent`.string, EventData)

    let tupleType = nnkTupleTy.newTree()

    for input in eventObject.inputs:
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
          var `argument`: `kind` = Abi.decode(`eventData`.topics[`i`].data, `kind`)
        i += 1

        call.add argument
        callWithRawData.add argument
      else:
        # Generate the tuple type based on the non indexed inputs
        tupleType.add nnkIdentDefs.newTree(ident(input.name), input.typ, newEmptyNode())

    # Decode the tuple in on shot
    let decodedIdent = genSym(nskLet, "decoded")
    argParseBody.add quote do:
      let `decodedIdent` = Abi.decode(`eventData`.data, `tupleType`)

    # Loop on the inputs again to add the arguments to the calls
    for input in eventObject.inputs:
      if not input.indexed:
        let fieldName = ident(input.name)
        let argument = nnkDotExpr.newTree(decodedIdent, fieldName)
        call.add argument
        callWithRawData.add argument

    let
      eventName = eventObject.name
      cbident = ident eventName
      procTy = nnkProcTy.newTree(params, newEmptyNode())
      signature = getSignature(eventObject)

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
      bindSym "JsonString",
      newEmptyNode()
    )

    let procTyWithRawData = nnkProcTy.newTree(paramsWithRawData, newEmptyNode())
    procTyWithRawData[1] = pragmas

    result = quote do:
      type `cbident`* = object

      template eventTopic*(T: type `cbident`): eth_api_types.Bytes32 =
        const r = Bytes32 keccak256(`signature`).data
        r

      proc subscribe[TSender](s: ContractInstance[`cname`, TSender],
                      t: type `cbident`,
                      options: FilterOptions,
                      `callbackIdent`: `procTy`,
                      errorHandler: SubscriptionErrorHandler,
                      withHistoricEvents = true): Future[Subscription] {.used.} =
        proc eventHandler(`jsonIdent`: JsonString) {.gcsafe, raises: [].} =
          try:
            `argParseBody`
            `call`
          except CatchableError as err:
            errorHandler err[]

        s.sender.subscribeForLogs(options, eventTopic(`cbident`), eventHandler, errorHandler, withHistoricEvents)

      proc subscribe[TSender](s: ContractInstance[`cname`, TSender],
                      t: type `cbident`,
                      options: FilterOptions,
                      `callbackIdent`: `procTyWithRawData`,
                      errorHandler: SubscriptionErrorHandler,
                      withHistoricEvents = true): Future[Subscription] {.used.} =
        proc eventHandler(`jsonIdent`: JsonString) {.gcsafe, raises: [].} =
          try:
            `argParseBody`
            `callWithRawData`
          except CatchableError as err:
            errorHandler err[]

        s.sender.subscribeForLogs(options, eventTopic(`cbident`), eventHandler, errorHandler, withHistoricEvents)


macro contract*(cname: untyped, body: untyped): untyped =
  var objects = parseContract(body)
  result = newStmtList()
  result.add quote do:
    type
      `cname`* = object

  var constructorGenerated = false

  for obj in objects:
    case obj.kind:
    of function:
      result.add genFunction(cname, obj.functionObject)
    of constructor:
      result.add genConstructor(cname, obj.constructorObject)
      constructorGenerated = true
    of event:
      result.add genEvent(cname, obj.eventObject)

  if not constructorGenerated:
    result.add genConstructor(cname, ConstructorObject())

  when defined(debugMacros) or defined(debugWeb3Macros):
    echo result.repr
