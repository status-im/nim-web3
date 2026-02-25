# json-rpc
# Copyright (c) 2024-2026 Status Research & Development GmbH
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
  server.rpc(EthJson):
    proc eth_syncing(x: JsonString): SyncingStatus {.async: (raises: []).} =
      return SyncingStatus(syncing: false)

    proc eth_sendRawTransaction(x: JsonString, data: seq[byte]): Hash32 {.async: (raises: [RlpError]).} =
      let tx = rlp.decode(data, BlobTransaction)
      let h = computeRlpHash(tx.tx)
      return Hash32(h.data)

    proc eth_getTransactionReceipt(x: JsonString, data: Hash32): ReceiptObject {.async: (raises: [SerializationError]).} =
      var r: ReceiptObject
      if x != "-1".JsonString:
        r = decodeFromString(x, ReceiptObject)
      return r

    proc eth_getTransactionByHash(x: JsonString, data: Hash32): TransactionObject {.async: (raises: [SerializationError]).} =
      var tx: TransactionObject
      if x != "-1".JsonString:
        tx = decodeFromString(x, TransactionObject)
      return tx

    proc eth_getTransactionByBlockNumberAndIndex(x: JsonString, blockId: RtBlockIdentifier, quantity: Quantity): TransactionObject {.async: (raises: [SerializationError]).} =
      var tx: TransactionObject
      if x != "-1".JsonString:
        tx = decodeFromString(x, TransactionObject)
      return tx

    proc eth_getTransactionByBlockHashAndIndex(x: JsonString, data: Hash32, quantity: Quantity): TransactionObject {.async: (raises: [SerializationError]).} =
      var tx: TransactionObject
      if x != "-1".JsonString:
        tx = decodeFromString(x, TransactionObject)
      return tx

    proc eth_getTransactionCount(x: JsonString, data: Address, blockId: RtBlockIdentifier): Quantity {.async: (raises: [SerializationError]).} =
      if x != "-1".JsonString:
        result = decodeFromString(x, Quantity)

    proc eth_getStorageAt(x: JsonString, data: Address, slot: UInt256, blockId: RtBlockIdentifier): FixedBytes[32] {.async: (raises: [SerializationError]).} =
      if x != "-1".JsonString:
        result = decodeFromString(x, FixedBytes[32])

    proc eth_getProof(x: JsonString, address: Address, slots: seq[UInt256], blockId: RtBlockIdentifier): ProofResponse {.async: (raises: [SerializationError]).} =
      var p: ProofResponse
      if x != "-1".JsonString:
        p = decodeFromString(x, ProofResponse)
      return p

    proc eth_getCode(x: JsonString, data: Address, blockId: RtBlockIdentifier): seq[byte] {.async: (raises: [SerializationError]).} =
      if x != "-1".JsonString:
        result = decodeFromString(x, seq[byte])

    proc eth_getBlockTransactionCountByNumber(x: JsonString, blockId: RtBlockIdentifier): Quantity {.async: (raises: [SerializationError]).} =
      if x != "-1".JsonString:
        result = decodeFromString(x, Quantity)

    proc eth_getBlockTransactionCountByHash(x: JsonString, data: Hash32): Quantity {.async: (raises: [SerializationError]).} =
      if x != "-1".JsonString:
        result = decodeFromString(x, Quantity)

    proc eth_getBlockReceipts(x: JsonString, blockId: RtBlockIdentifier): Opt[seq[ReceiptObject]] {.async: (raises: [SerializationError]).} =
      if x != "-1".JsonString:
        let r = decodeFromString(x, Opt[seq[ReceiptObject]])
        return r

    proc eth_getBlockByNumber(x: JsonString, blockId: RtBlockIdentifier, fullTransactions: bool): BlockObject {.async: (raises: [SerializationError]).} =
      var blk: BlockObject
      if x != "-1".JsonString:
        blk = decodeFromString(x, BlockObject)
      return blk

    proc eth_getBlockByHash(x: JsonString, data: Hash32, fullTransactions: bool): BlockObject {.async: (raises: [SerializationError]).} =
      var blk: BlockObject
      if x != "-1".JsonString:
        blk = decodeFromString(x, BlockObject)
      return blk

    proc eth_getBalance(x: JsonString, data: Address, blockId: RtBlockIdentifier): UInt256 {.async: (raises: [SerializationError]).} =
      if x != "-1".JsonString:
        result = decodeFromString(x, UInt256)

    proc eth_feeHistory(x: JsonString, blockCount: Quantity, newestBlock: RtBlockIdentifier, rewardPercentiles: Opt[seq[float64]]): FeeHistoryResult {.async: (raises: [SerializationError]).} =
      var fh: FeeHistoryResult
      if x != "-1".JsonString:
        fh = decodeFromString(x, FeeHistoryResult)
      return fh

    proc eth_estimateGas(x: JsonString, call: TransactionArgs): Quantity {.async: (raises: [SerializationError]).} =
      if x != "-1".JsonString:
        result = decodeFromString(x, Quantity)

    proc eth_createAccessList(x: JsonString, call: TransactionArgs, blockId: RtBlockIdentifier): AccessListResult {.async: (raises: [SerializationError]).} =
      var z: AccessListResult
      if x != "-1".JsonString:
        z = decodeFromString(x, AccessListResult)
      return z

    proc eth_chainId(x: JsonString, ): Quantity {.async: (raises: [SerializationError]).} =
      if x != "-1".JsonString:
        result = decodeFromString(x, Quantity)

    proc eth_call(x: JsonString, call: TransactionArgs, blockId: RtBlockIdentifier): seq[byte] {.async: (raises: [SerializationError]).} =
      if x != "-1".JsonString:
        result = decodeFromString(x, seq[byte])

    proc eth_blockNumber(x: JsonString): Quantity {.async: (raises: [SerializationError]).} =
      if x != "-1".JsonString:
        result = decodeFromString(x, Quantity)

    proc debug_getRawTransaction(x: JsonString, data: Bytes32): RlpEncodedBytes {.async: (raises: [SerializationError]).} =
      var res: seq[byte]
      if x != "-1".JsonString:
        res = decodeFromString(x, seq[byte])
      return res.RlpEncodedBytes

    proc debug_getRawReceipts(x: JsonString, blockId: RtBlockIdentifier): seq[RlpEncodedBytes] {.async: (raises: [SerializationError]).} =
      var res: seq[RlpEncodedBytes]
      if x != "-1".JsonString:
        res = decodeFromString(x, seq[RlpEncodedBytes])
      return res

    proc debug_getRawHeader(x: JsonString, blockId: RtBlockIdentifier): RlpEncodedBytes {.async: (raises: [SerializationError]).} =
      var res: seq[byte]
      if x != "-1".JsonString:
        res = decodeFromString(x, seq[byte])
      return res.RlpEncodedBytes

    proc debug_getRawBlock(x: JsonString, blockId: RtBlockIdentifier): RlpEncodedBytes {.async: (raises: [SerializationError]).} =
      var res: seq[byte]
      if x != "-1".JsonString:
        res = decodeFromString(x, seq[byte])
      return res.RlpEncodedBytes

    proc eth_blobBaseFee(x: JsonString): Quantity {.async: (raises: [SerializationError]).} =
      if x != "-1".JsonString:
        return decodeFromString(x, Quantity)

    proc eth_getLogs(x: JsonString, filterOptions: FilterOptions): seq[LogObject] {.async: (raises: [SerializationError]).} =
      if x != "-1".JsonString:
        return decodeFromString(x, seq[LogObject])

    proc net_version(x: JsonString): string {.async: (raises: [SerializationError]).} =
      if x != "-1".JsonString:
        return decodeFromString(x, string)
