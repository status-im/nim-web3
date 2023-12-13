# nim-web3
# Copyright (c) 2019-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  stint,
  ./primitives

export
  primitives

type
  SyncObject* = object
    startingBlock*: Quantity
    currentBlock*: Quantity
    highestBlock*: Quantity

  HistoricExtraData* = DynamicBytes[0, 4096]
    ## In the current specs, the maximum is 32, but historically this value was
    ## used as Clique metadata which is dynamic in lenght and exceeds 32 bytes.
    ## Since we still need to support syncing old blocks, we use this more relaxed
    ## setting. Downstream libraries that want to enforce the up-to-date limit are
    ## expected to do this on their own.

  EthSend* = object
    `from`*: Address             # the address the transaction is sent from.
    to*: Option[Address]         # (optional when creating new contract) the address the transaction is directed to.
    gas*: Option[Quantity]       # (optional, default: 90000) integer of the gas provided for the transaction execution. It will return unused gas.
    gasPrice*: Option[Quantity]  # (optional, default: To-Be-Determined) integer of the gasPrice used for each paid gas.
    value*: Option[UInt256]      # (optional) integer of the value sent with this transaction.
    data*: seq[byte]             # the compiled code of a contract OR the hash of the invoked method signature and encoded parameters.
                                 # For details see Ethereum Contract ABI.
    nonce*: Option[Quantity]     # (optional) integer of a nonce. This allows to overwrite your own pending transactions that use the same nonce

  # TODO: Both `EthSend` and `EthCall` are super outdated, according to new spec
  # those should be merged into one type `GenericTransaction` with a lot more fields
  # see: https://github.com/ethereum/execution-apis/blob/main/src/schemas/transaction.yaml#L244
  EthCall* = object
    source*: Option[Address]    # (optional) The address the transaction is sent from.
    to*: Option[Address]        # The address the transaction is directed to.
    gas*: Option[Quantity]      # (optional) Integer of the gas provided for the transaction execution. eth_call consumes zero gas, but this parameter may be needed by some executions.
    gasPrice*: Option[Quantity] # (optional) Integer of the gasPrice used for each paid gas.
    value*: Option[UInt256]     # (optional) Integer of the value sent with this transaction.
    data*: Option[seq[byte]]    # (optional) Hash of the method signature and encoded parameters. For details see Ethereum Contract ABI.
    maxFeePerGas*: Option[Quantity]         # (optional) MaxFeePerGas is the maximum fee per gas offered, in wei.
    maxPriorityFeePerGas*: Option[Quantity] # (optional) MaxPriorityFeePerGas is the maximum miner tip per gas offered, in wei.

  ## A block header object
  BlockHeader* = ref object
    number*: Quantity
    hash*: Hash256
    parentHash*: Hash256
    sha3Uncles*: Hash256
    logsBloom*: FixedBytes[256]
    transactionsRoot*: Hash256
    stateRoot*: Hash256
    receiptsRoot*: Hash256
    miner*: Address
    difficulty*: UInt256
    extraData*: HistoricExtraData
    gasLimit*: Quantity
    gasUsed*: Quantity
    timestamp*: Quantity
    nonce*: FixedBytes[8]
    mixHash*: Hash256
    baseFeePerGas*: Option[UInt256]         # EIP-1559
    withdrawalsRoot*: Option[Hash256]       # EIP-4895
    blobGasUsed*: Option[Quantity]          # EIP-4844
    excessBlobGas*: Option[Quantity]        # EIP-4844
    parentBeaconBlockRoot*: Option[Hash256] # EIP-4788

  WithdrawalObject* = object
    index*: Quantity
    validatorIndex*: Quantity
    address*: Address
    amount*: Quantity

  ## A block object, or null when no block was found
  BlockObject* = ref object
    number*: Quantity                           # the block number. null when its pending block.
    hash*: Hash256                              # hash of the block. null when its pending block.
    parentHash*: Hash256                        # hash of the parent block.
    sha3Uncles*: Hash256                        # SHA3 of the uncles data in the block.
    logsBloom*: FixedBytes[256]                 # the bloom filter for the logs of the block. null when its pending block.
    transactionsRoot*: Hash256                  # the root of the transaction trie of the block.
    stateRoot*: Hash256                         # the root of the final state trie of the block.
    receiptsRoot*: Hash256                      # the root of the receipts trie of the block.
    miner*: Address                             # the address of the beneficiary to whom the mining rewards were given.
    difficulty*: UInt256                        # integer of the difficulty for this block.
    extraData*: HistoricExtraData               # the "extra data" field of this block.
    gasLimit*: Quantity                         # the maximum gas allowed in this block.
    gasUsed*: Quantity                          # the total used gas by all transactions in this block.
    timestamp*: Quantity                        # the unix timestamp for when the block was collated.
    nonce*: Option[FixedBytes[8]]               # hash of the generated proof-of-work. null when its pending block.
    mixHash*: Hash256
    size*: Quantity                             # integer the size of this block in bytes.
    totalDifficulty*: UInt256                   # integer of the total difficulty of the chain until this block.
    transactions*: seq[TxOrHash]                # list of transaction objects, or 32 Bytes transaction hashes depending on the last given parameter.
    uncles*: seq[Hash256]                       # list of uncle hashes.
    baseFeePerGas*: Option[UInt256]             # EIP-1559
    withdrawals*: Option[seq[WithdrawalObject]] # EIP-4895
    withdrawalsRoot*: Option[Hash256]           # EIP-4895
    blobGasUsed*: Option[Quantity]              # EIP-4844
    excessBlobGas*: Option[Quantity]            # EIP-4844
    parentBeaconBlockRoot*: Option[Hash256]     # EIP-4788

  TxOrHashKind* = enum
    tohHash
    tohTx

  TxOrHash* = object
    case kind*: TxOrHashKind
    of tohHash:
      hash*: TxHash
    of tohTx:
      tx*: TransactionObject

  AccessTuple* = object
    address*: Address
    storageKeys*: seq[FixedBytes[32]]

  AccessListResult* = object
    accessList*: seq[AccessTuple]
    error*: string
    gasUsed: Quantity

  TransactionObject* = ref object                    # A transaction object, or null when no transaction was found:
    hash*: TxHash                                    # hash of the transaction.
    nonce*: Quantity                                 # TODO: Is int? the number of transactions made by the sender prior to this one.
    blockHash*: Option[BlockHash]                    # hash of the block where this transaction was in. null when its pending.
    blockNumber*: Option[Quantity]                   # block number where this transaction was in. null when its pending.
    transactionIndex*: Option[Quantity]              # integer of the transactions index position in the block. null when its pending.
    `from`*: Address                                 # address of the sender.
    to*: Option[Address]                             # address of the receiver. null when its a contract creation transaction.
    value*: UInt256                                  # value transferred in Wei.
    gasPrice*: Quantity                              # gas price provided by the sender in Wei.
    gas*: Quantity                                   # gas provided by the sender.
    input*: seq[byte]                                # the data send along with the transaction.
    v*: Quantity                                     # ECDSA recovery id
    r*: UInt256                                      # ECDSA signature r
    s*: UInt256                                      # ECDSA signature s
    `type`*: Option[Quantity]                        # EIP-2718, with 0x0 for Legacy
    chainId*: Option[Quantity]                       # EIP-159
    accessList*: Option[seq[AccessTuple]]            # EIP-2930
    maxFeePerGas*: Option[Quantity]                  # EIP-1559
    maxPriorityFeePerGas*: Option[Quantity]          # EIP-1559
    maxFeePerBlobGas*: Option[UInt256]               # EIP-4844
    blobVersionedHashes*: Option[seq[VersionedHash]] # EIP-4844

  ReceiptObject* = ref object           # A transaction receipt object, or null when no receipt was found:
    transactionHash*: TxHash            # hash of the transaction.
    transactionIndex*: Quantity         # integer of the transactions index position in the block.
    blockHash*: BlockHash               # hash of the block where this transaction was in.
    blockNumber*: Quantity              # block number where this transaction was in.
    `from`*: Address                    # address of the sender.
    to*: Option[Address]                # address of the receiver. null when its a contract creation transaction.
    cumulativeGasUsed*: Quantity        # the total amount of gas used when this transaction was executed in the block.
    effectiveGasPrice*: Quantity        # The sum of the base fee and tip paid per unit of gas.
    gasUsed*: Quantity                  # the amount of gas used by this specific transaction alone.
    contractAddress*: Option[Address]   # the contract address created, if the transaction was a contract creation, otherwise null.
    logs*: seq[LogObject]               # TODO: See Wiki for details. list of log objects, which this transaction generated.
    logsBloom*: FixedBytes[256]         # bloom filter for light clients to quickly retrieve related logs.
    `type`*: Option[Quantity]           # integer of the transaction type, 0x0 for legacy transactions, 0x1 for access list types, 0x2 for dynamic fees.
    root*: Option[Hash256]              # 32 bytes of post-transaction stateroot (pre Byzantium)
    status*: Option[Quantity]           # either 1 (success) or 0 (failure)
    blobGasUsed*: Option[Quantity]      # uint64
    blobGasPrice*: Option[UInt256]      # UInt256

  FilterDataKind* = enum fkItem, fkList
  FilterData* = object
    # Difficult to process variant objects in input data, as kind is immutable.
    # TODO: This might need more work to handle "or" options
    kind*: FilterDataKind
    items*: seq[FilterData]
    item*: UInt256
    # TODO: I don't think this will work as input, need only one value that is either UInt256 or seq[UInt256]

  Topic* = FixedBytes[32]

  FilterOptions* = object
    fromBlock*: Option[RtBlockIdentifier] # (optional, default: "latest") integer block number, or "latest" for the last mined block or "pending", "earliest" for not yet mined transactions.
    toBlock*: Option[RtBlockIdentifier]   # (optional, default: "latest") integer block number, or "latest" for the last mined block or "pending", "earliest" for not yet mined transactions.
    # TODO: address as optional list of address or optional address
    address*: seq[Address]              # (optional) contract address or a list of addresses from which logs should originate.
    topics*: seq[Option[seq[Topic]]]    # (optional) list of DATA topics. Topics are order-dependent. Each topic can also be a list of DATA with "or" options.
    blockHash*: Option[BlockHash]       # (optional) hash of the block. If its present, fromBlock and toBlock, should be none. Introduced in EIP234

  LogObject* = object
    removed*: bool                      # true when the log was removed, due to a chain reorganization. false if its a valid log.
    logIndex*: Option[Quantity]         # integer of the log index position in the block. null when its pending log.
    transactionIndex*: Option[Quantity] # integer of the transactions index position log was created from. null when its pending log.
    transactionHash*: Option[TxHash]    # hash of the transactions this log was created from. null when its pending log.
    blockHash*: Option[BlockHash]       # hash of the block where this log was in. null when its pending. null when its pending log.
    blockNumber*: Option[Quantity]      # the block number where this log was in. null when its pending. null when its pending log.
    address*: Address                   # address from which this log originated.
    data*: seq[byte]                    # contains one or more 32 Bytes non-indexed arguments of the log.
    topics*: seq[Topic]                 # array of 0 to 4 32 Bytes DATA of indexed log arguments.
                                        # (In solidity: The first topic is the hash of the signature of the event.
                                        # (e.g. Deposit(address,bytes32,uint256)), except you declared the event with the anonymous specifier.)

  RlpEncodedBytes* = distinct seq[byte]

  StorageProof* = object
    key*: UInt256
    value*: UInt256
    proof*: seq[RlpEncodedBytes]

  ProofResponse* = object
    address*: Address
    accountProof*: seq[RlpEncodedBytes]
    balance*: UInt256
    codeHash*: CodeHash
    nonce*: Quantity
    storageHash*: StorageHash
    storageProof*: seq[StorageProof]

  BlockIdentifier* = string|BlockNumber|RtBlockIdentifier

  BlockIdentifierKind* = enum
    bidNumber
    bidAlias

  RtBlockIdentifier* = object
    case kind*: BlockIdentifierKind
    of bidNumber:
      number*: BlockNumber
    of bidAlias:
      alias*: string

{.push raises: [].}

func blockId*(n: BlockNumber): RtBlockIdentifier =
  RtBlockIdentifier(kind: bidNumber, number: n)

func blockId*(b: BlockObject): RtBlockIdentifier =
  RtBlockIdentifier(kind: bidNumber, number: BlockNumber b.number)

func blockId*(a: string): RtBlockIdentifier =
  RtBlockIdentifier(kind: bidAlias, alias: a)

func txOrHash*(hash: TxHash): TxOrHash =
  TxOrHash(kind: tohHash, hash: hash)

func txOrHash*(tx: TransactionObject): TxOrHash =
  TxOrHash(kind: tohTx, tx: tx)
