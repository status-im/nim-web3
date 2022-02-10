import
  ethtypes

export
  ethtypes

type
  # https://github.com/ethereum/consensus-specs/blob/v1.1.9/specs/bellatrix/beacon-chain.md#executionpayloadheader
  ExecutionPayloadHeaderV1* = object
    parent_hash*: FixedBytes[32]
    fee_recipient*: Address
    state_root*: FixedBytes[32]
    receipts_root*: FixedBytes[32]
    logs_bloom*: FixedBytes[256]
    random*: FixedBytes[32]
    block_number*: Quantity
    gas_limit*: Quantity
    gas_used*: Quantity
    timestamp*: Quantity
    extra_data*: string    # List[byte, MAX_EXTRA_DATA_BYTES]
    base_fee_per_gas*: FixedBytes[32]  # base fee introduced in EIP-1559, little-endian serialized

  # https://github.com/flashbots/mev-boost/blob/thegostep/docs/docs/milestone-1.md#blindedbeaconblockbody
  BlindedBeaconBlockBody* = object
    randao_reveal*: FixedBytes[96]
    eth1_data*: string # Eth1Data
    graffiti*: FixedBytes[32]
    proposer_slashings*: string # List[ProposerSlashing, MAX_PROPOSER_SLASHINGS]
    attester_slashings*: string # List[AttesterSlashing, MAX_ATTESTER_SLASHINGS]
    attestations*: string # List[Attestation, MAX_ATTESTATIONS]
    voluntary_exits*: string # List[SignedVoluntaryExit, MAX_VOLUNTARY_EXITS]
    sync_aggregate*: string # SyncAggregate
    execution_payload_header*: ExecutionPayloadHeaderV1

  # https://github.com/flashbots/mev-boost/blob/thegostep/docs/docs/milestone-1.md#blindedbeaconblock
  BlindedBeaconBlock* = object
    slot*: Quantity
    proposer_index*: Quantity
    parent_root*: FixedBytes[32]
    state_root*: FixedBytes[32]
    body*: BlindedBeaconBlockBody

  # https://github.com/flashbots/mev-boost/blob/thegostep/docs/docs/milestone-1.md#signedblindedbeaconblock
  SignedBlindedBeaconBlock* = object
    message*: BlindedBeaconBlock
    signature*: FixedBytes[96]
    
