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
    input: RequestTx
    output: ResponseRx

const
  inputPath = "tests/execution-apis/tests"

func strip(line: string): string =
  return line[3..^1]

func toTx(req: RequestRx): RequestTx =
  RequestTx(
    id: Opt.some(req.id),
    `method`: req.`method`.get(),
    params: req.params.toTx,
  )

proc extractTest(fileName: string): TestData =
  let
    lines = readFile(fileName).split("\n")
    input = lines[0].strip()
    output = lines[1].strip()

  return (
    file: fileName,
    input: JrpcSys.decode(input, RequestRx).toTx,
    output: JrpcSys.decode(output, ResponseRx),
  )

proc extractTests(): seq[TestData] =
  for fileName in walkDirRec(inputPath):
    if fileName.endsWith(".io"):
      result.add(fileName.extractTest())

proc callWithParams(client: RpcClient, data: TestData): Future[bool] {.async.} =
  let res = data.output

  try:
    var params = data.input.params
    if data.output.result.string.len > 0:
      let jsonBytes = JrpcConv.encode(data.output.result.string)
      params.positional.insert(jsonBytes.JsonString, 0)
    else:
      params.positional.insert("-1".JsonString, 0)

    let resJson = await client.call(data.input.`method`, params)

    if res.result.string.len > 0:
      let wantVal = JrpcConv.decode(res.result.string, JsonValueRef[string])
      let getVal = JrpcConv.decode(resJson.string, JsonValueRef[string])

      if wantVal != getVal:
        debugEcho data.file
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
  "fee-history.io" # float roundtrip not match
]

suite "Ethereum execution api":
  let testCases = extractTests()
  if testCases.len < 1:
    raise newException(ValueError, "execution_api tests not found, did you clone?")

  var srv = newRpcHttpServer(["127.0.0.1:0"])
  srv.installHandlers()
  srv.start()

  for idx, item in testCases:
    let input = item.input
    let methodName = input.`method`

    test methodName:
      let (_, fileName, ext) = splitFile(item.file)
      let client = newRpcHttpClient()
      waitFor client.connect("http://" & $srv.localAddress()[0])
      let response = waitFor client.callWithParams(item)
      let source = fileName & ext
      if source in allowedToFail:
        check true
      else:
        check response
      waitFor client.close()

  waitFor srv.stop()
  waitFor srv.closeWait()

proc setupMethods(server: RpcServer) =
  server.rpc("eth_getBlockReceipts") do(blockId: RtBlockIdentifier) -> Opt[seq[ReceiptObject]]:
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

  waitFor srv.stop()
  waitFor srv.closeWait()
