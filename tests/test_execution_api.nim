import os
import macros
import system/io
import strutils
import pkg/unittest2
import ../web3
import json_rpc/rpcclient
import chronos, options, json, stint
import test_utils

import random

type TestData = tuple
  file: string
  input: JsonNode
  output: JsonNode

func strip(line: string): string =
  return line[3..^1]

proc extract_test(filename: string): TestData =
  let lines = readFile(filename).split("\n")

  return (
    file: filename,
    input: lines[0].strip().parseJson(),
    output: lines[1].strip().parseJson()
  )

proc extract_tests(): seq[TestData] =
  var to_return: seq[TestData] = @[]

  for filename in walkDirRec("./execution-apis/tests"):
    if filename.endsWith(".io"):
      to_return.add(extract_test(filename))

  return to_return

##
## Start of our test callers
##
proc test_debug_getRawBlock(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.debug_getRawBlock(item.input["params"][0].getStr())
  return false

proc test_debug_getRawHeader(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.debug_getRawHeader(item.input["params"][0].getStr())
  return false

proc test_debug_getRawReceipts(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.debug_getRawReceipts(item.input["params"][0].getStr())
  return true

proc test_debug_getRawTransaction(web3: Web3, item: TestData): Future[bool] {.async.} =
  let result = await web3.provider.debug_getRawTransaction(item.input["params"][0].getStr())
  return true

proc test_eth_accounts(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_blockNumber(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_call(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_chainId(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_coinbase(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_compileLLL(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_compileSerpent(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_compileSolidity(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_createAccessList(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_estimateGas(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_feeHistory(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_gasPrice(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getBalance(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getBlockByHash(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getBlockByNumber(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getBlockTransactionCountByHash(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getBlockTransactionCountByNumber(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getCode(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getCompilers(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getFilterChanges(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getFilterLogs(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getLogs(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getProof(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getStorageAt(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getTransactionByBlockHashAndIndex(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getTransactionByBlockNumberAndIndex(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getTransactionByHash(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getTransactionCount(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getTransactionReceipt(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getUncleByBlockHashAndIndex(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getUncleByBlockNumberAndIndex(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getUncleCountByBlockHash(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getUncleCountByBlockNumber(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_getWork(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_hashrate(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_mining(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_newBlockFilter(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_newFilter(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_newPendingTransactionFilter(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_protocolVersion(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_sendRawTransaction(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_sendTransaction(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_sign(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_submitHashrate(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_submitWork(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_subscribe(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_syncing(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_uninstallFilter(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_eth_unsubscribe(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_net_listening(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_net_peerCount(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_net_version(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_shh_addToGroup(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_shh_getFilterChanges(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_shh_getMessages(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_shh_hasIdentity(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_shh_newFilter(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_shh_newGroup(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_shh_newIdentity(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_shh_post(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_shh_uninstallFilter(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_shh_version(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_web3_clientVersion(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

proc test_web3_sha3(web3: Web3, item: TestData): Future[bool] {.async.} =
  return false

##
## Lookup table for test callers
##
proc call_api(web3: Web3, item: TestData): Future[bool] {.async.} =
  case item.input["method"].get_str():
    of "debug_getRawBlock": test_debug_getRawBlock(web3, item)
    of "debug_getRawHeader": test_debug_getRawHeader(web3, item)
    of "debug_getRawReceipts": test_debug_getRawReceipts(web3, item)
    of "debug_getRawTransaction": test_debug_getRawTransaction(web3, item)
    of "eth_accounts": test_eth_accounts(web3, item)
    of "eth_blockNumber": test_eth_blockNumber(web3, item)
    of "eth_call": test_eth_call(web3, item)
    of "eth_chainId": test_eth_chainId(web3, item)
    of "eth_coinbase": test_eth_coinbase(web3, item)
    of "eth_compileLLL": test_eth_compileLLL(web3, item)
    of "eth_compileSerpent": test_eth_compileSerpent(web3, item)
    of "eth_compileSolidity": test_eth_compileSolidity(web3, item)
    of "eth_createAccessList": test_eth_createAccessList(web3, item)
    of "eth_estimateGas": test_eth_estimateGas(web3, item)
    of "eth_feeHistory": test_eth_feeHistory(web3, item)
    of "eth_gasPrice": test_eth_gasPrice(web3, item)
    of "eth_getBalance": test_eth_getBalance(web3, item)
    of "eth_getBlockByHash": test_eth_getBlockByHash(web3, item)
    of "eth_getBlockByNumber": test_eth_getBlockByNumber(web3, item)
    of "eth_getBlockTransactionCountByHash": test_eth_getBlockTransactionCountByHash(web3, item)
    of "eth_getBlockTransactionCountByNumber": test_eth_getBlockTransactionCountByNumber(web3, item)
    of "eth_getCode": test_eth_getCode(web3, item)
    of "eth_getCompilers": test_eth_getCompilers(web3, item)
    of "eth_getFilterChanges": test_eth_getFilterChanges(web3, item)
    of "eth_getFilterLogs": test_eth_getFilterLogs(web3, item)
    of "eth_getLogs": test_eth_getLogs(web3, item)
    of "eth_getProof": test_eth_getProof(web3, item)
    of "eth_getStorageAt": test_eth_getStorageAt(web3, item)
    of "eth_getTransactionByBlockHashAndIndex": test_eth_getTransactionByBlockHashAndIndex(web3, item)
    of "eth_getTransactionByBlockNumberAndIndex": test_eth_getTransactionByBlockNumberAndIndex(web3, item)
    of "eth_getTransactionByHash": test_eth_getTransactionByHash(web3, item)
    of "eth_getTransactionCount": test_eth_getTransactionCount(web3, item)
    of "eth_getTransactionReceipt": test_eth_getTransactionReceipt(web3, item)
    of "eth_getUncleByBlockHashAndIndex": test_eth_getUncleByBlockHashAndIndex(web3, item)
    of "eth_getUncleByBlockNumberAndIndex": test_eth_getUncleByBlockNumberAndIndex(web3, item)
    of "eth_getUncleCountByBlockHash": test_eth_getUncleCountByBlockHash(web3, item)
    of "eth_getUncleCountByBlockNumber": test_eth_getUncleCountByBlockNumber(web3, item)
    of "eth_getWork": test_eth_getWork(web3, item)
    of "eth_hashrate": test_eth_hashrate(web3, item)
    of "eth_mining": test_eth_mining(web3, item)
    of "eth_newBlockFilter": test_eth_newBlockFilter(web3, item)
    of "eth_newFilter": test_eth_newFilter(web3, item)
    of "eth_newPendingTransactionFilter": test_eth_newPendingTransactionFilter(web3, item)
    of "eth_protocolVersion": test_eth_protocolVersion(web3, item)
    of "eth_sendRawTransaction": test_eth_sendRawTransaction(web3, item)
    of "eth_sendTransaction": test_eth_sendTransaction(web3, item)
    of "eth_sign": test_eth_sign(web3, item)
    of "eth_submitHashrate": test_eth_submitHashrate(web3, item)
    of "eth_submitWork": test_eth_submitWork(web3, item)
    of "eth_subscribe": test_eth_subscribe(web3, item)
    of "eth_syncing": test_eth_syncing(web3, item)
    of "eth_uninstallFilter": test_eth_uninstallFilter(web3, item)
    of "eth_unsubscribe": test_eth_unsubscribe(web3, item)
    of "net_listening": test_net_listening(web3, item)
    of "net_peerCount": test_net_peerCount(web3, item)
    of "net_version": test_net_version(web3, item)
    of "shh_addToGroup": test_shh_addToGroup(web3, item)
    of "shh_getFilterChanges": test_shh_getFilterChanges(web3, item)
    of "shh_getMessages": test_shh_getMessages(web3, item)
    of "shh_hasIdentity": test_shh_hasIdentity(web3, item)
    of "shh_newFilter": test_shh_newFilter(web3, item)
    of "shh_newGroup": test_shh_newGroup(web3, item)
    of "shh_newIdentity": test_shh_newIdentity(web3, item)
    of "shh_post": test_shh_post(web3, item)
    of "shh_uninstallFilter": test_shh_uninstallFilter(web3, item)
    of "shh_version": test_shh_version(web3, item)
    of "web3_clientVersion": test_web3_clientVersion(web3, item)
    of "web3_sha3": test_web3_sha3(web3, item)
    else:
      raise newException(ValueError, "Invalid API call")


const excluded_tests = [
  # TODO: These seem to be unsupported in ganache
  "debug_getRawBlock",
  "debug_getRawHeader",
  "debug_getRawReceipts",
  "debug_getRawTransaction",
]

suite "Ethereum execution api":
  for item in extract_tests():
    let input = item.input
    let method_name = input["method"].get_str()

    let (directory, filename, ext) = splitFile(item.file)

    if lastPathPart(directory) in excluded_tests:
      continue

    suite directory:
      test filename:
        proc do_test() {.async.} =
          let web3 = await newWeb3("ws://127.0.0.1:8545/")
          if not await web3.call_api(item):
            fail()

          echo "--------------------------------------------------"

        waitFor do_test()
