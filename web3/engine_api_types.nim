# https://github.com/ethereum/execution-apis/blob/v1.0.0-alpha.4/src/engine/specification.md

import
  std/options,
  ethtypes

export
  ethtypes

type
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-alpha.4/src/engine/specification.md#payloadattributesv1
  PayloadAttributesV1* = object
    timestamp*: Quantity
    random*: FixedBytes[32]
    feeRecipient*: Address

  PayloadExecutionStatus* {.pure.} = enum
    valid   = "VALID"
    invalid = "INVALID"
    syncing = "SYNCING"

  ExecutePayloadResponse* = object
    status*: string
    latestValidHash*: Option[BlockHash]
    message*: Option[string]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-alpha.4/src/engine/specification.md#forkchoicestatev1
  ForkchoiceStateV1* = object
    headBlockHash*: BlockHash
    safeBlockHash*: BlockHash
    finalizedBlockHash*: BlockHash

  ForkchoiceUpdatedStatus* {.pure.} = enum
    success = "SUCCESS"
    syncing = "SYNCING"

  ForkchoiceUpdatedResponse* = object
    status*: ForkchoiceUpdatedStatus
    payloadId*: Option[Quantity]

const
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-alpha.4/src/engine/specification.md#errors
  PARSE_ERROR* = -32700
  INVALID_REQUEST* = -32600
  METHOD_NOT_FOUND* = -32601
  INVALID_PARAMS* = -32602
  INTERNAL_ERROR* = -32603
  SERVER_ERROR* = -32000
  UNKNOWN_PAYLOAD* = -32001
