# json-rpc
# Copyright (c) 2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  stint,
  eth/common,
  json_rpc/rpcserver,
  ../../web3/conversions,
  ../../web3/eth_api_types,
  ../../web3/primitives as w3,
  ./min_blobtx_rlp

type
  Hash32 = w3.Hash32
  Address = w3.Address
  FixedBytes[N: static int] = w3.FixedBytes[N]

func decodeFromString(x: JsonString, T: type): T =
  let jsonBytes = EthJson.decode(x.string, string)
  result = EthJson.decode(jsonBytes, T)

proc installHandlers*(server: RpcServer) =
  server.rpc("eth_syncing", EthJson) do(x: JsonString) -> SyncingStatus:
    return SyncingStatus(syncing: false)

  server.rpc("eth_sendRawTransaction", EthJson) do(x: JsonString, data: seq[byte]) -> Hash32:
    let tx = rlp.decode(data, BlobTransaction)
    let h = computeRlpHash(tx.tx)
    return Hash32(h.data)

  server.rpc("eth_getTransactionReceipt", EthJson) do(x: JsonString, data: Hash32) -> ReceiptObject:
    var r: ReceiptObject
    if x != "-1".JsonString:
      r = decodeFromString(x, ReceiptObject)
    return r

  server.rpc("eth_getTransactionByHash", EthJson) do(x: JsonString, data: Hash32) -> TransactionObject:
    var tx: TransactionObject
    if x != "-1".JsonString:
      tx = decodeFromString(x, TransactionObject)
    return tx

  server.rpc("eth_getTransactionByBlockNumberAndIndex", EthJson) do(x: JsonString, blockId: RtBlockIdentifier, quantity: Quantity) -> TransactionObject:
    var tx: TransactionObject
    if x != "-1".JsonString:
      tx = decodeFromString(x, TransactionObject)
    return tx

  server.rpc("eth_getTransactionByBlockHashAndIndex", EthJson) do(x: JsonString, data: Hash32, quantity: Quantity) -> TransactionObject:
    var tx: TransactionObject
    if x != "-1".JsonString:
      tx = decodeFromString(x, TransactionObject)
    return tx

  server.rpc("eth_getTransactionCount", EthJson) do(x: JsonString, data: Address, blockId: RtBlockIdentifier) -> Quantity:
    if x != "-1".JsonString:
      result = decodeFromString(x, Quantity)

  server.rpc("eth_getStorageAt", EthJson) do(x: JsonString, data: Address, slot: UInt256, blockId: RtBlockIdentifier) -> FixedBytes[32]:
    if x != "-1".JsonString:
      result = decodeFromString(x, FixedBytes[32])

  server.rpc("eth_getProof", EthJson) do(x: JsonString, address: Address, slots: seq[UInt256], blockId: RtBlockIdentifier) -> ProofResponse:
    var p: ProofResponse
    if x != "-1".JsonString:
      p = decodeFromString(x, ProofResponse)
    return p

  server.rpc("eth_getCode", EthJson) do(x: JsonString, data: Address, blockId: RtBlockIdentifier) -> seq[byte]:
    if x != "-1".JsonString:
      result = decodeFromString(x, seq[byte])

  server.rpc("eth_getBlockTransactionCountByNumber", EthJson) do(x: JsonString, blockId: RtBlockIdentifier) -> Quantity:
    if x != "-1".JsonString:
      result = decodeFromString(x, Quantity)

  server.rpc("eth_getBlockTransactionCountByHash", EthJson) do(x: JsonString, data: Hash32) -> Quantity:
    if x != "-1".JsonString:
      result = decodeFromString(x, Quantity)

  server.rpc("eth_getBlockReceipts", EthJson) do(x: JsonString, blockId: RtBlockIdentifier) -> Opt[seq[ReceiptObject]]:
    if x != "-1".JsonString:
      let r = decodeFromString(x, Opt[seq[ReceiptObject]])
      return r

  server.rpc("eth_getBlockByNumber", EthJson) do(x: JsonString, blockId: RtBlockIdentifier, fullTransactions: bool) -> BlockObject:
    var blk: BlockObject
    if x != "-1".JsonString:
      blk = decodeFromString(x, BlockObject)
    return blk

  server.rpc("eth_getBlockByHash", EthJson) do(x: JsonString, data: Hash32, fullTransactions: bool) -> BlockObject:
    var blk: BlockObject
    if x != "-1".JsonString:
      blk = decodeFromString(x, BlockObject)
    return blk

  server.rpc("eth_getBalance", EthJson) do(x: JsonString, data: Address, blockId: RtBlockIdentifier) -> UInt256:
    if x != "-1".JsonString:
      result = decodeFromString(x, UInt256)

  server.rpc("eth_feeHistory", EthJson) do(x: JsonString, blockCount: Quantity, newestBlock: RtBlockIdentifier, rewardPercentiles: Opt[seq[float64]]) -> FeeHistoryResult:
    var fh: FeeHistoryResult
    if x != "-1".JsonString:
      fh = decodeFromString(x, FeeHistoryResult)
    return fh

  server.rpc("eth_estimateGas", EthJson) do(x: JsonString, call: TransactionArgs) -> Quantity:
    if x != "-1".JsonString:
      result = decodeFromString(x, Quantity)

  server.rpc("eth_createAccessList", EthJson) do(x: JsonString, call: TransactionArgs, blockId: RtBlockIdentifier) -> AccessListResult:
    var z: AccessListResult
    if x != "-1".JsonString:
      z = decodeFromString(x, AccessListResult)
    return z

  server.rpc("eth_chainId", EthJson) do(x: JsonString, ) -> Quantity:
    if x != "-1".JsonString:
      result = decodeFromString(x, Quantity)

  server.rpc("eth_call", EthJson) do(x: JsonString, call: TransactionArgs, blockId: RtBlockIdentifier) -> seq[byte]:
    if x != "-1".JsonString:
      result = decodeFromString(x, seq[byte])

  server.rpc("eth_blockNumber", EthJson) do(x: JsonString) -> Quantity:
    if x != "-1".JsonString:
      result = decodeFromString(x, Quantity)

  server.rpc("debug_getRawTransaction", EthJson) do(x: JsonString, data: Bytes32) -> RlpEncodedBytes:
    var res: seq[byte]
    if x != "-1".JsonString:
      res = decodeFromString(x, seq[byte])
    return res.RlpEncodedBytes

  server.rpc("debug_getRawReceipts", EthJson) do(x: JsonString, blockId: RtBlockIdentifier) -> seq[RlpEncodedBytes]:
    var res: seq[RlpEncodedBytes]
    if x != "-1".JsonString:
      res = decodeFromString(x, seq[RlpEncodedBytes])
    return res

  server.rpc("debug_getRawHeader", EthJson) do(x: JsonString, blockId: RtBlockIdentifier) -> RlpEncodedBytes:
    var res: seq[byte]
    if x != "-1".JsonString:
      res = decodeFromString(x, seq[byte])
    return res.RlpEncodedBytes

  server.rpc("debug_getRawBlock", EthJson) do(x: JsonString, blockId: RtBlockIdentifier) -> RlpEncodedBytes:
    var res: seq[byte]
    if x != "-1".JsonString:
      res = decodeFromString(x, seq[byte])
    return res.RlpEncodedBytes

  server.rpc("eth_blobBaseFee", EthJson) do(x: JsonString) -> Quantity:
    if x != "-1".JsonString:
      return decodeFromString(x, Quantity)

  server.rpc("eth_getLogs", EthJson) do(x: JsonString, filterOptions: FilterOptions) -> seq[LogObject]:
    if x != "-1".JsonString:
      return decodeFromString(x, seq[LogObject])
