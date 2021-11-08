# https://github.com/ethereum/execution-apis/blob/v1.0.0-alpha.4/src/engine/specification.md

import ethtypes, engine_api_types

proc engine_executePayloadV1(payload: ExecutionPayloadV1): ExecutePayloadResponse
proc engine_forkchoiceUpdatedV1(forkchoiceState: ForkchoiceStateV1): ForkchoiceUpdatedResponse
proc engine_getPayloadV1(payloadId: Quantity): ExecutionPayloadV1
