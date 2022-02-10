# https://github.com/flashbots/mev-boost/blob/thegostep/docs/docs/milestone-1.md#api-docs

import ethtypes, builder_api_types, engine_api_types

proc builder_getPayloadHeaderV1(payloadId: PayloadID): ExecutionPayloadHeaderV1
proc builder_proposeBlindedBlockV1(blck: SignedBlindedBeaconBlock): ExecutionPayloadV1
