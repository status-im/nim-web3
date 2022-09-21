import
  stint,
  ethtypes

export
  ethtypes

type
  # https://github.com/flashbots/mev-boost/blob/thegostep/docs/lib/types.go#L34
  ExecutionPayloadWithTxRootV1* = object
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
    #transactions: seq[string]
    transactionsRoot*: FixedBytes[32]

  ExecutionPayloadHeaderOnlyBlockHash* = object
    # Another of these either-snake-or-camel definitions
    # also why use common.Hash elsewhere but string here as block type? Either
    # works, but.
    blockHash*: string

  # https://github.com/flashbots/mev-boost/blob/thegostep/docs/lib/types.go#L26
  BlindedBeaconBlockBodyPartial* = object
    execution_payload_header*: ExecutionPayloadHeaderOnlyBlockHash
    # Either snake_case or camelCase is allowed, or both:
    # https://github.com/flashbots/mev-boost/blob/thegostep/docs/lib/service.go#L157

  # https://github.com/flashbots/mev-boost/blob/thegostep/docs/docs/milestone-1.md#blindedbeaconblock
  # https://github.com/flashbots/mev-boost/blob/thegostep/docs/lib/types.go#L17
  BlindedBeaconBlock* = object
    # These are snake case, while, e.g. ExecutionPayloadWithTxRootV1 is
    # camelCase. And others, such as BlindedBeaconBlockBodyPartial, can be either
    # proposer_index, parent_root, and state_root are all strings for MEV
    slot*: Quantity    # MEV builder service uses string here
    proposer_index*: Quantity
    parent_root*: FixedBytes[32]
    state_root*: FixedBytes[32]
    # The MEV sevice only decodes BlindedBeaconBlockBodyPartial
    # https://github.com/flashbots/mev-boost/blob/thegostep/docs/lib/service.go#L149
    body*: BlindedBeaconBlockBodyPartial

  # https://github.com/flashbots/mev-boost/blob/thegostep/docs/docs/milestone-1.md#signedblindedbeaconblock
  # https://github.com/flashbots/mev-boost/blob/thegostep/docs/lib/types.go#L11
  SignedBlindedBeaconBlock* = object
    message*: BlindedBeaconBlock
    signature*: FixedBytes[96]  # the MEV builder API service uses string here
