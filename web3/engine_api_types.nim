import
  std/options,
  stint,
  ethtypes

export
  options, stint, ethtypes

type
  # https://github.com/ethereum/execution-apis/blob/d03c193dc317538e2a1a098030c21bacc2fd1333/src/engine/shanghai.md#executionpayloadbodyv1
  ExecutionPayloadBodyV1* = object
    transactions*: seq[TypedTransaction]
    withdrawals*: seq[WithdrawalV1]
  
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.2/src/engine/paris.md#payloadattributesv1
  PayloadAttributesV1* = object
    timestamp*: Quantity
    prevRandao*: FixedBytes[32]
    suggestedFeeRecipient*: Address

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.2/src/engine/shanghai.md#payloadattributesv2
  PayloadAttributesV2* = object
    timestamp*: Quantity
    prevRandao*: FixedBytes[32]
    suggestedFeeRecipient*: Address
    withdrawals*: seq[WithdrawalV1]

  # This is ugly, but see the comment on ExecutionPayloadV1OrV2.
  PayloadAttributesV1OrV2* = object
    timestamp*: Quantity
    prevRandao*: FixedBytes[32]
    suggestedFeeRecipient*: Address
    withdrawals*: Option[seq[WithdrawalV1]]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.2/src/engine/paris.md#payloadstatusv1
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

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.2/src/engine/paris.md#forkchoicestatev1
  ForkchoiceStateV1* = object
    headBlockHash*: BlockHash
    safeBlockHash*: BlockHash
    finalizedBlockHash*: BlockHash

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.2/src/engine/paris.md#response-1
  PayloadID* = FixedBytes[8]

  ForkchoiceUpdatedResponse* = object
    payloadStatus*: PayloadStatusV1
    payloadId*: Option[PayloadID]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.2/src/engine/paris.md#transitionconfigurationv1
  TransitionConfigurationV1* = object
    terminalTotalDifficulty*: UInt256
    terminalBlockHash*: BlockHash
    terminalBlockNumber*: Quantity

  # https://github.com/ethereum/execution-apis/blob/main/src/engine/shanghai.md#engine_getpayloadv2
  GetPayloadV2Response* = object
    executionPayload*: ExecutionPayloadV1OrV2
    blockValue*: Quantity

  GetPayloadV3Response* = object
    executionPayload*: ExecutionPayloadV3
    blockValue*: Quantity

  SomeGetPayloadResponse* =
    ExecutionPayloadV1 |
    GetPayloadV2Response |
    GetPayloadV3Response

const
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.2/src/engine/common.md#errors
  engineApiParseError* = - 32700
  engineApiInvalidRequest* = -32600
  engineApiMethodNotFound* = -32601
  engineApiInvalidParams* = -32602
  engineApiInternalError* = -32603
  engineApiServerError* = -32000
  engineApiUnknownPayload* = -38001
  engineApiInvalidForkchoiceState* = -38002
  engineApiInvalidPayloadAttributes* = -38003
  engineApiTooLargeRequest* = -38004
