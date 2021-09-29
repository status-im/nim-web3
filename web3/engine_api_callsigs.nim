# https://github.com/ethereum/execution-apis/blob/main/src/engine/interop/specification.md

import ethtypes, engine_api_types

proc engine_preparePayload(payloadAttributes: PayloadAttributes): PreparePayloadResponse
proc engine_getPayload(payloadId: Quantity): ExecutionPayload
proc engine_executePayload(payload: ExecutionPayload): ExecutePayloadResponse
proc engine_consensusValidated(data: BlockValidationResult)
proc engine_forkchoiceUpdated(update: ForkChoiceUpdate)
