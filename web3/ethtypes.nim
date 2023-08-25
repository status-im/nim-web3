import
  std/[options, hashes, typetraits],
  stint, stew/[byteutils, results]

export
  hashes, options

const
  web3_consensus_const_preset* {.strdefine.} = "mainnet"

  # TODO This is not very elegant. Can we make this a run-time choice?
  fieldElementsPerBlob = when web3_consensus_const_preset == "minimal": 4
                         elif web3_consensus_const_preset == "mainnet": 4096
                         else: {.error: "please set 'web3_consensus_const_preset' to either 'mainnet' or 'minimal'".}

type
  SyncObject* = object
    startingBlock*: int
    currentBlock*: int
    highestBlock*: int

  FixedBytes*[N: static[int]] = distinct array[N, byte]
  DynamicBytes*[
    minLen: static[int] = 0,
    maxLen: static[int] = high(int)] = distinct seq[byte]

  HistoricExtraData = DynamicBytes[0, 4096]
    ## In the current specs, the maximum is 32, but historically this value was
    ## used as Clique metadata which is dynamic in lenght and exceeds 32 bytes.
    ## Since we still need to support syncing old blocks, we use this more relaxed
    ## setting. Downstream libraries that want to enforce the up-to-date limit are
    ## expected to do this on their own.

  Address* = distinct array[20, byte]
  TxHash* = FixedBytes[32]
  Hash256* = FixedBytes[32]
  BlockHash* = Hash256
  BlockNumber* = uint64
  BlockIdentifier* = string|BlockNumber|RtBlockIdentifier
  Nonce* = int
  CodeHash* = FixedBytes[32]
  StorageHash* = FixedBytes[32]
  VersionedHash* = FixedBytes[32]

  BlockIdentifierKind* = enum
    bidNumber
    bidAlias

  RtBlockIdentifier* = object
    case kind*: BlockIdentifierKind
    of bidNumber:
      number*: BlockNumber
    of bidAlias:
      alias*: string

  Quantity* = distinct uint64

  KZGCommitment* = FixedBytes[48]
  KZGProof* = FixedBytes[48]
  Blob* = FixedBytes[fieldElementsPerBlob * 32]

  EthSend* = object
    source*: Address             # the address the transaction is sent from.
    to*: Option[Address]         # (optional when creating new contract) the address the transaction is directed to.
    gas*: Option[Quantity]       # (optional, default: 90000) integer of the gas provided for the transaction execution. It will return unused gas.
    gasPrice*: Option[int]       # (optional, default: To-Be-Determined) integer of the gasPrice used for each paid gas.
    value*: Option[UInt256]      # (optional) integer of the value sent with this transaction.
    data*: string                # the compiled code of a contract OR the hash of the invoked method signature and encoded parameters.
                                 # For details see Ethereum Contract ABI.
    nonce*: Option[Nonce]        # (optional) integer of a nonce. This allows to overwrite your own pending transactions that use the same nonce

  #EthSend* = object
  #  source*: Address     # the address the transaction is sent from.
  #  to*: Address         # (optional when creating new contract) the address the transaction is directed to.
  #  gas*: int            # (optional, default: 90000) integer of the gas provided for the transaction execution. It will return unused gas.
  #  gasPrice*: int       # (optional, default: To-Be-Determined) integer of the gasPrice used for each paid gas.
  #  value*: int          # (optional) integer of the value sent with this transaction.
  #  data*: string                # the compiled code of a contract OR the hash of the invoked method signature and encoded parameters. For details see Ethereum Contract ABI.
  #  nonce*: int          # (optional) integer of a nonce. This allows to overwrite your own pending transactions that use the same nonce


  # TODO: Both `EthSend` and `EthCall` are super outdated, according to new spec
  # those should be merged into one type `GenericTransaction` with a lot more fields
  # see: https://github.com/ethereum/execution-apis/blob/main/src/schemas/transaction.yaml#L244
  EthCall* = object
    source*: Option[Address]  # (optional) The address the transaction is sent from.
    to*: Address      # The address the transaction is directed to.
    gas*: Option[Quantity]                 # (optional) Integer of the gas provided for the transaction execution. eth_call consumes zero gas, but this parameter may be needed by some executions.
    gasPrice*: Option[int]            # (optional) Integer of the gasPrice used for each paid gas.
    value*: Option[UInt256]              # (optional) Integer of the value sent with this transaction.
    data*: Option[string]                # (optional) Hash of the method signature and encoded parameters. For details see Ethereum Contract ABI.

  #EthCall* = object
  #  source*: Address  # (optional) The address the transaction is sent from.
  #  to*: Address      # The address the transaction is directed to.
  #  gas*: int                 # (optional) Integer of the gas provided for the transaction execution. eth_call consumes zero gas, but this parameter may be needed by some executions.
  #  gasPrice*: int            # (optional) Integer of the gasPrice used for each paid gas.
  #  value*: int               # (optional) Integer of the value sent with this transaction.
  #  data*: int                # (optional) Hash of the method signature and encoded parameters. For details see Ethereum Contract ABI.

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

  WithdrawalObject = object
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
    transactions*: seq[TxHash]                  # list of transaction objects, or 32 Bytes transaction hashes depending on the last given parameter.
    uncles*: seq[Hash256]                       # list of uncle hashes.
    baseFeePerGas*: Option[UInt256]             # EIP-1559
    withdrawals*: Option[seq[WithdrawalObject]] # EIP-4895
    withdrawalsRoot*: Option[Hash256]           # EIP-4895
    blobGasUsed*: Option[Quantity]              # EIP-4844
    excessBlobGas*: Option[Quantity]            # EIP-4844
    parentBeaconBlockRoot*: Option[Hash256]     # EIP-4788

  AccessTuple* = object
    address*: Address
    storageKeys*: seq[Hash256]

  TransactionObject* = object                        # A transaction object, or null when no transaction was found:
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
    v*: UInt256                                      # ECDSA recovery id
    r*: UInt256                                      # ECDSA signature r
    s*: UInt256                                      # ECDSA signature s
    `type`*: Option[Quantity]                        # EIP-2718, with 0x0 for Legacy
    chainId*: Option[UInt256]                        # EIP-159
    accessList*: Option[seq[AccessTuple]]            # EIP-2930
    maxFeePerGas*: Option[Quantity]                  # EIP-1559
    maxPriorityFeePerGas*: Option[Quantity]          # EIP-1559
    maxFeePerBlobGas*: Option[Quantity]              # EIP-4844
    blobVersionedHashes*: Option[seq[VersionedHash]] # EIP-4844

  ReceiptKind* = enum rkRoot, rkStatus
  ReceiptObject* = object
    # A transaction receipt object, or null when no receipt was found:
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

  FilterDataKind* = enum fkItem, fkList
  FilterData* = object
    # Difficult to process variant objects in input data, as kind is immutable.
    # TODO: This might need more work to handle "or" options
    kind*: FilterDataKind
    items*: seq[FilterData]
    item*: UInt256
    # TODO: I don't think this will work as input, need only one value that is either UInt256 or seq[UInt256]

  FilterOptions* = object
    fromBlock*: Option[string]              # (optional, default: "latest") integer block number, or "latest" for the last mined block or "pending", "earliest" for not yet mined transactions.
    toBlock*: Option[string]                # (optional, default: "latest") integer block number, or "latest" for the last mined block or "pending", "earliest" for not yet mined transactions.
    address*: Option[Address]  # (optional) contract address or a list of addresses from which logs should originate.
    topics*: Option[seq[string]]#Option[seq[FilterData]]        # (optional) list of DATA topics. Topics are order-dependent. Each topic can also be a list of DATA with "or" options.
    blockhash*: Option[BlockHash]

  LogObject* = object              
    removed*: bool                 # true when the log was removed, due to a chain reorganization. false if its a valid log.
    logIndex*: Quantity            # integer of the log index position in the block. null when its pending log.
    transactionIndex*: Quantity    # integer of the transactions index position log was created from. null when its pending log.
    transactionHash*: TxHash       # hash of the transactions this log was created from. null when its pending log.
    blockHash*: BlockHash          # hash of the block where this log was in. null when its pending. null when its pending log.
    blockNumber*: Quantity         # the block number where this log was in. null when its pending. null when its pending log.
    address*: Address              # address from which this log originated.
    data*: seq[byte]               # contains one or more 32 Bytes non-indexed arguments of the log.
    topics*: seq[FixedBytes[32]]   # array of 0 to 4 32 Bytes DATA of indexed log arguments.
                                   # (In solidity: The first topic is the hash of the signature of the event.
                                   # (e.g. Deposit(address,bytes32,uint256)), except you declared the event with the anonymous specifier.)

#  EthSend* = object
#    source*: Address     # the address the transaction is sent from.
#    to*: Option[Address] # (optional when creating new contract) the address the transaction is directed to.
#    gas*: Option[int]            # (optional, default: 90000) integer of the gas provided for the transaction execution. It will return unused gas.
#    gasPrice*: Option[int]       # (optional, default: To-Be-Determined) integer of the gasPrice used for each paid gas.
#    value*: Option[int]          # (optional) integer of the value sent with this transaction.
#    data*: string                # the compiled code of a contract OR the hash of the invoked method signature and encoded parameters. For details see Ethereum Contract ABI.
#    nonce*: Option[int]          # (optional) integer of a nonce. This allows to overwrite your own pending transactions that use the same nonce

# var x: array[20, byte] = [1.byte, 2, 3, 4, 5, 6, 7, 0xab, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]

  TypedTransaction* = distinct seq[byte]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.3/src/engine/shanghai.md#withdrawalv1
  WithdrawalV1* = object
    index*: Quantity
    validatorIndex*: Quantity
    address*: Address
    amount*: Quantity

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.3/src/engine/paris.md#executionpayloadv1
  ExecutionPayloadV1* = object
    parentHash*: Hash256
    feeRecipient*: Address
    stateRoot*: Hash256
    receiptsRoot*: Hash256
    logsBloom*: FixedBytes[256]
    prevRandao*: FixedBytes[32]
    blockNumber*: Quantity
    gasLimit*: Quantity
    gasUsed*: Quantity
    timestamp*: Quantity
    extraData*: DynamicBytes[0, 32]
    baseFeePerGas*: UInt256
    blockHash*: Hash256
    transactions*: seq[TypedTransaction]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.3/src/engine/shanghai.md#executionpayloadv2
  ExecutionPayloadV2* = object
    parentHash*: Hash256
    feeRecipient*: Address
    stateRoot*: Hash256
    receiptsRoot*: Hash256
    logsBloom*: FixedBytes[256]
    prevRandao*: FixedBytes[32]
    blockNumber*: Quantity
    gasLimit*: Quantity
    gasUsed*: Quantity
    timestamp*: Quantity
    extraData*: DynamicBytes[0, 32]
    baseFeePerGas*: UInt256
    blockHash*: Hash256
    transactions*: seq[TypedTransaction]
    withdrawals*: seq[WithdrawalV1]

  # This is ugly, but I don't think the RPC library will handle
  # ExecutionPayloadV1 | ExecutionPayloadV2. (Am I wrong?)
  # Note that the spec currently says that various V2 methods
  # (e.g. engine_newPayloadV2) need to accept *either* V1 or V2
  # of the data structure (e.g. either ExecutionPayloadV1 or
  # ExecutionPayloadV2); it's not like V2 of the method only
  # needs to accept V2 of the structure. Anyway, the best way
  # I've found to handle this is to make this structure with an
  # Option for the withdrawals field. If you've got a better idea,
  # please fix this. (Maybe the RPC library does handle sum types?
  # Or maybe we can enhance it to do so?) --Adam
  #
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.3/src/engine/shanghai.md
  ExecutionPayloadV1OrV2* = object
    parentHash*: BlockHash
    feeRecipient*: Address
    stateRoot*: BlockHash
    receiptsRoot*: BlockHash
    logsBloom*: FixedBytes[256]
    prevRandao*: FixedBytes[32]
    blockNumber*: Quantity
    gasLimit*: Quantity
    gasUsed*: Quantity
    timestamp*: Quantity
    extraData*: DynamicBytes[0, 32]
    baseFeePerGas*: UInt256
    blockHash*: BlockHash
    transactions*: seq[TypedTransaction]
    withdrawals*: Option[seq[WithdrawalV1]]

  # https://github.com/ethereum/execution-apis/blob/fe8e13c288c592ec154ce25c534e26cb7ce0530d/src/engine/cancun.md#executionpayloadv3
  ExecutionPayloadV3* = object
    parentHash*: Hash256
    feeRecipient*: Address
    stateRoot*: Hash256
    receiptsRoot*: Hash256
    logsBloom*: FixedBytes[256]
    prevRandao*: FixedBytes[32]
    blockNumber*: Quantity
    gasLimit*: Quantity
    gasUsed*: Quantity
    timestamp*: Quantity
    extraData*: DynamicBytes[0, 32]
    baseFeePerGas*: UInt256
    blockHash*: Hash256
    transactions*: seq[TypedTransaction]
    withdrawals*: seq[WithdrawalV1]
    blobGasUsed*: Quantity
    excessBlobGas*: Quantity

  SomeExecutionPayload* =
    ExecutionPayloadV1 |
    ExecutionPayloadV2 |
    ExecutionPayloadV3

  # https://github.com/ethereum/execution-apis/blob/ee3df5bc38f28ef35385cefc9d9ca18d5e502778/src/engine/cancun.md#blobsbundlev1
  BlobsBundleV1* = object
    commitments*: seq[KZGCommitment]
    proofs*: seq[KZGProof]
    blobs*: seq[Blob]

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

  AccessListEntry* = object
    address*: Address
    storageKeys*: seq[FixedBytes[32]]

  AccessList* = seq[AccessListEntry]

  AccessListResult* = object
    accessList*: AccessList
    error*: string
    gasUsed: Quantity

template `==`*[N](a, b: FixedBytes[N]): bool =
  distinctBase(a) == distinctBase(b)

template `==`*(a, b: Quantity): bool =
  distinctBase(a) == distinctBase(b)

template `==`*[minLen, maxLen](a, b: DynamicBytes[minLen, maxLen]): bool =
  distinctBase(a) == distinctBase(b)

func `==`*(a, b: Address): bool {.inline.} =
  array[20, byte](a) == array[20, byte](b)

func blockId*(n: BlockNumber): RtBlockIdentifier =
  RtBlockIdentifier(kind: bidNumber, number: n)

func blockId*(b: BlockObject): RtBlockIdentifier =
  RtBlockIdentifier(kind: bidNumber, number: BlockNumber b.number)

func blockId*(a: string): RtBlockIdentifier =
  RtBlockIdentifier(kind: bidAlias, alias: a)

func hash*[N](bytes: FixedBytes[N]): Hash =
  hash(distinctBase bytes)

template toHex*[N](x: FixedBytes[N]): string =
  toHex(distinctBase x)

template toHex*[minLen, maxLen](x: DynamicBytes[minLen, maxLen]): string =
  toHex(distinctBase x)

template toHex*(x: Address): string =
  toHex(distinctBase x)

template fromHex*(T: type Address, hexStr: string): T =
  T fromHex(distinctBase(T), hexStr)

template skip0xPrefix(hexStr: string): int =
  ## Returns the index of the first meaningful char in `hexStr` by skipping
  ## "0x" prefix
  if hexStr.len > 1 and hexStr[0] == '0' and hexStr[1] in {'x', 'X'}: 2
  else: 0

func strip0xPrefix*(s: string): string =
  let prefixLen = skip0xPrefix(s)
  if prefixLen != 0:
    s[prefixLen .. ^1]
  else:
    s

func fromHex*[minLen, maxLen](T: type DynamicBytes[minLen, maxLen], hexStr: string): T =
  let prefixLen = skip0xPrefix(hexStr)
  let hexDataLen = hexStr.len - prefixLen

  if hexDataLen < minLen * 2:
    raise newException(ValueError, "hex input too small")

  if hexDataLen > maxLen * 2:
    raise newException(ValueError, "hex input too large")

  T hexToSeqByte(hexStr)

template fromHex*[N](T: type FixedBytes[N], hexStr: string): T =
  T fromHex(distinctBase(T), hexStr)

func toArray*[N](data: DynamicBytes[N, N]): array[N, byte] =
  copyMem(addr result[0], unsafeAddr distinctBase(data)[0], N)

template bytes*(data: DynamicBytes): seq[byte] =
  distinctBase data

template bytes*(data: FixedBytes): auto =
  distinctBase data

template len*(data: DynamicBytes): int =
  len(distinctBase data)

func `$`*[minLen, maxLen](data: DynamicBytes[minLen, maxLen]): string =
  "0x" & byteutils.toHex(distinctBase(data))


# These conversion functions are very ugly, but at least
# they're very straightforward and simple. If anyone has
# a better idea, I'm all ears. (See the above comment on
# ExecutionPayloadV1OrV2.) --Adam

func toExecutionPayloadV1OrExecutionPayloadV2*(p: ExecutionPayloadV1OrV2): Result[ExecutionPayloadV1, ExecutionPayloadV2] =
  if p.withdrawals.isNone:
    ok(
      ExecutionPayloadV1(
        parentHash: p.parentHash,
        feeRecipient: p.feeRecipient,
        stateRoot: p.stateRoot,
        receiptsRoot: p.receiptsRoot,
        logsBloom: p.logsBloom,
        prevRandao: p.prevRandao,
        blockNumber: p.blockNumber,
        gasLimit: p.gasLimit,
        gasUsed: p.gasUsed,
        timestamp: p.timestamp,
        extraData: p.extraData,
        baseFeePerGas: p.baseFeePerGas,
        blockHash: p.blockHash,
        transactions: p.transactions
      )
    )
  else:
    err(
      ExecutionPayloadV2(
        parentHash: p.parentHash,
        feeRecipient: p.feeRecipient,
        stateRoot: p.stateRoot,
        receiptsRoot: p.receiptsRoot,
        logsBloom: p.logsBloom,
        prevRandao: p.prevRandao,
        blockNumber: p.blockNumber,
        gasLimit: p.gasLimit,
        gasUsed: p.gasUsed,
        timestamp: p.timestamp,
        extraData: p.extraData,
        baseFeePerGas: p.baseFeePerGas,
        blockHash: p.blockHash,
        transactions: p.transactions,
        withdrawals: p.withdrawals.get
      )
    )

func toExecutionPayloadV1*(p: ExecutionPayloadV1OrV2): ExecutionPayloadV1 =
  p.toExecutionPayloadV1OrExecutionPayloadV2.get

func toExecutionPayloadV2*(p: ExecutionPayloadV1OrV2): ExecutionPayloadV2 =
  p.toExecutionPayloadV1OrExecutionPayloadV2.error

func toExecutionPayloadV1OrV2*(p: ExecutionPayloadV1): ExecutionPayloadV1OrV2 =
  ExecutionPayloadV1OrV2(
    parentHash: p.parentHash,
    feeRecipient: p.feeRecipient,
    stateRoot: p.stateRoot,
    receiptsRoot: p.receiptsRoot,
    logsBloom: p.logsBloom,
    prevRandao: p.prevRandao,
    blockNumber: p.blockNumber,
    gasLimit: p.gasLimit,
    gasUsed: p.gasUsed,
    timestamp: p.timestamp,
    extraData: p.extraData,
    baseFeePerGas: p.baseFeePerGas,
    blockHash: p.blockHash,
    transactions: p.transactions,
    withdrawals: none[seq[WithdrawalV1]]()
  )

func toExecutionPayloadV1OrV2*(p: ExecutionPayloadV2): ExecutionPayloadV1OrV2 =
  ExecutionPayloadV1OrV2(
    parentHash: p.parentHash,
    feeRecipient: p.feeRecipient,
    stateRoot: p.stateRoot,
    receiptsRoot: p.receiptsRoot,
    logsBloom: p.logsBloom,
    prevRandao: p.prevRandao,
    blockNumber: p.blockNumber,
    gasLimit: p.gasLimit,
    gasUsed: p.gasUsed,
    timestamp: p.timestamp,
    extraData: p.extraData,
    baseFeePerGas: p.baseFeePerGas,
    blockHash: p.blockHash,
    transactions: p.transactions,
    withdrawals: some(p.withdrawals)
  )
