import os
import pkg/unittest2
import strutils
import system/io
import chronos, options, json, stint

import stew/byteutils
import json_rpc/rpcclient

import ../web3
import ../web3/ethtypes
import ../web3/conversions


type TestData = tuple
  file: string
  input: JsonNode
  output: JsonNode

func strip(line: string): string =
  return line[3..^1]

proc extract_test(filename: string): TestData =
  let lines = readFile(filename).split("\n")

  # FIXME
  # TODO: This is broken because nimbus uses "source"
  #       whereas the ethereum api spec always uses "from"
  #       We can't easily change everything in the remaining
  #       time so we change here for now
  let input_str = lines[0].strip().replace("from", "source")
  let output_str = lines[1].strip().replace("from", "source")

  return (
    file: filename,
    input: input_str.parseJson(),
    output: output_str.parseJson(),
  )

proc extract_tests(): seq[TestData] =
  var to_return: seq[TestData] = @[]

  for filename in walkDirRec(getCurrentDir() & "/tests/execution-apis/tests"):
    if filename.endsWith(".io"):
      to_return.add(extract_test(filename))

  return to_return

func hasParam(item: TestData, index: int): bool =
  return item.input["params"].len > index

func getParam(item: TestData, index: int): JsonNode =
  return item.input["params"][index]

func getParamStr(item: TestData, index: int): string =
  return item.getParam(index).getStr()

func getParamInt(item: TestData, index: int): int =
  return item.getParam(index).getInt()

func getParamBool(item: TestData, index: int): bool =
  return item.getParam(index).getBool()

func getParamArray(item: TestData, index: int): seq[JsonNode] =
  return item.getParam(index).getElems()

func getParamEthCall*(item: TestData, index: int): EthCall =
  let param = item.getParam(index)

  result.to = Address.fromHex(param["to"].getStr())

  if "source" in param:
    result.source = some(Address.fromHex(param["source"].getStr()))
  if "gas" in param:
    result.gas = some(Quantity(param["gas"].getInt()))
  if "gasPrice" in param:
    result.gasPrice = some(param["gasPrice"].getInt())
  if "value" in param:
    result.value = some(param["value"].getInt().u256)
  if "data" in param:
    result.data = some(param["data"].getStr())

func getParamBlockIdentifier(item: TestData, index: int): BlockIdentifier =
  return BlockIdentifier(item.getParamStr(index))

func toString(itemlist: seq[JsonNode]): seq[string] =
  var to_return: seq[string]

  for item in itemlist:
    to_return.add(item.getStr())

  return to_return

func toUInt256(itemlist: seq[JsonNode]): seq[UInt256] =
  var to_return: seq[UInt256]

  for item in itemlist:
    to_return.add(item.getInt().u256)

  return to_return

##
## Start of our test callers
##
proc test_debug_getRawBlock(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.debug_getRawBlock(item.getParamStr(0))
  return false

proc test_debug_getRawHeader(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.debug_getRawHeader(item.getParamStr(0))
  return false

proc test_debug_getRawReceipts(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.debug_getRawReceipts(item.getParamStr(0))
  return true

proc test_debug_getRawTransaction(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.debug_getRawTransaction(item.getParamStr(0))
  return true

proc test_eth_accounts(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_accounts()
  return true

proc test_eth_blockNumber(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_blockNumber()
  return true

proc test_eth_call(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_call(
      item.getParamEthCall(0),
      item.getParamBlockIdentifier(1)
  )
  return false

proc test_eth_chainId(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_chainId()
  return true

proc test_eth_coinbase(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_coinbase()
  return true

proc test_eth_compileLLL(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_compileLLL()
  return true

proc test_eth_compileSerpent(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_compileSerpent()
  return true

proc test_eth_compileSolidity(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_compileSolidity()
  return true

proc test_eth_createAccessList(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_createAccessList(
    item.getParamEthCall(0),
    item.getParamBlockIdentifier(1)
  )
  return false

proc test_eth_estimateGas(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_estimateGas(
    item.getParamEthCall(0),
    item.getParamBlockIdentifier(1)
  )
  return true

proc test_eth_feeHistory(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_feeHistory(
    item.getParamStr(0),
    item.getParamStr(1),
    item.getParamArray(2).toString()
  )
  return true

proc test_eth_gasPrice(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_gasPrice(
  )
  return true

proc test_eth_getBalance(web3: Web3, item: TestData): Future[bool] {.async.} =
  let balance = await web3.provider.eth_getBalance(
    Address.fromHex(item.getParamStr(0)),
    item.getParamBlockIdentifier(1)
  )

  check(balance >= 0)
  return true

proc test_eth_getBlockByHash(web3: Web3, item: TestData): Future[bool] {.async.} =
  expect(ValueError):
    discard await web3.provider.eth_getBlockByHash(
      BlockHash.fromHex(item.getParamStr(0)),
      item.getParamBool(1)
    )
  return true

proc test_eth_getBlockByNumber(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_getBlockByNumber(
    item.getParamBlockIdentifier(0),
    item.getParamBool(1)
  )
  return true

proc test_eth_getBlockTransactionCountByHash(web3: Web3, item: TestData): Future[bool] {.async.} =
  # TODO: Add block hash
  expect(ValueError):
    discard await web3.provider.eth_getBlockTransactionCountByHash(
      BlockHash.fromHex(item.getParamStr(0))
    )
  return true

proc test_eth_getBlockTransactionCountByNumber(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_getBlockTransactionCountByNumber(
      item.getParamBlockIdentifier(0)
  )
  return true

proc test_eth_getCode(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_getCode(
      Address.fromHex(item.getParamStr(0)),
      item.getParamBlockIdentifier(1)
  )
  return true

proc test_eth_getCompilers(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_getCompilers()
  return true

proc test_eth_getFilterChanges(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_getFilterChanges(
      item.getParamStr(0)
  )
  return true

proc test_eth_getFilterLogs(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_getFilterLogs(
      item.getParamStr(0)
  )
  return true

# proc test_eth_getLogs(web3: Web3, item: TestData): Future[bool] {.async.} =
#   let result = await web3.provider.eth_getLogs()
#   return true

proc test_eth_getProof(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_getProof(
    Address.fromHex(item.getParamStr(0)),
    item.getParamArray(1).toUInt256(),
    item.getParamBlockIdentifier(2)
  )
  return true

proc test_eth_getStorageAt(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_getStorageAt(
    Address.fromHex(item.getParamStr(0)),
    item.getParamInt(1),
    item.getParamBlockIdentifier(2)
  )
  return true

proc test_eth_getTransactionByBlockHashAndIndex(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_getTransactionByBlockHashAndIndex(
    item.getParamInt(0).u256,
    item.getParamInt(1)
  )
  return true

proc test_eth_getTransactionByBlockNumberAndIndex(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_getTransactionByBlockNumberAndIndex(
    item.getParamBlockIdentifier(0),
    item.getParamInt(1)
  )
  return true

proc test_eth_getTransactionByHash(web3: Web3, item: TestData): Future[bool] {.async.} =
  expect(ValueError):
    discard await web3.provider.eth_getTransactionByHash(
      TxHash.fromHex(item.getParamStr(0))
    )
  return true

proc test_eth_getTransactionCount(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_getTransactionCount(
    Address.fromHex(item.getParamStr(0)),
    item.getParamBlockIdentifier(1),
  )
  return true

proc test_eth_getTransactionReceipt(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_getTransactionReceipt(
    TxHash.fromHex(item.getParamStr(0))
  )
  return true

proc test_eth_getUncleByBlockHashAndIndex(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_getUncleByBlockHashAndIndex(
    item.getParamInt(0).u256,
    item.getParamInt(1),
  )
  return true

proc test_eth_getUncleByBlockNumberAndIndex(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_getUncleByBlockNumberAndIndex(
    item.getParamBlockIdentifier(0),
    item.getParamInt(1),
  )
  return true

proc test_eth_getUncleCountByBlockHash(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_getUncleCountByBlockHash(
    BlockHash.fromHex(item.getParamStr(0))
  )
  return true

proc test_eth_getUncleCountByBlockNumber(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_getUncleCountByBlockNumber(
    item.getParamBlockIdentifier(0)
  )
  return true

proc test_eth_getWork(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_getWork()
  return true

proc test_eth_hashrate(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_hashrate()
  return true

proc test_eth_mining(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_mining()
  return true

proc test_eth_newBlockFilter(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_newBlockFilter()
  return true

proc test_eth_newFilter(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_newFilter(to(item.getParam(0), FilterOptions))
  return true

proc test_eth_newPendingTransactionFilter(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_newPendingTransactionFilter()
  return true

proc test_eth_protocolVersion(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_protocolVersion()
  return true

proc test_eth_sendRawTransaction(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_sendRawTransaction(
    item.getParamStr(0)
  )
  return true

proc test_eth_sendTransaction(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_sendTransaction(
    to(item.getParam(0), EthSend)
  )
  return true

proc test_eth_sign(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_sign(
    Address.fromHex(item.getParamStr(0)),
    item.getParamStr(1)
  )
  return true

proc test_eth_submitHashrate(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_submitHashRate(
    item.getParamInt(0).u256,
    item.getParamInt(1).u256
  )
  return true

proc test_eth_submitWork(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_submitWork(
    item.getParamInt(0),
    item.getParamInt(1).u256,
    item.getParamInt(2).u256
  )
  return true

proc test_eth_subscribe(web3: Web3, item: TestData): Future[bool] {.async.} =
  if item.hasParam(1):
    let result = await web3.provider.eth_subscribe(
      item.getParamStr(0),
      item.getParam(1)
    )

  else:
    let result = await web3.provider.eth_subscribe(
      item.getParamStr(0)
    )

  return true

proc test_eth_syncing(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_syncing()
  return true

proc test_eth_uninstallFilter(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_uninstallFilter(
    item.getParamStr(0)
  )
  return true

proc test_eth_unsubscribe(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.eth_unsubscribe(
    item.getParamStr(0)
  )
  return true

proc test_net_listening(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.net_listening()
  return true

proc test_net_peerCount(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.net_peerCount()
  return true

proc test_net_version(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.net_version()
  return true

# proc test_shh_addToGroup(web3: Web3, item: TestData): Future[bool] {.async.} =
#   let result = await web3.provider.shh_addToGroup(
#   )
#   return true

proc test_shh_getFilterChanges(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.shh_getFilterChanges(
    item.getParamInt(0)
  )
  return true

proc test_shh_getMessages(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.shh_getMessages(
    item.getParamInt(0)
  )
  return true

proc test_shh_hasIdentity(web3: Web3, item: TestData): Future[bool] {.async.} =
  # TODO: Array version
  # let result = await web3.provider.shh_hasIdentity()
  return true

proc test_shh_newFilter(web3: Web3, item: TestData): Future[bool] {.async.} =
  # TODO
  # let result = await web3.provider.shh_newFilter()
  return true

proc test_shh_newGroup(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.shh_newGroup()
  return true

proc test_shh_newIdentity(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.shh_newIdentity()
  return true

proc test_shh_post(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.shh_post()
  return true

proc test_shh_uninstallFilter(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.shh_uninstallFilter(
    item.getParamInt(0)
  )
  return true

proc test_shh_version(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.shh_version(to(item.getParam(0), WhisperPost))
  return true

proc test_web3_clientVersion(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.web3_clientVersion()
  return true

proc test_web3_sha3(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.web3_sha3(item.getParamStr(0))
  return true

##
## Lookup table for test callers
##
proc call_api(web3: Web3, item: TestData): Future[bool] {.async.} =
  let test_function = item.input["method"].get_str()

  case test_function:
    of "debug_getRawBlock": return await test_debug_getRawBlock(web3, item)
    of "debug_getRawHeader": return await test_debug_getRawHeader(web3, item)
    of "debug_getRawReceipts": return await test_debug_getRawReceipts(web3, item)
    of "debug_getRawTransaction": return await test_debug_getRawTransaction(web3, item)
    of "eth_accounts": return await test_eth_accounts(web3, item)
    of "eth_blockNumber": return await test_eth_blockNumber(web3, item)
    of "eth_chainId": return await test_eth_chainId(web3, item)
    of "eth_coinbase": return await test_eth_coinbase(web3, item)
    of "eth_compileLLL": return await test_eth_compileLLL(web3, item)
    of "eth_compileSerpent": return await test_eth_compileSerpent(web3, item)
    of "eth_compileSolidity": return await test_eth_compileSolidity(web3, item)
    of "eth_gasPrice": return await test_eth_gasPrice(web3, item)
    of "eth_getBalance": return await test_eth_getBalance(web3, item)
    of "eth_getBlockByHash": return await test_eth_getBlockByHash(web3, item)
    of "eth_getBlockTransactionCountByHash": return await test_eth_getBlockTransactionCountByHash(web3, item)
    of "eth_getCode": return await test_eth_getCode(web3, item)
    of "eth_getCompilers": return await test_eth_getCompilers(web3, item)
    of "eth_getFilterChanges": return await test_eth_getFilterChanges(web3, item)
    of "eth_getFilterLogs": return await test_eth_getFilterLogs(web3, item)
    of "eth_getTransactionByHash": return await test_eth_getTransactionByHash(web3, item)
    of "eth_getTransactionCount": return await test_eth_getTransactionCount(web3, item)
    of "eth_getTransactionReceipt": return await test_eth_getTransactionReceipt(web3, item)
    of "eth_getUncleByBlockHashAndIndex": return await test_eth_getUncleByBlockHashAndIndex(web3, item)
    of "eth_getUncleByBlockNumberAndIndex": return await test_eth_getUncleByBlockNumberAndIndex(web3, item)
    of "eth_getUncleCountByBlockHash": return await test_eth_getUncleCountByBlockHash(web3, item)
    of "eth_getUncleCountByBlockNumber": return await test_eth_getUncleCountByBlockNumber(web3, item)
    of "eth_getWork": return await test_eth_getWork(web3, item)
    of "eth_hashrate": return await test_eth_hashrate(web3, item)
    of "eth_mining": return await test_eth_mining(web3, item)
    of "eth_newBlockFilter": return await test_eth_newBlockFilter(web3, item)
    of "eth_newFilter": return await test_eth_newFilter(web3, item)
    of "eth_newPendingTransactionFilter": return await test_eth_newPendingTransactionFilter(web3, item)
    of "eth_protocolVersion": return await test_eth_protocolVersion(web3, item)
    of "eth_sendTransaction": return await test_eth_sendTransaction(web3, item)
    of "eth_sign": return await test_eth_sign(web3, item)
    of "eth_submitHashrate": return await test_eth_submitHashrate(web3, item)
    of "eth_submitWork": return await test_eth_submitWork(web3, item)
    of "eth_subscribe": return await test_eth_subscribe(web3, item)
    of "eth_syncing": return await test_eth_syncing(web3, item)
    of "eth_uninstallFilter": return await test_eth_uninstallFilter(web3, item)
    of "eth_unsubscribe": return await test_eth_unsubscribe(web3, item)
    of "net_listening": return await test_net_listening(web3, item)
    of "net_peerCount": return await test_net_peerCount(web3, item)
    of "net_version": return await test_net_version(web3, item)
    of "shh_getFilterChanges": return await test_shh_getFilterChanges(web3, item)
    of "shh_getMessages": return await test_shh_getMessages(web3, item)
    of "shh_newGroup": return await test_shh_newGroup(web3, item)
    of "shh_newIdentity": return await test_shh_newIdentity(web3, item)
    of "shh_post": return await test_shh_post(web3, item)
    of "shh_uninstallFilter": return await test_shh_uninstallFilter(web3, item)
    of "shh_version": return await test_shh_version(web3, item)
    of "web3_clientVersion": return await test_web3_clientVersion(web3, item)
    of "web3_sha3": return await test_web3_sha3(web3, item)

    # FIXME
    # TODO: Buggy
    #
    # (Uneven hex string length)
    # of "eth_getStorageAt": return await test_eth_getStorageAt(web3, item)
    # (index error)
    # of "eth_estimateGas": return await test_eth_estimateGas(web3, item)
    # (Crashes when returning null)
    # of "eth_getBlockByNumber": return await test_eth_getBlockByNumber(web3, item)
    # (Need to set gas price first)
    # of "eth_call": return await test_eth_call(web3, item)

    # TODO: Implementation
    #
    # of "eth_getLogs": return await test_eth_getLogs(web3, item)
    # of "shh_addToGroup": return await test_shh_addToGroup(web3, item)
    # of "shh_hasIdentity": return await test_shh_hasIdentity(web3, item)
    # of "shh_newFilter": return await test_shh_newFilter(web3, item)
    # of "eth_sendRawTransaction": return await test_eth_sendRawTransaction(web3, item)

    # TODO: Needs transaction
    # of "eth_getTransactionByBlockNumberAndIndex": return await test_eth_getTransactionByBlockNumberAndIndex(web3, item)
    # of "eth_getBlockTransactionCountByNumber": return await test_eth_getBlockTransactionCountByNumber(web3, item)
    # of "eth_getTransactionByBlockHashAndIndex": return await test_eth_getTransactionByBlockHashAndIndex(web3, item)

    # NOTE: Not supported
    # of "eth_getProof": return await test_eth_getProof(web3, item)
    # of "eth_feeHistory": return await test_eth_feeHistory(web3, item)
    # of "eth_createAccessList": return await test_eth_createAccessList(web3, item)

    else:
      echo(test_function, " is not yet implemented")
      return true


const excluded_tests = [
  # TODO: These seem to be unsupported in ganache
  "debug_getRawBlock",
  "debug_getRawHeader",
  "debug_getRawReceipts",
  "debug_getRawTransaction",
]

let all_tests = extract_tests()
if all_tests.len < 1:
  raise newException(ValueError, "execution_api tests not found, did you clone?")

suite "Ethereum execution api":
  for item in all_tests:
    let input = item.input
    let method_name = input["method"].get_str()

    let (directory, filename, ext) = splitFile(item.file)

    if lastPathPart(directory) in excluded_tests:
      continue

    suite directory:
      test method_name:
        proc do_test() {.async.} =
          let web3 = await newWeb3("ws://127.0.0.1:8545/")
          let response = await web3.call_api(item)

          if not response:
            fail()

        waitFor do_test()
