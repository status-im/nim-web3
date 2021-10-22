# https://github.com/ethereum/execution-apis/blob/main/src/engine/interop/specification.md

import
  ethtypes

export
  ethtypes

type
  PayloadAttributes* = object
    parentHash*: BlockHash
    timestamp*: Quantity
    random*: FixedBytes[32]
    feeRecipient*: Address

  PreparePayloadResponse* = object
    payloadId*: Quantity

  PayloadExecutionStatus* {.pure.} = enum
    valid   = "VALID"
    invalid = "INVALID"
    syncing = "SYNCING"

  ExecutePayloadResponse* = object
    status*: string

  ForkChoiceUpdate* = object
    headBlockHash*: BlockHash
    finalizedBlockHash*: BlockHash

const
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-alpha.2/src/engine/interop/specification.md
  UNKNOWN_HEADER* = 4
  UNKNOWN_PAYLOAD* = 5
