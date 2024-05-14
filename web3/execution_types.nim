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
    withdrawals*: Option[seq[WithdrawalV1]]
    blobGasUsed*: Option[Quantity]
    excessBlobGas*: Option[Quantity]
    depositReceipts*: Option[seq[DepositReceiptV1]]
    exits*: Option[seq[WithdrawalRequestV1]]

  PayloadAttributes* = object
    timestamp*: Quantity
    prevRandao*: FixedBytes[32]
    suggestedFeeRecipient*: Address
    withdrawals*: Option[seq[WithdrawalV1]]
    parentBeaconBlockRoot*: Option[FixedBytes[32]]

  SomeOptionalPayloadAttributes* =
    Option[PayloadAttributesV1] |
    Option[PayloadAttributesV2] |
    Option[PayloadAttributesV3]

  GetPayloadResponse* = object
    executionPayload*: ExecutionPayload
    blockValue*: Option[UInt256]
    blobsBundle*: Option[BlobsBundleV1]
    shouldOverrideBuilder*: Option[bool]

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

func V1*(attr: Option[PayloadAttributes]): Option[PayloadAttributesV1] =
  if attr.isNone:
    return none(PayloadAttributesV1)
  some(attr.get.V1)

func V2*(attr: Option[PayloadAttributes]): Option[PayloadAttributesV2] =
  if attr.isNone:
    return none(PayloadAttributesV2)
  some(attr.get.V2)

func V3*(attr: Option[PayloadAttributes]): Option[PayloadAttributesV3] =
  if attr.isNone:
    return none(PayloadAttributesV3)
  some(attr.get.V3)

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
    withdrawals: some(attr.withdrawals)
  )

func payloadAttributes*(attr: PayloadAttributesV3): PayloadAttributes =
  PayloadAttributes(
    timestamp: attr.timestamp,
    prevRandao: attr.prevRandao,
    suggestedFeeRecipient: attr.suggestedFeeRecipient,
    withdrawals: some(attr.withdrawals),
    parentBeaconBlockRoot: some(attr.parentBeaconBlockRoot)
  )

func payloadAttributes*(x: Option[PayloadAttributesV1]): Option[PayloadAttributes] =
  if x.isNone: none(PayloadAttributes)
  else: some(payloadAttributes x.get)

func payloadAttributes*(x: Option[PayloadAttributesV2]): Option[PayloadAttributes] =
  if x.isNone: none(PayloadAttributes)
  else: some(payloadAttributes x.get)

func payloadAttributes*(x: Option[PayloadAttributesV3]): Option[PayloadAttributes] =
  if x.isNone: none(PayloadAttributes)
  else: some(payloadAttributes x.get)

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

func V4*(p: ExecutionPayload): ExecutionPayloadV4 =
  ExecutionPayloadV4(
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
    excessBlobGas: p.excessBlobGas.get(0.Quantity),
    depositReceipts: p.depositReceipts.get(newSeq[DepositReceiptV1]()),
    exits: p.exits.get(newSeq[WithdrawalRequestV1]())
  )

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
    withdrawals: some(p.withdrawals)
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
    withdrawals: some(p.withdrawals),
    blobGasUsed: some(p.blobGasUsed),
    excessBlobGas: some(p.excessBlobGas)
  )

func executionPayload*(p: ExecutionPayloadV4): ExecutionPayload =
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
    withdrawals: some(p.withdrawals),
    blobGasUsed: some(p.blobGasUsed),
    excessBlobGas: some(p.excessBlobGas),
    depositReceipts: some(p.depositReceipts),
    exits: some(p.exits)
  )

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

func V4*(res: GetPayloadResponse): GetPayloadV4Response =
  GetPayloadV4Response(
    executionPayload: res.executionPayload.V4,
    blockValue: res.blockValue.get,
    blobsBundle: res.blobsBundle.get(BlobsBundleV1()),
    shouldOverrideBuilder: res.shouldOverrideBuilder.get(false)
  )

func getPayloadResponse*(x: ExecutionPayloadV1): GetPayloadResponse =
  GetPayloadResponse(executionPayload: x.executionPayload)

func getPayloadResponse*(x: GetPayloadV2Response): GetPayloadResponse =
  GetPayloadResponse(
    executionPayload: x.executionPayload.executionPayload,
    blockValue: some(x.blockValue)
  )

func getPayloadResponse*(x: GetPayloadV3Response): GetPayloadResponse =
  GetPayloadResponse(
    executionPayload: x.executionPayload.executionPayload,
    blockValue: some(x.blockValue),
    blobsBundle: some(x.blobsBundle),
    shouldOverrideBuilder: some(x.shouldOverrideBuilder)
  )

func getPayloadResponse*(x: GetPayloadV4Response): GetPayloadResponse =
  GetPayloadResponse(
    executionPayload: x.executionPayload.executionPayload,
    blockValue: some(x.blockValue),
    blobsBundle: some(x.blobsBundle),
    shouldOverrideBuilder: some(x.shouldOverrideBuilder)
  )