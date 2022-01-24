import
  std/options,
  ethtypes

export
  ethtypes

type
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-alpha.5/src/engine/specification.md#payloadattributesv1
  PayloadAttributesV1* = object
    timestamp*: Quantity
    random*: FixedBytes[32]
    suggestedFeeRecipient*: Address

  PayloadExecutionStatus* {.pure.} = enum
    valid   = "VALID"
    invalid = "INVALID"
    syncing = "SYNCING"

  PayloadID* = FixedBytes[8]

  ExecutePayloadResponse* = object
    status*: PayloadExecutionStatus
    latestValidHash*: Option[BlockHash]
    validationError*: Option[string]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-alpha.5/src/engine/specification.md#forkchoicestatev1
  ForkchoiceStateV1* = object
    headBlockHash*: BlockHash
    safeBlockHash*: BlockHash
    finalizedBlockHash*: BlockHash

  ForkchoiceUpdatedStatus* {.pure.} = enum
    success = "SUCCESS"
    syncing = "SYNCING"

  ForkchoiceUpdatedResponse* = object
    status*: ForkchoiceUpdatedStatus
    payloadId*: Option[PayloadID]

const
  engineApiParseError* = - 32700
  engineApiInvalidRequest* = -32600
  engineApiMethodNotFound* = -32601
  engineApiInvalidParams* = -32602
  engineApiInternalError* = -32603
  engineApiServerError* = -32000
  engineApiUnknownPayload* = -32001
  engineApiInvalidTerminalBlock* = -32002
