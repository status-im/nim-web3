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

  BlockValidationStatus* {.pure.} = enum
    valid   = "VALID"
    invalid = "INVALID"

  BlockValidationResult* = object
    blockHash*: BlockHash
    status*: string

  ForkChoiceUpdate* = object
    headBlockHash*: BlockHash
    finalizedBlockHash*: BlockHash
