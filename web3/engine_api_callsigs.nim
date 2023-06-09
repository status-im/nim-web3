# https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.3/src/engine/paris.md#methods
# https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.3/src/engine/shanghai.md#methods

import ethtypes, engine_api_types

proc engine_newPayloadV1(payload: ExecutionPayloadV1): PayloadStatusV1
proc engine_newPayloadV2(payload: ExecutionPayloadV2): PayloadStatusV1
proc engine_newPayloadV3(payload: ExecutionPayloadV3, versioned_hashes: seq[VersionedHash]): PayloadStatusV1
proc engine_forkchoiceUpdatedV1(forkchoiceState: ForkchoiceStateV1, payloadAttributes: Option[PayloadAttributesV1]): ForkchoiceUpdatedResponse
proc engine_forkchoiceUpdatedV2(forkchoiceState: ForkchoiceStateV1, payloadAttributes: Option[PayloadAttributesV2]): ForkchoiceUpdatedResponse
proc engine_getPayloadV1(payloadId: PayloadID): ExecutionPayloadV1
proc engine_getPayloadV2(payloadId: PayloadID): GetPayloadV2Response
proc engine_getPayloadV2_exact(payloadId: PayloadID): GetPayloadV2ResponseExact
proc engine_getPayloadV3(payloadId: PayloadID): GetPayloadV3Response
proc engine_exchangeTransitionConfigurationV1(transitionConfiguration: TransitionConfigurationV1): TransitionConfigurationV1
proc engine_getPayloadBodiesByHashV1(hashes: seq[BlockHash]): seq[Option[ExecutionPayloadBodyV1]]
