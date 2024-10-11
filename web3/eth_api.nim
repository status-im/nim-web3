# nim-web3
# Copyright (c) 2019-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or
#    http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or
#    http://opensource.org/licenses/MIT)
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

import
  std/json,
  json_rpc/[client, jsonmarshal],
  stint,
  ./conversions,
  ./eth_api_types

export
  eth_api_types,
  conversions

createRpcSigsFromNim(RpcClient):
  proc web3_clientVersion(): string
  proc web3_sha3(data: seq[byte]): Hash32
  proc net_version(): string
  proc net_peerCount(): Quantity
  proc net_listening(): bool
  proc eth_protocolVersion(): string
  proc eth_syncing(): SyncingStatus
  proc eth_coinbase(): Address
  proc eth_mining(): bool
  proc eth_hashrate(): Quantity
  proc eth_gasPrice(): Quantity
  proc eth_blobBaseFee(): Quantity
  proc eth_accounts(): seq[Address]
  proc eth_blockNumber(): Quantity
  proc eth_getBalance(data: Address, blockId: BlockIdentifier): UInt256
  proc eth_getStorageAt(data: Address, slot: UInt256, blockId: BlockIdentifier): FixedBytes[32]
  proc eth_getTransactionCount(data: Address, blockId: BlockIdentifier): Quantity
  proc eth_getBlockTransactionCountByHash(data: Hash32): Quantity
  proc eth_getBlockTransactionCountByNumber(blockId: BlockIdentifier): Quantity

  # TODO: Investigate why nim v2 cannot instantiate generic functions
  # with oneof params `blockId: BlockIdentifier` and and return type
  # Opt[seq[ReceiptObject]], this is a regression after all
  # https://github.com/nim-lang/Nim/issues/23310
  when false:
    proc eth_getBlockReceipts(blockId: BlockIdentifier): Opt[seq[ReceiptObject]]

  proc eth_getBlockReceipts(blockId: string): Opt[seq[ReceiptObject]]
  proc eth_getBlockReceipts(blockId: Quantity): Opt[seq[ReceiptObject]]
  proc eth_getBlockReceipts(blockId: RtBlockIdentifier): Opt[seq[ReceiptObject]]

  proc eth_getUncleCountByBlockHash(data: Hash32): Quantity
  proc eth_getUncleCountByBlockNumber(blockId: BlockIdentifier): Quantity
  proc eth_getCode(data: Address, blockId: BlockIdentifier): seq[byte]
  proc eth_sign(address: Address, data: seq[byte]): seq[byte]
  proc eth_signTransaction(args: TransactionArgs): seq[byte]
  proc eth_sendTransaction(args: TransactionArgs): Hash32
  proc eth_sendRawTransaction(data: seq[byte]): Hash32
  proc eth_call(args: TransactionArgs, blockId: BlockIdentifier): seq[byte]
  proc eth_estimateGas(args: TransactionArgs): Quantity
  proc eth_createAccessList(args: TransactionArgs, blockId: BlockIdentifier): AccessListResult
  proc eth_getBlockByHash(data: Hash32, fullTransactions: bool): BlockObject
  proc eth_getBlockByNumber(blockId: BlockIdentifier, fullTransactions: bool): BlockObject
  proc eth_getTransactionByHash(data: Hash32): TransactionObject
  proc eth_getTransactionByBlockHashAndIndex(data: Hash32, quantity: Quantity): TransactionObject
  proc eth_getTransactionByBlockNumberAndIndex(blockId: BlockIdentifier, quantity: Quantity): TransactionObject
  proc eth_getTransactionReceipt(data: Hash32): ReceiptObject
  proc eth_getUncleByBlockHashAndIndex(data: Hash32, quantity: Quantity): BlockObject
  proc eth_getUncleByBlockNumberAndIndex(blockId: BlockIdentifier, quantity: Quantity): BlockObject
  proc eth_getCompilers(): seq[string]
  proc eth_compileLLL(): seq[byte]
  proc eth_compileSolidity(): seq[byte]
  proc eth_compileSerpent(): seq[byte]
  proc eth_newFilter(filterOptions: FilterOptions): string
  proc eth_newBlockFilter(): string
  proc eth_newPendingTransactionFilter(): string
  proc eth_uninstallFilter(filterId: string): bool
  proc eth_getFilterChanges(filterId: string): JsonNode
  proc eth_getFilterLogs(filterId: string): JsonNode
  proc eth_getLogs(filterOptions: FilterOptions): seq[LogObject]
  proc eth_chainId(): Quantity

  proc eth_getWork(): seq[UInt256]
  proc eth_submitWork(nonce: int64, powHash: Hash32, mixDigest: Hash32): bool
  proc eth_submitHashrate(hashRate: UInt256, id: UInt256): bool
  proc eth_subscribe(name: string, options: FilterOptions): string
  proc eth_subscribe(name: string): string
  proc eth_unsubscribe(id: string)

  proc eth_getProof(
    address: Address,
    slots: seq[UInt256],
    blockId: BlockIdentifier): ProofResponse

  proc eth_feeHistory(
    blockCount: Quantity,
    newestBlock: BlockIdentifier,
    rewardPercentiles: Opt[seq[float64]]): FeeHistoryResult

  proc debug_getRawBlock(blockId: BlockIdentifier): RlpEncodedBytes
  proc debug_getRawHeader(blockId: BlockIdentifier): RlpEncodedBytes
  proc debug_getRawReceipts(blockId: BlockIdentifier): seq[RlpEncodedBytes]
  proc debug_getRawTransaction(data: Hash32): RlpEncodedBytes

createSingleRpcSig(RpcClient, "eth_getJsonLogs"):
  proc eth_getLogs(filterOptions: FilterOptions): seq[JsonString]
