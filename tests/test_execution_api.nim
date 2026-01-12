import
  std/[os, strutils],
  pkg/unittest2,
  chronos,
  json_rpc/[rpcclient, rpcserver],
  json_rpc/private/jrpc_sys,
  ../web3/conversions,
  ./helpers/handlers,
  ../web3/eth_api,
  results

type
  TestData = tuple
    file: string
    description: string
    input: RequestTx
    output: ResponseRx

const
  inputPath = "tests/execution-apis/tests"

{.push raises: [].}

# XXX explicit readValue/writeValue to avoid automatic serialization
EthJson.automaticSerialization(JsonValueRef, true)

func compareValue(lhs, rhs: JsonValueRef): bool

func compareObject(lhs, rhs: JsonValueRef): bool =
  # assume lhs.len > rhs.len
  # null field and no field are treated equals
  for k, v in lhs.objVal:
    let rhsVal = rhs.objVal.getOrDefault(k, nil)
    if rhsVal.isNil:
      if v.kind != JsonValueKind.Null:
        return false
      else:
        continue
    if not compareValue(rhsVal, v):
      return false
  true

func compareValue(lhs, rhs: JsonValueRef): bool =
  if lhs.isNil and rhs.isNil:
    return true

  if not lhs.isNil and rhs.isNil:
    return false

  if lhs.isNil and not rhs.isNil:
    return false

  if lhs.kind != rhs.kind:
    return false

  case lhs.kind
  of JsonValueKind.String:
    lhs.strVal == rhs.strVal
  of JsonValueKind.Number:
    lhs.numVal == rhs.numVal
  of JsonValueKind.Object:
    if lhs.objVal.len >= rhs.objVal.len:
      compareObject(lhs, rhs)
    else:
      compareObject(rhs, lhs)
  of JsonValueKind.Array:
    if lhs.arrayVal.len != rhs.arrayVal.len:
      return false
    for i, x in lhs.arrayVal:
      if not compareValue(x, rhs.arrayVal[i]):
        return false
    true
  of JsonValueKind.Bool:
    lhs.boolVal == rhs.boolVal
  of JsonValueKind.Null:
    true

func strip(line: string): string =
  return line[3..^1]

func toTx(req: RequestRx): RequestTx =
  RequestTx(
    id: Opt.some(req.id),
    `method`: req.`method`.get(),
    params: req.params.toTx,
  )

proc extractTest(fileName: string): TestData {.raises: [IOError, SerializationError].} =
  # Note: Currently only supports single input/output per file as there is only one test
  # case that has multiple inputs/outputs (estimate-with-eip7702.io) and it is not worth
  # adding support for this one. For multiple inputs/outputs the last one will be tested.
  # These tests anyhow only test for serialization correctness and this multi-input/output
  # test case tests a specific change in actual output value.
  let lines = readFile(fileName).split("\n")
  var
    description = ""
    input = ""
    output = ""
  for line in lines:
    if line == "":
      continue
    if line.startsWith("// "):
      if description == "":
        description = line.strip()
      else:
        description = description & " " & line.strip()
    elif line.startsWith(">> "):
      if input != "":
        debugEcho "Test contains multiple inputs: " & fileName
      input = line
    elif line.startsWith("<< "):
      if output != "":
        debugEcho "Test contains multiple outputs: " & fileName
      output = line
  if input == "":
    raise (ref IOError)(msg: "Test contains no input: " & fileName)
  if output == "":
    raise (ref IOError)(msg: "Test contains no output: " & fileName)
  input = input.strip()
  output = output.strip()

  return (
    file: fileName,
    description: description,
    input: JrpcSys.decode(input, RequestRx).toTx,
    output: JrpcSys.decode(output, ResponseRx),
  )

proc extractTests(): seq[TestData] {.raises: [OSError, IOError, SerializationError].} =
  for fileName in walkDirRec(inputPath):
    if fileName.endsWith(".io"):
      result.add(fileName.extractTest())

proc callWithParams(client: RpcClient, data: TestData): Future[bool] {.async.} =
  let res = data.output

  try:
    var params = data.input.params
    if data.output.result.string.len > 0:
      let jsonBytes = EthJson.encode(data.output.result.string)
      params.positional.insert(jsonBytes.JsonString, 0)
    else:
      params.positional.insert("-1".JsonString, 0)

    let resJson = await client.call(data.input.`method`, params)

    if res.result.string.len > 0:
      let wantVal = EthJson.decode(res.result.string, JsonValueRef[string])
      let getVal = EthJson.decode(resJson.string, JsonValueRef[string])

      if not compareValue(wantVal, getVal):
        debugEcho data.file
        debugEcho data.description
        debugEcho "EXPECT: ", res.result
        debugEcho "GET: ", resJson.string
        return false

    return true
  except SerializationError as exc:
    debugEcho data.file
    debugEcho exc.formatMsg("xxx")
    return false
  except CatchableError as exc:
    if res.error.isSome:
      return true
    debugEcho data.file
    debugEcho exc.msg
    return false

const allowedToFail = [
  # Supports either the specific test file name or all tests for a specific method
  "fee-history.io", # float roundtrip not match
  "eth_simulateV1", # unimplemented
]

suite "Ethereum execution api":
  let testCases = extractTests()
  if testCases.len < 1:
    raise newException(ValueError, "execution_api tests not found, did you clone?")

  var srv = newRpcHttpServer(["127.0.0.1:0"])
  srv.installHandlers()
  srv.start()

  for idx, item in testCases:
    checkpoint item.file & ": " & item.description
    let input = item.input
    let methodName = input.`method`

    test methodName:
      let (_, fileName, ext) = splitFile(item.file)
      let client = newRpcHttpClient()
      waitFor client.connect("http://" & $srv.localAddress()[0])
      let response = waitFor client.callWithParams(item)
      let source = fileName & ext
      if source in allowedToFail or methodName in allowedToFail:
        skip()
      else:
        check response
      waitFor client.close()

  waitFor srv.stop()
  waitFor srv.closeWait()

proc setupMethods(server: RpcServer) =
  server.rpc("eth_getBlockReceipts", EthJson) do(blockId: RtBlockIdentifier) -> Opt[seq[ReceiptObject]]:
    var res: seq[ReceiptObject]
    return Opt.some(res)

suite "Test eth api":
  var srv = newRpcHttpServer(["127.0.0.1:0"])
  srv.setupMethods()
  srv.start()

  test "eth_getBlockReceipts generic functions":
    let client = newRpcHttpClient()
    waitFor client.connect("http://" & $srv.localAddress()[0])
    let res = waitFor client.eth_getBlockReceipts(blockId("latest"))
    check res.isSome
    waitFor client.close()

  test "eth_getBlockReceipts with Quantity param":
    let client = newRpcHttpClient()
    waitFor client.connect("http://" & $srv.localAddress()[0])
    let res = waitFor client.eth_getBlockReceipts(blockId(0))
    check res.isSome
    waitFor client.close()

  test "eth_getBlockReceipts with string param":
    let client = newRpcHttpClient()
    waitFor client.connect("http://" & $srv.localAddress()[0])
    let res = waitFor client.eth_getBlockReceipts("latest")
    check res.isSome
    waitFor client.close()

  waitFor srv.stop()
  waitFor srv.closeWait()

{.pop.}
