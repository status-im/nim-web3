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
    status*: string
    payloadId*: Option[Quantity]

const
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-alpha.4/src/engine/interop/specification.md#error-codes
  UNKNOWN_HEADER* = 4
  UNKNOWN_PAYLOAD* = 5
