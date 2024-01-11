# json-rpc
# Copyright (c) 2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  json_rpc/rpcserver,
  ../../web3/conversions

proc installHandlers*(server: RpcServer) =
  server.rpc("eth_syncing") do() -> bool:
    return false

  server.rpc("eth_sendRawTransaction") do(data: seq[byte]) -> TxHash:
    return false

  server.rpc("eth_getTransactionReceipt") do(data: TxHash) -> ReceiptObject:
    return false

  server.rpc("eth_getTransactionByHash") do(data: TxHash) -> TransactionObject:
    return false

  server.rpc("eth_getTransactionByBlockNumberAndIndex") do(blockId: BlockIdentifier, quantity: Quantity) -> TransactionObject:
    return false

  server.rpc("eth_getTransactionByBlockHashAndIndex") do(data: Hash256, quantity: Quantity) -> TransactionObject:
    return false

  server.rpc("eth_getStorageAt") do(data: Address, slot: UInt256, blockId: BlockIdentifier) -> UInt256:
    return false

  server.rpc("eth_getProof") do(address: Address, slots: seq[UInt256], blockId: BlockIdentifier) -> ProofResponse:
    return false

  server.rpc("eth_getCode") do(data: Address, blockId: BlockIdentifier) -> seq[byte]:
    return false

  server.rpc("eth_getBlockTransactionCountByNumber") do(blockId: BlockIdentifier) -> Quantity:
    return false

  server.rpc("eth_getBlockTransactionCountByHash") do(data: BlockHash) -> Quantity:
    return false

  server.rpc("eth_getBlockReceipts") do(blockId: BlockIdentifier) -> seq[ReceiptObject]:
    return false

  server.rpc("eth_getBlockByNumber") do(blockId: BlockIdentifier, fullTransactions: bool) -> BlockObject:
    return false

  server.rpc("eth_getBlockByHash") do(data: BlockHash, fullTransactions: bool) -> BlockObject:
    return false

  server.rpc("eth_getBalance") do(data: Address, blockId: BlockIdentifier) -> UInt256:
    return false

  server.rpc("eth_feeHistory") do(blockCount: Quantity, newestBlock: BlockIdentifier, rewardPercentiles: Option[seq[Quantity]]) -> FeeHistoryResult:
    return false

  server.rpc("eth_estimateGas") do(call: EthCall, blockId: BlockIdentifier) -> Quantity:
    return false

  server.rpc("eth_createAccessList") do(call: EthCall, blockId: BlockIdentifier) -> AccessListResult:
    return false

  server.rpc("eth_chainId") do() -> Quantity:
    return false

  server.rpc("eth_call") do(call: EthCall, blockId: BlockIdentifier) -> seq[byte]:
    return false

  server.rpc("eth_blockNumber") do() -> Quantity:
    return false

  server.rpc("debug_getRawTransaction") do(data: TxHash) -> RlpEncodedBytes:
    return false

  server.rpc("debug_getRawReceipts") do(blockId: BlockIdentifier) -> RlpEncodedBytes:
    return false

  server.rpc("debug_getRawHeader") do(blockId: BlockIdentifier) -> RlpEncodedBytes:
    return false

  server.rpc("debug_getRawBlock ") doblockId: BlockIdentifier() -> RlpEncodedBytes:
    return false