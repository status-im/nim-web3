## This module contains signatures for the Ethereum client RPCs.
## The signatures are not imported directly, but read and processed with parseStmt,
## then a procedure body is generated to marshal native Nim parameters to json and visa versa.
import json, stint, ethtypes

proc web3_clientVersion(): string
proc web3_sha3(data: string): string
proc net_version(): string
proc net_peerCount(): int
proc net_listening(): bool
proc eth_protocolVersion(): string
proc eth_syncing(): JsonNode
proc eth_coinbase(): string
proc eth_mining(): bool
proc eth_hashrate(): int
proc eth_gasPrice(): int64
proc eth_accounts(): seq[Address]
proc eth_blockNumber(): Quantity
proc eth_getBalance(data: array[20, byte], quantityTag: string): int
proc eth_getStorageAt(data: array[20, byte], quantity: int, quantityTag: string): seq[byte]
proc eth_getTransactionCount(data: array[20, byte], quantityTag: string): Quantity
proc eth_getBlockTransactionCountByHash(data: BlockHash)
proc eth_getBlockTransactionCountByNumber(quantityTag: string)
proc eth_getUncleCountByBlockHash(data: BlockHash)
proc eth_getUncleCountByBlockNumber(quantityTag: string)
proc eth_getCode(data: array[20, byte], quantityTag: string): seq[byte]
proc eth_sign(data: array[20, byte], message: seq[byte]): seq[byte]
proc eth_sendTransaction(obj: EthSend): TxHash
proc eth_sendRawTransaction(data: string): TxHash
proc eth_call(call: EthCall, quantityTag: string): string #UInt256
proc eth_estimateGas(call: EthCall, quantityTag: string): UInt256
proc eth_getBlockByHash(data: BlockHash, fullTransactions: bool): BlockObject
proc eth_getBlockByNumber(quantityTag: string, fullTransactions: bool): BlockObject
proc eth_getTransactionByHash(data: TxHash): TransactionObject
proc eth_getTransactionByBlockHashAndIndex(data: UInt256, quantity: int): TransactionObject
proc eth_getTransactionByBlockNumberAndIndex(quantityTag: string, quantity: int): TransactionObject
proc eth_getTransactionReceipt(data: TxHash): ReceiptObject
proc eth_getUncleByBlockHashAndIndex(data: UInt256, quantity: int64): BlockObject
proc eth_getUncleByBlockNumberAndIndex(quantityTag: string, quantity: int64): BlockObject
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
proc eth_getLogs(filterOptions: JsonNode): JsonNode

proc eth_getWork(): seq[UInt256]
proc eth_submitWork(nonce: int64, powHash: Uint256, mixDigest: Uint256): bool
proc eth_submitHashrate(hashRate: UInt256, id: Uint256): bool
proc eth_subscribe(name: string, options: JsonNode): string
proc eth_unsubscribe(id: string)

proc shh_post(): string
proc shh_version(message: WhisperPost): bool
proc shh_newIdentity(): array[60, byte]
proc shh_hasIdentity(identity: array[60, byte]): bool
proc shh_newGroup(): array[60, byte]
proc shh_addToGroup(identity: array[60, byte]): bool
proc shh_newFilter(filterOptions: FilterOptions, to: array[60, byte], topics: seq[UInt256]): int
proc shh_uninstallFilter(id: int): bool
proc shh_getFilterChanges(id: int): seq[WhisperMessage]
proc shh_getMessages(id: int): seq[WhisperMessage]
