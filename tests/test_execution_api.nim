import
  std/[os, strutils],
  pkg/unittest2,
  chronos,
  json_rpc/rpcclient,
  json_rpc/private/jrpc_sys,
  ../web3/conversions

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
  try:
    let resJson = await client.call(data.input.`method`, data.input.params)
    let res = JrpcSys.decode(resJson.string, ResponseRx)
    doAssert(res.result.isSome)

    return true
  except CatchableError as exc:
    debugEcho exc.msg
    return false

suite "Ethereum execution api":
  let testCases = extractTests()
  if testCases.len < 1:
    raise newException(ValueError, "execution_api tests not found, did you clone?")

  var srv = newRpcWebSocketServer("127.0.0.1", Port(0))
  srv.installHandlers()
  srv.start()

  for item in testCases:
    let input = item.input
    let methodName = input.`method`

    let (directory, _, _) = splitFile(item.file)

    suite directory:
      test methodName:
        proc doTest() {.async.} =
           let client = newRpcWebSocketClient()
           await client.connect("ws://" & $srv.localAddress())
           let response = await client.callWithParams(item)

          if not response:
            fail()

          await client.close()

        waitFor doTest()

  srv.stop()
  waitFor srv.closeWait()
