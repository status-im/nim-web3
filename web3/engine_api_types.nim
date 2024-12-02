# nim-web3
# Copyright (c) 2022-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [].}

import
  std/typetraits,
  stint,
  primitives,
  results

export
  results, stint, primitives

type
  TypedTransaction* = distinct seq[byte]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/shanghai.md#withdrawalv1
  WithdrawalV1* = object
    index*: Quantity
    validatorIndex*: Quantity
    address*: Address
    amount*: Quantity

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/paris.md#executionpayloadv1
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/openrpc/schemas/payload.yaml#L51
  ExecutionPayloadV1* = object
    parentHash*: Hash32
    feeRecipient*: Address
    stateRoot*: Hash32
    receiptsRoot*: Hash32
    logsBloom*: Bytes256
    prevRandao*: Bytes32
    blockNumber*: Quantity
    gasLimit*: Quantity
    gasUsed*: Quantity
    timestamp*: Quantity
    extraData*: DynamicBytes[0, 32]
    baseFeePerGas*: UInt256
    blockHash*: Hash32
    transactions*: seq[TypedTransaction]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/shanghai.md#executionpayloadv2
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/openrpc/schemas/payload.yaml#L135
  ExecutionPayloadV2* = object
    parentHash*: Hash32
    feeRecipient*: Address
    stateRoot*: Hash32
    receiptsRoot*: Hash32
    logsBloom*: Bytes256
    prevRandao*: Bytes32
    blockNumber*: Quantity
    gasLimit*: Quantity
    gasUsed*: Quantity
    timestamp*: Quantity
    extraData*: DynamicBytes[0, 32]
    baseFeePerGas*: UInt256
    blockHash*: Hash32
    transactions*: seq[TypedTransaction]
    withdrawals*: seq[WithdrawalV1]

  # This is ugly, but I don't think the RPC library will handle
  # ExecutionPayloadV1 | ExecutionPayloadV2. (Am I wrong?)
  # Note that the spec currently says that various V2 methods
  # (e.g. engine_newPayloadV2) need to accept *either* V1 or V2
  # of the data structure (e.g. either ExecutionPayloadV1 or
  # ExecutionPayloadV2); it's not like V2 of the method only
  # needs to accept V2 of the structure. Anyway, the best way
  # I've found to handle this is to make this structure with an
  # Option for the withdrawals field. If you've got a better idea,
  # please fix this. (Maybe the RPC library does handle sum types?
  # Or maybe we can enhance it to do so?) --Adam
  #
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/shanghai.md
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/openrpc/schemas/payload.yaml#L51
  ExecutionPayloadV1OrV2* = object
    parentHash*: Hash32
    feeRecipient*: Address
    stateRoot*: Hash32
    receiptsRoot*: Hash32
    logsBloom*: Bytes256
    prevRandao*: Bytes32
    blockNumber*: Quantity
    gasLimit*: Quantity
    gasUsed*: Quantity
    timestamp*: Quantity
    extraData*: DynamicBytes[0, 32]
    baseFeePerGas*: UInt256
    blockHash*: Hash32
    transactions*: seq[TypedTransaction]
    withdrawals*: Opt[seq[WithdrawalV1]]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/cancun.md#executionpayloadv3
  ExecutionPayloadV3* = object
    parentHash*: Hash32
    feeRecipient*: Address
    stateRoot*: Hash32
    receiptsRoot*: Hash32
    logsBloom*: Bytes256
    prevRandao*: Bytes32
    blockNumber*: Quantity
    gasLimit*: Quantity
    gasUsed*: Quantity
    timestamp*: Quantity
    extraData*: DynamicBytes[0, 32]
    baseFeePerGas*: UInt256
    blockHash*: Hash32
    transactions*: seq[TypedTransaction]
    withdrawals*: seq[WithdrawalV1]
    blobGasUsed*: Quantity
    excessBlobGas*: Quantity

  SomeExecutionPayload* =
    ExecutionPayloadV1 |
    ExecutionPayloadV2 |
    ExecutionPayloadV3

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/cancun.md#blobsbundlev1
  BlobsBundleV1* = object
    commitments*: seq[KzgCommitment]
    proofs*: seq[KzgProof]
    blobs*: seq[Blob]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/shanghai.md#executionpayloadbodyv1
  # For optional withdrawals field, see:
  #   https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/shanghai.md#engine_getpayloadbodiesbyhashv1
  #   https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/shanghai.md#engine_getpayloadbodiesbyrangev1
  # "Client software MUST set withdrawals field to null for bodies of pre-Shanghai blocks."
  ExecutionPayloadBodyV1* = object
    transactions*: seq[TypedTransaction]
    withdrawals*: Opt[seq[WithdrawalV1]]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/paris.md#payloadattributesv1
  PayloadAttributesV1* = object
    timestamp*: Quantity
    prevRandao*: Bytes32
    suggestedFeeRecipient*: Address

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/shanghai.md#payloadattributesv2
  PayloadAttributesV2* = object
    timestamp*: Quantity
    prevRandao*: Bytes32
    suggestedFeeRecipient*: Address
    withdrawals*: seq[WithdrawalV1]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/cancun.md#payloadattributesv3
  PayloadAttributesV3* = object
    timestamp*: Quantity
    prevRandao*: Bytes32
    suggestedFeeRecipient*: Address
    withdrawals*: seq[WithdrawalV1]
    parentBeaconBlockRoot*: Hash32

  PayloadAttributesV4* = object
    timestamp*: Quantity
    prevRandao*: Bytes32
    suggestedFeeRecipient*: Address
    withdrawals*: seq[WithdrawalV1]
    parentBeaconBlockRoot*: Hash32
    targetBlobsPerBlock*: Quantity
    maxBlobsPerBlock*: Quantity

  # This is ugly, but see the comment on ExecutionPayloadV1OrV2.
  PayloadAttributesV1OrV2* = object
    timestamp*: Quantity
    prevRandao*: Bytes32
    suggestedFeeRecipient*: Address
    withdrawals*: Opt[seq[WithdrawalV1]]

  SomePayloadAttributes* =
    PayloadAttributesV1 |
    PayloadAttributesV2 |
    PayloadAttributesV3 |
    PayloadAttributesV4

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/paris.md#payloadstatusv1
  PayloadExecutionStatus* {.pure.} = enum
    syncing = "SYNCING"
    valid = "VALID"
    invalid = "INVALID"
    accepted = "ACCEPTED"
    invalid_block_hash = "INVALID_BLOCK_HASH"

  PayloadStatusV1* = object
    status*: PayloadExecutionStatus
    latestValidHash*: Opt[Hash32]
    validationError*: Opt[string]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/paris.md#forkchoicestatev1
  ForkchoiceStateV1* = object
    headBlockHash*: Hash32
    safeBlockHash*: Hash32
    finalizedBlockHash*: Hash32

  # https://github.com/ethereum/execution-apis/blob/main/src/engine/openrpc/schemas/forkchoice.yaml#L18
  ForkchoiceUpdatedResponse* = object
    payloadStatus*: PayloadStatusV1
    payloadId*: Opt[Bytes8]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/paris.md#transitionconfigurationv1
  TransitionConfigurationV1* = object
    terminalTotalDifficulty*: UInt256
    terminalBlockHash*: Hash32
    terminalBlockNumber*: Quantity

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/shanghai.md#response-2
  GetPayloadV2Response* = object
    executionPayload*: ExecutionPayloadV1OrV2
    blockValue*: UInt256

  GetPayloadV2ResponseExact* = object
    executionPayload*: ExecutionPayloadV2
    blockValue*: UInt256

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/cancun.md#response-2
  GetPayloadV3Response* = object
    executionPayload*: ExecutionPayloadV3
    blockValue*: UInt256
    blobsBundle*: BlobsBundleV1
    shouldOverrideBuilder*: bool

  # https://github.com/ethereum/execution-apis/blob/4140e528360fea53c34a766d86a000c6c039100e/src/engine/prague.md#response-1
  GetPayloadV4Response* = object
    executionPayload*: ExecutionPayloadV3
    blockValue*: UInt256
    blobsBundle*: BlobsBundleV1
    shouldOverrideBuilder*: bool
    executionRequests*: array[3, seq[byte]]

  SomeGetPayloadResponse* =
    ExecutionPayloadV1 |
    GetPayloadV2Response |
    GetPayloadV3Response |
    GetPayloadV4Response

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/identification.md#engine_getclientversionv1
  ClientVersionV1* = object
    code*: string # e.g. NB or BU
    name*: string # Human-readable name of the client, e.g. Lighthouse or go-ethereum
    version*: string #  the version string of the current implementation e.g. v4.6.0 or 1.0.0-alpha.1 or 1.0.0+20130313144700
    commit*: Bytes4

const
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/common.md#errors
  engineApiParseError* = -32700
  engineApiInvalidRequest* = -32600
  engineApiMethodNotFound* = -32601
  engineApiInvalidParams* = -32602
  engineApiInternalError* = -32603
  engineApiServerError* = -32000
  engineApiUnknownPayload* = -38001
  engineApiInvalidForkchoiceState* = -38002
  engineApiInvalidPayloadAttributes* = -38003
  engineApiTooLargeRequest* = -38004
  engineApiUnsupportedFork* = -38005

template `==`*(a, b: TypedTransaction): bool =
  distinctBase(a) == distinctBase(b)

# Backwards compatibility

type
  PayloadID* {.deprecated.} = Bytes8