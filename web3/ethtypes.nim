import
  options, json, hashes, typetraits,
  stint, stew/byteutils

type
  SyncObject* = object
    startingBlock*: int
    currentBlock*: int
    highestBlock*: int

  FixedBytes* [N: static[int]] = distinct array[N, byte]
  DynamicBytes* [N: static[int]] = distinct array[N, byte]

  Address* = distinct array[20, byte]
  TxHash* = FixedBytes[32]
  BlockHash* = FixedBytes[32]
  BlockNumber* = uint64
  BlockIdentifier* = string|BlockNumber|RtBlockIdentifier
  Nonce* = int

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

  EthSend* = object
    source*: Address             # the address the transaction is send from.
    to*: Option[Address]         # (optional when creating new contract) the address the transaction is directed to.
    gas*: Option[Quantity]            # (optional, default: 90000) integer of the gas provided for the transaction execution. It will return unused gas.
    gasPrice*: Option[int]       # (optional, default: To-Be-Determined) integer of the gasPrice used for each paid gas.
    value*: Option[Uint256]          # (optional) integer of the value sent with this transaction.
    data*: string                # the compiled code of a contract OR the hash of the invoked method signature and encoded parameters. For details see Ethereum Contract ABI.
    nonce*: Option[Nonce]        # (optional) integer of a nonce. This allows to overwrite your own pending transactions that use the same nonce

  #EthSend* = object
  #  source*: Address     # the address the transaction is send from.
  #  to*: Address         # (optional when creating new contract) the address the transaction is directed to.
  #  gas*: int            # (optional, default: 90000) integer of the gas provided for the transaction execution. It will return unused gas.
  #  gasPrice*: int       # (optional, default: To-Be-Determined) integer of the gasPrice used for each paid gas.
  #  value*: int          # (optional) integer of the value sent with this transaction.
  #  data*: string                # the compiled code of a contract OR the hash of the invoked method signature and encoded parameters. For details see Ethereum Contract ABI.
  #  nonce*: int          # (optional) integer of a nonce. This allows to overwrite your own pending transactions that use the same nonce

  EthCall* = object
    source*: Option[Address]  # (optional) The address the transaction is send from.
    to*: Address      # The address the transaction is directed to.
    gas*: Option[Quantity]                 # (optional) Integer of the gas provided for the transaction execution. eth_call consumes zero gas, but this parameter may be needed by some executions.
    gasPrice*: Option[int]            # (optional) Integer of the gasPrice used for each paid gas.
    value*: Option[UInt256]              # (optional) Integer of the value sent with this transaction.
    data*: Option[string]                # (optional) Hash of the method signature and encoded parameters. For details see Ethereum Contract ABI.

  #EthCall* = object
  #  source*: Address  # (optional) The address the transaction is send from.
  #  to*: Address      # The address the transaction is directed to.
  #  gas*: int                 # (optional) Integer of the gas provided for the transaction execution. eth_call consumes zero gas, but this parameter may be needed by some executions.
  #  gasPrice*: int            # (optional) Integer of the gasPrice used for each paid gas.
  #  value*: int               # (optional) Integer of the value sent with this transaction.
  #  data*: int                # (optional) Hash of the method signature and encoded parameters. For details see Ethereum Contract ABI.

  ## A block header object
  BlockHeader* = ref object
    number*: Quantity
    hash*: BlockHash
    parentHash*: BlockHash
    sha3Uncles*: BlockHash
    logsBloom*: FixedBytes[256]
    transactionsRoot*: BlockHash
    stateRoot*: BlockHash
    receiptsRoot*: BlockHash
    miner*: Address
    difficulty*: Quantity
    extraData*: string
    gasLimit*: Quantity
    gasUsed*: Quantity
    timestamp*: Quantity
    nonce*: Quantity
    mixHash*: BlockHash

  ## A block object, or null when no block was found
  BlockObject* = ref object
    number*: Quantity             # the block number. null when its pending block.
    hash*: BlockHash              # hash of the block. null when its pending block.
    parentHash*: BlockHash        # hash of the parent block.
    sha3Uncles*: UInt256          # SHA3 of the uncles data in the block.
    logsBloom*: FixedBytes[256]   # the bloom filter for the logs of the block. null when its pending block.
    transactionsRoot*: UInt256    # the root of the transaction trie of the block.
    stateRoot*: UInt256           # the root of the final state trie of the block.
    receiptsRoot*: UInt256        # the root of the receipts trie of the block.
    miner*: Address               # the address of the beneficiary to whom the mining rewards were given.
    difficulty*: Quantity         # integer of the difficulty for this block.
    extraData*: string            # the "extra data" field of this block.
    gasLimit*: Quantity           # the maximum gas allowed in this block.
    gasUsed*: Quantity            # the total used gas by all transactions in this block.
    timestamp*: Quantity          # the unix timestamp for when the block was collated.
    nonce*: Quantity              # hash of the generated proof-of-work. null when its pending block.
    size*: Quantity               # integer the size of this block in bytes.
    totalDifficulty*: Quantity    # integer of the total difficulty of the chain until this block.
    transactions*: seq[TxHash]    # list of transaction objects, or 32 Bytes transaction hashes depending on the last given parameter.
    uncles*: seq[BlockHash]       # list of uncle hashes.

  TransactionObject* = object     # A transaction object, or null when no transaction was found:
    hash*: TxHash                 # hash of the transaction.
    nonce*: int64                 # TODO: Is int? the number of transactions made by the sender prior to this one.
    blockHash*: BlockHash         # hash of the block where this transaction was in. null when its pending.
    blockNumber*: int64           # block number where this transaction was in. null when its pending.
    transactionIndex*: int64      # integer of the transactions index position in the block. null when its pending.
    source*: Address              # address of the sender.
    to*: Address                  # address of the receiver. null when its a contract creation transaction.
    value*: int64                 # value transferred in Wei.
    gasPrice*: int64              # gas price provided by the sender in Wei.
    gas*: Quantity                # gas provided by the sender.
    input*: seq[byte]             # the data send along with the transaction.

  ReceiptKind* = enum rkRoot, rkStatus
  ReceiptObject* = object
    # A transaction receipt object, or null when no receipt was found:
    transactionHash*: TxHash          # hash of the transaction.
    transactionIndex*: string#int            # integer of the transactions index position in the block.
    blockHash*: BlockHash             # hash of the block where this transaction was in.
    blockNumber*: string#int                 # block number where this transaction was in.
    cumulativeGasUsed*: string#int           # the total amount of gas used when this transaction was executed in the block.
    gasUsed*: string#int                     # the amount of gas used by this specific transaction alone.
    contractAddress*: Option[Address] # the contract address created, if the transaction was a contract creation, otherwise null.
    logs*: seq[LogObject]                # TODO: See Wiki for details. list of log objects, which this transaction generated.
    logsBloom*: Option[FixedBytes[256]]      # bloom filter for light clients to quickly retrieve related logs.
    # TODO:
    #case kind*: ReceiptKind
    #of rkRoot: root*: UInt256         # post-transaction stateroot (pre Byzantium).
    #of rkStatus: status*: int         # 1 = success, 0 = failure.

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
    #removed*: bool              # true when the log was removed, due to a chain reorganization. false if its a valid log.
    logIndex*: string#int              # integer of the log index position in the block. null when its pending log.
    transactionIndex*: string#ref int  # integer of the transactions index position log was created from. null when its pending log.
    transactionHash*: TxHash    # hash of the transactions this log was created from. null when its pending log.
    blockHash*: BlockHash       # hash of the block where this log was in. null when its pending. null when its pending log.
    blockNumber*: string#int64     # the block number where this log was in. null when its pending. null when its pending log.
    address*: Address           # address from which this log originated.
    data*: string#seq[UInt256]         # contains one or more 32 Bytes non-indexed arguments of the log.
    topics*: seq[string]#array[4, UInt256]  # array of 0 to 4 32 Bytes DATA of indexed log arguments.
                                # (In solidity: The first topic is the hash of the signature of the event.
                                # (e.g. Deposit(address,bytes32,uint256)), except you declared the event with the anonymous specifier.)

  WhisperPost* = object
    # The whisper post object:
    source*: array[60, byte]    # (optional) the identity of the sender.
    to*: array[60, byte]        # (optional) the identity of the receiver. When present whisper will encrypt the message so that only the receiver can decrypt it.
    topics*: seq[UInt256]       # TODO: Correct type? list of DATA topics, for the receiver to identify messages.
    payload*: UInt256           # TODO: Correct type - maybe string? the payload of the message.
    priority*: int              # integer of the priority in a rang from ... (?).
    ttl*: int                   # integer of the time to live in seconds.

  WhisperMessage* = object
    # (?) are from the RPC Wiki, indicating uncertainty in type format.
    hash*: UInt256              # (?) the hash of the message.
    source*: array[60, byte]    # the sender of the message, if a sender was specified.
    to*: array[60, byte]        # the receiver of the message, if a receiver was specified.
    expiry*: int                # integer of the time in seconds when this message should expire (?).
    ttl*: int                   # integer of the time the message should float in the system in seconds (?).
    sent*: int                  # integer of the unix timestamp when the message was sent.
    topics*: seq[UInt256]       # list of DATA topics the message contained.
    payload*: string            # TODO: Correct type? the payload of the message.
    workProved*: int            # integer of the work this message required before it was send (?).

#  EthSend* = object
#    source*: Address     # the address the transaction is send from.
#    to*: Option[Address] # (optional when creating new contract) the address the transaction is directed to.
#    gas*: Option[int]            # (optional, default: 90000) integer of the gas provided for the transaction execution. It will return unused gas.
#    gasPrice*: Option[int]       # (optional, default: To-Be-Determined) integer of the gasPrice used for each paid gas.
#    value*: Option[int]          # (optional) integer of the value sent with this transaction.
#    data*: string                # the compiled code of a contract OR the hash of the invoked method signature and encoded parameters. For details see Ethereum Contract ABI.
#    nonce*: Option[int]          # (optional) integer of a nonce. This allows to overwrite your own pending transactions that use the same nonce

# var x: array[20, byte] = [1.byte, 2, 3, 4, 5, 6, 7, 0xab, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20]

proc `==`*[N](a, b: FixedBytes[N]): bool {.inline.} =
  array[N, byte](a) == array[N, byte](b)

proc `==`*[N](a, b: DynamicBytes[N]): bool {.inline.} =
  array[N, byte](a) == array[N, byte](b)

proc `==`*(a, b: Address): bool {.inline.} =
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

template toHex*[N](x: DynamicBytes[N]): string =
  toHex(distinctBase x)

template toHex*(x: Address): string =
  toHex(distinctBase x)

template fromHex*(T: type Address, hexStr: string): T =
  T fromHex(distinctBase(T), hexStr)

template fromHex*[N](T: type DynamicBytes[N], hexStr: string): T =
  T fromHex(distinctBase(T), hexStr)

template fromHex*[N](T: type FixedBytes[N], hexStr: string): T =
  T fromHex(distinctBase(T), hexStr)

template skip0xPrefix(hexStr: string): int =
  ## Returns the index of the first meaningful char in `hexStr` by skipping
  ## "0x" prefix
  if hexStr.len > 1 and hexStr[0] == '0' and hexStr[1] in {'x', 'X'}: 2
  else: 0

proc strip0xPrefix*(s: string): string =
  let prefixLen = skip0xPrefix(s)
  if prefixLen != 0:
    s[prefixLen .. ^1]
  else:
    s

