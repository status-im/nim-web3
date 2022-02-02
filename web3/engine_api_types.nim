import
  std/options,
  ethtypes

export
  ethtypes

type
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-alpha.6/src/engine/specification.md#payloadattributesv1
  PayloadAttributesV1* = object
    timestamp*: Quantity
    random*: FixedBytes[32]
    suggestedFeeRecipient*: Address

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-alpha.6/src/engine/specification.md#payloadstatusv1
  PayloadExecutionStatus* {.pure.} = enum
    valid                  = "VALID"
    invalid                = "INVALID"
    syncing                = "SYNCING"
    accepted               = "ACCEPTED"
    invalid_block_hash     = "INVALID_BLOCK_HASH"
    invalid_terminal_block = "INVALID_TERMINAL_BLOCK"

  PayloadStatusV1* = object
    status*: PayloadExecutionStatus
    latestValidHash*: Option[BlockHash]
    validationError*: Option[string]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-alpha.6/src/engine/specification.md#forkchoicestatev1
  ForkchoiceStateV1* = object
    headBlockHash*: BlockHash
    safeBlockHash*: BlockHash
    finalizedBlockHash*: BlockHash

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-alpha.6/src/engine/specification.md#response-1
  ForkchoiceUpdatedStatus* {.pure.} = enum
    valid                  = "VALID"
    invalid                = "INVALID"
    syncing                = "SYNCING"
    invalid_terminal_block = "INVALID_TERMINAL_BLOCK"

  PayloadID* = FixedBytes[8]

  ForkchoiceUpdatedResponse* = object
    payloadStatus*: ForkchoiceUpdatedStatus
    payloadId*: Option[PayloadID]

const
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-alpha.6/src/engine/specification.md#errors
  engineApiParseError* = - 32700
  engineApiInvalidRequest* = -32600
  engineApiMethodNotFound* = -32601
  engineApiInvalidParams* = -32602
  engineApiInternalError* = -32603
  engineApiServerError* = -32000
  engineApiUnknownPayload* = -32001
