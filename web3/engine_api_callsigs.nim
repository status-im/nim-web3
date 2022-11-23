# https://github.com/ethereum/execution-apis/blob/f33432b3a3f3d6de6ff5e7977f580376df9b57d9/src/engine/specification.md#core

import ethtypes, engine_api_types

proc engine_newPayloadV1(payload: ExecutionPayloadV1): PayloadStatusV1
proc engine_newPayloadV2(payload: ExecutionPayloadV2): PayloadStatusV1
proc engine_forkchoiceUpdatedV1(forkchoiceState: ForkchoiceStateV1, payloadAttributes: Option[PayloadAttributesV1]): ForkchoiceUpdatedResponse
proc engine_forkchoiceUpdatedV2(forkchoiceState: ForkchoiceStateV1, payloadAttributes: Option[PayloadAttributesV2]): ForkchoiceUpdatedResponse
proc engine_getPayloadV1(payloadId: PayloadID): ExecutionPayloadV1
proc engine_getPayloadV2(payloadId: PayloadID): ExecutionPayloadV2
proc engine_exchangeTransitionConfigurationV1(transitionConfiguration: TransitionConfigurationV1): TransitionConfigurationV1
