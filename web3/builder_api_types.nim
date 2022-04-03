import
  stint,
  ethtypes

export
  ethtypes

type
  # https://github.com/flashbots/mev-boost/blob/thegostep/docs/lib/types.go#L34
  ExecutionPayloadHeaderV1* = object
    parentHash*: FixedBytes[32]
    feeRecipient*: Address
    stateRoot*: FixedBytes[32]
    receiptsRoot*: FixedBytes[32]
    logsBloom*: string # FixedBytes[256]
    random*: FixedBytes[32]
    blockNumber*: Quantity
    gasLimit*: Quantity
    gasUsed*: Quantity
    timestamp*: Quantity
    extraData*: string    # List[byte, MAX_EXTRA_DATA_BYTES]
    baseFeePerGas*: Uint256  # base fee introduced in EIP-1559, little-endian serialized
    blockHash*: FixedBytes[32]
    transactionsRoot*: FixedBytes[32]

  ExecutionPayloadHeaderOnlyBlockHash* = object
    # Another of these either-snake-or-camel definitions
    # also why use common.Hash elsewhere but string here as block type? Either
    # works, but.
    blockHash*: string

  BlindedBeaconBlockBody* = object
    discard

  # https://github.com/flashbots/mev-boost/blob/main/docs/specification.md#blindedbeaconblock
  BlindedBeaconBlock* = object
    slot*: Quantity    # MEV builder service uses string here
    proposer_index*: Quantity
    parent_root*: FixedBytes[32]
    state_root*: FixedBytes[32]
    body*: BlindedBeaconBlockBody

  # https://github.com/flashbots/mev-boost/blob/main/docs/specification.md#signedblindedbeaconblock
  SignedBlindedBeaconBlock* = object
    message*: BlindedBeaconBlock
    signature*: FixedBytes[96]  # the MEV builder API service uses string here
