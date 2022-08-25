import
  std/options,
  stint,
  ethtypes

export
  ethtypes

type
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.1/src/engine/specification.md#payloadattributesv1
  PayloadAttributesV1* = object
    timestamp*: Quantity
    prevRandao*: FixedBytes[32]
    suggestedFeeRecipient*: Address

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.1/src/engine/specification.md#payloadstatusv1
  PayloadExecutionStatus* {.pure.} = enum
    syncing            = "SYNCING"
    valid              = "VALID"
    invalid            = "INVALID"
    accepted           = "ACCEPTED"
    invalid_block_hash = "INVALID_BLOCK_HASH"

  PayloadStatusV1* = object
    status*: PayloadExecutionStatus
    latestValidHash*: Option[BlockHash]
    validationError*: Option[string]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.1/src/engine/specification.md#forkchoicestatev1
  ForkchoiceStateV1* = object
    headBlockHash*: BlockHash
    safeBlockHash*: BlockHash
    finalizedBlockHash*: BlockHash

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.1/src/engine/specification.md#response-1
  PayloadID* = FixedBytes[8]

  ForkchoiceUpdatedResponse* = object
    payloadStatus*: PayloadStatusV1
    payloadId*: Option[PayloadID]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.1/src/engine/specification.md#transitionconfigurationv1
  TransitionConfigurationV1* = object
    terminalTotalDifficulty*: UInt256
    terminalBlockHash*: BlockHash
    terminalBlockNumber*: Quantity

const
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.1/src/engine/specification.md#errors
  engineApiParseError* = - 32700
  engineApiInvalidRequest* = -32600
  engineApiMethodNotFound* = -32601
  engineApiInvalidParams* = -32602
  engineApiInternalError* = -32603
  engineApiServerError* = -32000
  engineApiUnknownPayload* = -38001
  engineApiInvalidPayloadAttributes* = -38002
