import ethtypes, builder_api_types, engine_api_types

# https://github.com/flashbots/mev-boost/blob/main/docs/specification.md
proc builder_getPayloadHeaderV1(payloadId: PayloadID): ExecutionPayloadHeaderV1
proc builder_proposeBlindedBlockV1(blck: SignedBlindedBeaconBlock): ExecutionPayloadV1
