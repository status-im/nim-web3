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
  stew/byteutils,
  json_rpc/rpcserver,
  ../../web3/conversions,
  ../../web3/eth_api_types,
  ../../web3/primitives as w3

type
  Hash256 = w3.Hash256

proc installHandlers*(server: RpcServer) =
  server.rpc("eth_syncing") do(x: JsonString, ) -> bool:
    return false

  server.rpc("eth_sendRawTransaction") do(x: JsonString, data: seq[byte]) -> TxHash:
    let tx = rlp.decode(data, Transaction)
    let h = rlpHash(tx)
    return TxHash(h.data)

  server.rpc("eth_getTransactionReceipt") do(x: JsonString, data: TxHash) -> ReceiptObject:
    var r: ReceiptObject
    if x != "-1".JsonString:
      r = JrpcConv.decode(x.string, ReceiptObject)
    return r

  server.rpc("eth_getTransactionByHash") do(x: JsonString, data: TxHash) -> TransactionObject:
    var tx: TransactionObject
    if x != "-1".JsonString:
      tx = JrpcConv.decode(x.string, TransactionObject)
    return tx

  server.rpc("eth_getTransactionByBlockNumberAndIndex") do(x: JsonString, blockId: RtBlockIdentifier, quantity: Quantity) -> TransactionObject:
    var tx: TransactionObject
    if x != "-1".JsonString:
      tx = JrpcConv.decode(x.string, TransactionObject)
    return tx

  server.rpc("eth_getTransactionByBlockHashAndIndex") do(x: JsonString, data: Hash256, quantity: Quantity) -> TransactionObject:
    var tx: TransactionObject
    if x != "-1".JsonString:
      tx = JrpcConv.decode(x.string, TransactionObject)
    return tx

  server.rpc("eth_getTransactionCount") do(x: JsonString, data: Address, blockId: RtBlockIdentifier) -> Quantity:
    if x != "-1".JsonString:
      result = JrpcConv.decode(x.string, Quantity)

  server.rpc("eth_getStorageAt") do(x: JsonString, data: Address, slot: UInt256, blockId: RtBlockIdentifier) -> FixedBytes[32]:
    if x != "-1".JsonString:
      result = JrpcConv.decode(x.string, FixedBytes[32])

  server.rpc("eth_getProof") do(x: JsonString, address: Address, slots: seq[UInt256], blockId: RtBlockIdentifier) -> ProofResponse:
    var p: ProofResponse
    if x != "-1".JsonString:
      p = JrpcConv.decode(x.string, ProofResponse)
    return p

  server.rpc("eth_getCode") do(x: JsonString, data: Address, blockId: RtBlockIdentifier) -> seq[byte]:
    if x != "-1".JsonString:
      result = JrpcConv.decode(x.string, seq[byte])

  server.rpc("eth_getBlockTransactionCountByNumber") do(x: JsonString, blockId: RtBlockIdentifier) -> Quantity:
    if x != "-1".JsonString:
      result = JrpcConv.decode(x.string, Quantity)

  server.rpc("eth_getBlockTransactionCountByHash") do(x: JsonString, data: BlockHash) -> Quantity:
    if x != "-1".JsonString:
      result = JrpcConv.decode(x.string, Quantity)

  server.rpc("eth_getBlockReceipts") do(x: JsonString, blockId: RtBlockIdentifier) -> Option[seq[ReceiptObject]]:
    var r: seq[ReceiptObject]
    if x == "null".JsonString:
      return none(seq[ReceiptObject])
    if x != "-1".JsonString:
      r = JrpcConv.decode(x.string, seq[ReceiptObject])
    return some(r)

  server.rpc("eth_getBlockByNumber") do(x: JsonString, blockId: RtBlockIdentifier, fullTransactions: bool) -> BlockObject:
    var blk: BlockObject
    if x != "-1".JsonString:
      blk = JrpcConv.decode(x.string, BlockObject)
    return blk

  server.rpc("eth_getBlockByHash") do(x: JsonString, data: BlockHash, fullTransactions: bool) -> BlockObject:
    var blk: BlockObject
    if x != "-1".JsonString:
      blk = JrpcConv.decode(x.string, BlockObject)
    return blk

  server.rpc("eth_getBalance") do(x: JsonString, data: Address, blockId: RtBlockIdentifier) -> UInt256:
    if x != "-1".JsonString:
      result = JrpcConv.decode(x.string, UInt256)

  server.rpc("eth_feeHistory") do(x: JsonString, blockCount: Quantity, newestBlock: RtBlockIdentifier, rewardPercentiles: Option[seq[float64]]) -> FeeHistoryResult:
    var fh: FeeHistoryResult
    if x != "-1".JsonString:
      fh = JrpcConv.decode(x.string, FeeHistoryResult)
    return fh

  server.rpc("eth_estimateGas") do(x: JsonString, call: EthCall) -> Quantity:
    if x != "-1".JsonString:
      result = JrpcConv.decode(x.string, Quantity)

  server.rpc("eth_createAccessList") do(x: JsonString, call: EthCall, blockId: RtBlockIdentifier) -> AccessListResult:
    var z: AccessListResult
    if x != "-1".JsonString:
      z = JrpcConv.decode(x.string, AccessListResult)
    return z

  server.rpc("eth_chainId") do(x: JsonString, ) -> Quantity:
    if x != "-1".JsonString:
      result = JrpcConv.decode(x.string, Quantity)

  server.rpc("eth_call") do(x: JsonString, call: EthCall, blockId: RtBlockIdentifier) -> seq[byte]:
    if x != "-1".JsonString:
      result = JrpcConv.decode(x.string, seq[byte])

  server.rpc("eth_blockNumber") do(x: JsonString) -> Quantity:
    if x != "-1".JsonString:
      result = JrpcConv.decode(x.string, Quantity)

  server.rpc("debug_getRawTransaction") do(x: JsonString, data: TxHash) -> RlpEncodedBytes:
    var res: seq[byte]
    if x != "-1".JsonString:
      res = JrpcConv.decode(x.string, seq[byte])
    return res.RlpEncodedBytes

  server.rpc("debug_getRawReceipts") do(x: JsonString, blockId: RtBlockIdentifier) -> seq[RlpEncodedBytes]:
    var res: seq[RlpEncodedBytes]
    if x != "-1".JsonString:
      res = JrpcConv.decode(x.string, seq[RlpEncodedBytes])
    return res

  server.rpc("debug_getRawHeader") do(x: JsonString, blockId: RtBlockIdentifier) -> RlpEncodedBytes:
    var res: seq[byte]
    if x != "-1".JsonString:
      res = JrpcConv.decode(x.string, seq[byte])
    return res.RlpEncodedBytes

  server.rpc("debug_getRawBlock") do(x: JsonString, blockId: RtBlockIdentifier) -> RlpEncodedBytes:
    var res: seq[byte]
    if x != "-1".JsonString:
      res = JrpcConv.decode(x.string, seq[byte])
    return res.RlpEncodedBytes
