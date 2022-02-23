# https://github.com/ethereum/execution-apis/blob/v1.0.0-alpha.7/src/engine/specification.md#core

import ethtypes, engine_api_types

proc engine_newPayloadV1(payload: ExecutionPayloadV1): PayloadStatusV1
proc engine_forkchoiceUpdatedV1(forkchoiceState: ForkchoiceStateV1, payloadAttributes: Option[PayloadAttributesV1]): ForkchoiceUpdatedResponse
proc engine_getPayloadV1(payloadId: PayloadID): ExecutionPayloadV1
proc engine_exchangeTransitionConfigurationV1(transitionConfiguration: TransitionConfigurationV1): TransitionConfigurationV1
