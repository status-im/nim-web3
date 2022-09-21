import ethtypes, builder_api_types, engine_api_types

# https://github.com/flashbots/mev-boost/blob/thegostep/docs/docs/milestone-1.md#api-docs
# but not what's in the actual code
# proc builder_getPayloadHeaderV1(payloadId: PayloadID): ExecutionPayloadHeaderV1
# proc builder_proposeBlindedBlockV1(blck: SignedBlindedBeaconBlock): ExecutionPayloadV1

# https://github.com/flashbots/mev-boost/blob/thegostep/docs/lib/service.go
proc builder_getPayloadHeaderV1(payloadId: PayloadID): ExecutionPayloadWithTxRootV1
proc builder_proposeBlindedBlockV1(blck: SignedBlindedBeaconBlock): ExecutionPayloadWithTxRootV1
