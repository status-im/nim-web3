# nim-web3
# Copyright (c) 2023-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  stint,
  ./engine_api_types

export
  stint,
  engine_api_types

type
  ExecutionPayload* = object
    parentHash*: Hash256
    feeRecipient*: Address
    stateRoot*: Hash256
    receiptsRoot*: Hash256
    logsBloom*: FixedBytes[256]
    prevRandao*: FixedBytes[32]
    blockNumber*: Quantity
    gasLimit*: Quantity
    gasUsed*: Quantity
    timestamp*: Quantity
    extraData*: DynamicBytes[0, 32]
    baseFeePerGas*: UInt256
    blockHash*: Hash256
    transactions*: seq[TypedTransaction]
    withdrawals*: Opt[seq[WithdrawalV1]]
    blobGasUsed*: Opt[Quantity]
    excessBlobGas*: Opt[Quantity]
    depositReceipts*: Opt[seq[DepositReceiptV1]]
    exits*: Opt[seq[WithdrawalRequestV1]]

  PayloadAttributes* = object
    timestamp*: Quantity
    prevRandao*: FixedBytes[32]
    suggestedFeeRecipient*: Address
    withdrawals*: Opt[seq[WithdrawalV1]]
    parentBeaconBlockRoot*: Opt[FixedBytes[32]]

  SomeOptionalPayloadAttributes* =
    Opt[PayloadAttributesV1] |
    Opt[PayloadAttributesV2] |
    Opt[PayloadAttributesV3]

  GetPayloadResponse* = object
    executionPayload*: ExecutionPayload
    blockValue*: Opt[UInt256]
    blobsBundle*: Opt[BlobsBundleV1]
    shouldOverrideBuilder*: Opt[bool]

  Version* {.pure.} = enum
    V1
    V2
    V3
    V4

{.push raises: [].}

func version*(payload: ExecutionPayload): Version =
  if payload.depositReceipts.isSome or payload.exits.isSome:
    Version.V4
  elif payload.blobGasUsed.isSome or payload.excessBlobGas.isSome:
    Version.V3
  elif payload.withdrawals.isSome:
    Version.V2
  else:
    Version.V1

func version*(attr: PayloadAttributes): Version =
  if attr.parentBeaconBlockRoot.isSome:
    Version.V3
  elif attr.withdrawals.isSome:
    Version.V2
  else:
    Version.V1

func version*(res: GetPayloadResponse): Version =
  # TODO: should this return whatever version of
  # executionPayload.version?
  if res.executionPayload.version == Version.V4:
    Version.V4
  elif res.blobsBundle.isSome or res.shouldOverrideBuilder.isSome:
    Version.V3
  elif res.blockValue.isSome:
    Version.V2
  else:
    Version.V1

func V1V2*(attr: PayloadAttributes): PayloadAttributesV1OrV2 =
  PayloadAttributesV1OrV2(
    timestamp: attr.timestamp,
    prevRandao: attr.prevRandao,
    suggestedFeeRecipient: attr.suggestedFeeRecipient,
    withdrawals: attr.withdrawals
  )

func V1*(attr: PayloadAttributes): PayloadAttributesV1 =
  PayloadAttributesV1(
    timestamp: attr.timestamp,
    prevRandao: attr.prevRandao,
    suggestedFeeRecipient: attr.suggestedFeeRecipient
  )

func V2*(attr: PayloadAttributes): PayloadAttributesV2 =
  PayloadAttributesV2(
    timestamp: attr.timestamp,
    prevRandao: attr.prevRandao,
    suggestedFeeRecipient: attr.suggestedFeeRecipient,
    withdrawals: attr.withdrawals.get
  )

func V3*(attr: PayloadAttributes): PayloadAttributesV3 =
  PayloadAttributesV3(
    timestamp: attr.timestamp,
    prevRandao: attr.prevRandao,
    suggestedFeeRecipient: attr.suggestedFeeRecipient,
    withdrawals: attr.withdrawals.get(newSeq[WithdrawalV1]()),
    parentBeaconBlockRoot: attr.parentBeaconBlockRoot.get
  )

func V1*(attr: Opt[PayloadAttributes]): Opt[PayloadAttributesV1] =
  if attr.isNone:
    return Opt.none(PayloadAttributesV1)
  Opt.some(attr.get.V1)

func V2*(attr: Opt[PayloadAttributes]): Opt[PayloadAttributesV2] =
  if attr.isNone:
    return Opt.none(PayloadAttributesV2)
  Opt.some(attr.get.V2)

func V3*(attr: Opt[PayloadAttributes]): Opt[PayloadAttributesV3] =
  if attr.isNone:
    return Opt.none(PayloadAttributesV3)
  Opt.some(attr.get.V3)

func payloadAttributes*(attr: PayloadAttributesV1): PayloadAttributes =
  PayloadAttributes(
    timestamp: attr.timestamp,
    prevRandao: attr.prevRandao,
    suggestedFeeRecipient: attr.suggestedFeeRecipient
  )

func payloadAttributes*(attr: PayloadAttributesV2): PayloadAttributes =
  PayloadAttributes(
    timestamp: attr.timestamp,
    prevRandao: attr.prevRandao,
    suggestedFeeRecipient: attr.suggestedFeeRecipient,
    withdrawals: Opt.some(attr.withdrawals)
  )

func payloadAttributes*(attr: PayloadAttributesV3): PayloadAttributes =
  PayloadAttributes(
    timestamp: attr.timestamp,
    prevRandao: attr.prevRandao,
    suggestedFeeRecipient: attr.suggestedFeeRecipient,
    withdrawals: Opt.some(attr.withdrawals),
    parentBeaconBlockRoot: Opt.some(attr.parentBeaconBlockRoot)
  )

func payloadAttributes*(x: Opt[PayloadAttributesV1]): Opt[PayloadAttributes] =
  if x.isNone: Opt.none(PayloadAttributes)
  else: Opt.some(payloadAttributes x.get)

func payloadAttributes*(x: Opt[PayloadAttributesV2]): Opt[PayloadAttributes] =
  if x.isNone: Opt.none(PayloadAttributes)
  else: Opt.some(payloadAttributes x.get)

func payloadAttributes*(x: Opt[PayloadAttributesV3]): Opt[PayloadAttributes] =
  if x.isNone: Opt.none(PayloadAttributes)
  else: Opt.some(payloadAttributes x.get)

func V1V2*(p: ExecutionPayload): ExecutionPayloadV1OrV2 =
  ExecutionPayloadV1OrV2(
    parentHash: p.parentHash,
    feeRecipient: p.feeRecipient,
    stateRoot: p.stateRoot,
    receiptsRoot: p.receiptsRoot,
    logsBloom: p.logsBloom,
    prevRandao: p.prevRandao,
    blockNumber: p.blockNumber,
    gasLimit: p.gasLimit,
    gasUsed: p.gasUsed,
    timestamp: p.timestamp,
    extraData: p.extraData,
    baseFeePerGas: p.baseFeePerGas,
    blockHash: p.blockHash,
    transactions: p.transactions,
    withdrawals: p.withdrawals
  )

func V1*(p: ExecutionPayload): ExecutionPayloadV1 =
  ExecutionPayloadV1(
    parentHash: p.parentHash,
    feeRecipient: p.feeRecipient,
    stateRoot: p.stateRoot,
    receiptsRoot: p.receiptsRoot,
    logsBloom: p.logsBloom,
    prevRandao: p.prevRandao,
    blockNumber: p.blockNumber,
    gasLimit: p.gasLimit,
    gasUsed: p.gasUsed,
    timestamp: p.timestamp,
    extraData: p.extraData,
    baseFeePerGas: p.baseFeePerGas,
    blockHash: p.blockHash,
    transactions: p.transactions
  )

func V2*(p: ExecutionPayload): ExecutionPayloadV2 =
  ExecutionPayloadV2(
    parentHash: p.parentHash,
    feeRecipient: p.feeRecipient,
    stateRoot: p.stateRoot,
    receiptsRoot: p.receiptsRoot,
    logsBloom: p.logsBloom,
    prevRandao: p.prevRandao,
    blockNumber: p.blockNumber,
    gasLimit: p.gasLimit,
    gasUsed: p.gasUsed,
    timestamp: p.timestamp,
    extraData: p.extraData,
    baseFeePerGas: p.baseFeePerGas,
    blockHash: p.blockHash,
    transactions: p.transactions,
    withdrawals: p.withdrawals.get
  )

func V3*(p: ExecutionPayload): ExecutionPayloadV3 =
  ExecutionPayloadV3(
    parentHash: p.parentHash,
    feeRecipient: p.feeRecipient,
    stateRoot: p.stateRoot,
    receiptsRoot: p.receiptsRoot,
    logsBloom: p.logsBloom,
    prevRandao: p.prevRandao,
    blockNumber: p.blockNumber,
    gasLimit: p.gasLimit,
    gasUsed: p.gasUsed,
    timestamp: p.timestamp,
    extraData: p.extraData,
    baseFeePerGas: p.baseFeePerGas,
    blockHash: p.blockHash,
    transactions: p.transactions,
    withdrawals: p.withdrawals.get,
    blobGasUsed: p.blobGasUsed.get(0.Quantity),
    excessBlobGas: p.excessBlobGas.get(0.Quantity)
  )

# func V4*(p: ExecutionPayload): ExecutionPayloadV4 =
#   ExecutionPayloadV4(
#     parentHash: p.parentHash,
#     feeRecipient: p.feeRecipient,
#     stateRoot: p.stateRoot,
#     receiptsRoot: p.receiptsRoot,
#     logsBloom: p.logsBloom,
#     prevRandao: p.prevRandao,
#     blockNumber: p.blockNumber,
#     gasLimit: p.gasLimit,
#     gasUsed: p.gasUsed,
#     timestamp: p.timestamp,
#     extraData: p.extraData,
#     baseFeePerGas: p.baseFeePerGas,
#     blockHash: p.blockHash,
#     transactions: p.transactions,
#     withdrawals: p.withdrawals.get,
#     blobGasUsed: p.blobGasUsed.get(0.Quantity),
#     excessBlobGas: p.excessBlobGas.get(0.Quantity),
#     depositRequests: p.depositReceipts.get(newSeq[DepositReceiptV1]()),
#     withdrawalRequests: p.exits.get(newSeq[WithdrawalRequestV1]())
#   )

func V1*(p: ExecutionPayloadV1OrV2): ExecutionPayloadV1 =
  ExecutionPayloadV1(
    parentHash: p.parentHash,
    feeRecipient: p.feeRecipient,
    stateRoot: p.stateRoot,
    receiptsRoot: p.receiptsRoot,
    logsBloom: p.logsBloom,
    prevRandao: p.prevRandao,
    blockNumber: p.blockNumber,
    gasLimit: p.gasLimit,
    gasUsed: p.gasUsed,
    timestamp: p.timestamp,
    extraData: p.extraData,
    baseFeePerGas: p.baseFeePerGas,
    blockHash: p.blockHash,
    transactions: p.transactions
  )

func V2*(p: ExecutionPayloadV1OrV2): ExecutionPayloadV2 =
  ExecutionPayloadV2(
    parentHash: p.parentHash,
    feeRecipient: p.feeRecipient,
    stateRoot: p.stateRoot,
    receiptsRoot: p.receiptsRoot,
    logsBloom: p.logsBloom,
    prevRandao: p.prevRandao,
    blockNumber: p.blockNumber,
    gasLimit: p.gasLimit,
    gasUsed: p.gasUsed,
    timestamp: p.timestamp,
    extraData: p.extraData,
    baseFeePerGas: p.baseFeePerGas,
    blockHash: p.blockHash,
    transactions: p.transactions,
    withdrawals: p.withdrawals.get
  )

func executionPayload*(p: ExecutionPayloadV1): ExecutionPayload =
  ExecutionPayload(
    parentHash: p.parentHash,
    feeRecipient: p.feeRecipient,
    stateRoot: p.stateRoot,
    receiptsRoot: p.receiptsRoot,
    logsBloom: p.logsBloom,
    prevRandao: p.prevRandao,
    blockNumber: p.blockNumber,
    gasLimit: p.gasLimit,
    gasUsed: p.gasUsed,
    timestamp: p.timestamp,
    extraData: p.extraData,
    baseFeePerGas: p.baseFeePerGas,
    blockHash: p.blockHash,
    transactions: p.transactions
  )

func executionPayload*(p: ExecutionPayloadV2): ExecutionPayload =
  ExecutionPayload(
    parentHash: p.parentHash,
    feeRecipient: p.feeRecipient,
    stateRoot: p.stateRoot,
    receiptsRoot: p.receiptsRoot,
    logsBloom: p.logsBloom,
    prevRandao: p.prevRandao,
    blockNumber: p.blockNumber,
    gasLimit: p.gasLimit,
    gasUsed: p.gasUsed,
    timestamp: p.timestamp,
    extraData: p.extraData,
    baseFeePerGas: p.baseFeePerGas,
    blockHash: p.blockHash,
    transactions: p.transactions,
    withdrawals: Opt.some(p.withdrawals)
  )

func executionPayload*(p: ExecutionPayloadV3): ExecutionPayload =
  ExecutionPayload(
    parentHash: p.parentHash,
    feeRecipient: p.feeRecipient,
    stateRoot: p.stateRoot,
    receiptsRoot: p.receiptsRoot,
    logsBloom: p.logsBloom,
    prevRandao: p.prevRandao,
    blockNumber: p.blockNumber,
    gasLimit: p.gasLimit,
    gasUsed: p.gasUsed,
    timestamp: p.timestamp,
    extraData: p.extraData,
    baseFeePerGas: p.baseFeePerGas,
    blockHash: p.blockHash,
    transactions: p.transactions,
    withdrawals: Opt.some(p.withdrawals),
    blobGasUsed: Opt.some(p.blobGasUsed),
    excessBlobGas: Opt.some(p.excessBlobGas)
  )

# func executionPayload*(p: ExecutionPayloadV4): ExecutionPayload =
#   ExecutionPayload(
#     parentHash: p.parentHash,
#     feeRecipient: p.feeRecipient,
#     stateRoot: p.stateRoot,
#     receiptsRoot: p.receiptsRoot,
#     logsBloom: p.logsBloom,
#     prevRandao: p.prevRandao,
#     blockNumber: p.blockNumber,
#     gasLimit: p.gasLimit,
#     gasUsed: p.gasUsed,
#     timestamp: p.timestamp,
#     extraData: p.extraData,
#     baseFeePerGas: p.baseFeePerGas,
#     blockHash: p.blockHash,
#     transactions: p.transactions,
#     withdrawals: Opt.some(p.withdrawals),
#     blobGasUsed: Opt.some(p.blobGasUsed),
#     excessBlobGas: Opt.some(p.excessBlobGas),
#     depositReceipts: Opt.some(p.depositRequests),
#     exits: Opt.some(p.withdrawalRequests)
#   )

func executionPayload*(p: ExecutionPayloadV1OrV2): ExecutionPayload =
  ExecutionPayload(
    parentHash: p.parentHash,
    feeRecipient: p.feeRecipient,
    stateRoot: p.stateRoot,
    receiptsRoot: p.receiptsRoot,
    logsBloom: p.logsBloom,
    prevRandao: p.prevRandao,
    blockNumber: p.blockNumber,
    gasLimit: p.gasLimit,
    gasUsed: p.gasUsed,
    timestamp: p.timestamp,
    extraData: p.extraData,
    baseFeePerGas: p.baseFeePerGas,
    blockHash: p.blockHash,
    transactions: p.transactions,
    withdrawals: p.withdrawals
  )

func V1*(res: GetPayloadResponse): ExecutionPayloadV1 =
  res.executionPayload.V1

func V2*(res: GetPayloadResponse): GetPayloadV2Response =
  GetPayloadV2Response(
    executionPayload: res.executionPayload.V1V2,
    blockValue: res.blockValue.get
  )

func V3*(res: GetPayloadResponse): GetPayloadV3Response =
  GetPayloadV3Response(
    executionPayload: res.executionPayload.V3,
    blockValue: res.blockValue.get,
    blobsBundle: res.blobsBundle.get(BlobsBundleV1()),
    shouldOverrideBuilder: res.shouldOverrideBuilder.get(false)
  )

# func V4*(res: GetPayloadResponse): GetPayloadV4Response =
#   GetPayloadV4Response(
#     executionPayload: res.executionPayload.V4,
#     blockValue: res.blockValue.get,
#     blobsBundle: res.blobsBundle.get(BlobsBundleV1()),
#     shouldOverrideBuilder: res.shouldOverrideBuilder.get(false)
#   )

func getPayloadResponse*(x: ExecutionPayloadV1): GetPayloadResponse =
  GetPayloadResponse(executionPayload: x.executionPayload)

func getPayloadResponse*(x: GetPayloadV2Response): GetPayloadResponse =
  GetPayloadResponse(
    executionPayload: x.executionPayload.executionPayload,
    blockValue: Opt.some(x.blockValue)
  )

func getPayloadResponse*(x: GetPayloadV3Response): GetPayloadResponse =
  GetPayloadResponse(
    executionPayload: x.executionPayload.executionPayload,
    blockValue: Opt.some(x.blockValue),
    blobsBundle: Opt.some(x.blobsBundle),
    shouldOverrideBuilder: Opt.some(x.shouldOverrideBuilder)
  )

# func getPayloadResponse*(x: GetPayloadV4Response): GetPayloadResponse =
#   GetPayloadResponse(
#     executionPayload: x.executionPayload.executionPayload,
#     blockValue: Opt.some(x.blockValue),
#     blobsBundle: Opt.some(x.blobsBundle),
#     shouldOverrideBuilder: Opt.some(x.shouldOverrideBuilder)
#   )
