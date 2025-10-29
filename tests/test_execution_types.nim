# nim-web3
# Copyright (c) 2018-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/typetraits,
  pkg/unittest2,
  stew/byteutils,
  ../web3/execution_types,
  ./helpers/primitives_utils

suite "Execution types tests":
  let
    wd = WithdrawalV1(
      index: 1.Quantity,
      validatorIndex: 2.Quantity,
      address: address(3),
      amount: 4.Quantity,
    )

    payload = ExecutionPayload(
      parentHash: h256(1),
      feeRecipient: address(2),
      stateRoot: h256(3),
      receiptsRoot: h256(4),
      logsBloom: FixedBytes[256].conv(5),
      prevRandao: b32(6),
      blockNumber: 7.Quantity,
      gasLimit: 8.Quantity,
      gasUsed: 9.Quantity,
      timestamp: 10.Quantity,
      extraData: DynamicBytes[0, 32].conv(11),
      baseFeePerGas: 12.u256,
      blockHash: h256(13),
      transactions: @[TypedTransaction.conv(14)],
      withdrawals: Opt.some(@[wd]),
      blobGasUsed: Opt.some(15.Quantity),
      excessBlobGas: Opt.some(16.Quantity)
    )

    attr = PayloadAttributes(
      timestamp: 1.Quantity,
      prevRandao: b32(2),
      suggestedFeeRecipient: address(3),
      withdrawals: Opt.some(@[wd]),
      parentBeaconBlockRoot: Opt.some(h256(4)),
    )

    blobs = BlobsBundleV1(
      commitments: @[KzgCommitment.conv(1)],
      proofs: @[KzgProof.conv(2)],
      blobs: @[Blob.conv(3)],
    )

    response = GetPayloadResponse(
      executionPayload: payload,
      blockValue: Opt.some(1.u256),
      blobsBundle: Opt.some(blobs),
      shouldOverrideBuilder: Opt.some(false),
    )
  var
    payloadV4 = payload
    responseV6 = response
  payloadV4.blockAccessList = Opt.some(@[AccountChanges(address: default(Address))])
  responseV6.executionPayload = payloadV4
  responseV6.executionRequests =  Opt.some(@[@[0x1.byte, 0x2, 0x3]])

  test "payload version":
    var badv31 = payload
    badv31.blobGasUsed = Opt.none(Quantity)
    var badv32 = payload
    badv32.excessBlobGas = Opt.none(Quantity)
    var v2 = payload
    v2.blobGasUsed = Opt.none(Quantity)
    v2.excessBlobGas = Opt.none(Quantity)
    var v1 = v2
    v1.withdrawals = Opt.none(seq[WithdrawalV1])
    check badv31.version == Version.V3
    check badv32.version == Version.V3
    check v2.version == Version.V2
    check v1.version == Version.V1
    check payload.version == Version.V3

    let v31 = badv31.V3
    check v31.excessBlobGas == payload.excessBlobGas.get
    check v31.blobGasUsed == 0.Quantity

    let v32 = badv32.V3
    check v32.excessBlobGas == 0.Quantity
    check v32.blobGasUsed == payload.blobGasUsed.get

    check payloadV4.version == Version.V4

  test "attr version":
    var v2 = attr
    v2.parentBeaconBlockRoot = Opt.none(Hash32)
    var v1 = v2
    v1.withdrawals = Opt.none(seq[WithdrawalV1])
    check attr.version == Version.V3
    check v2.version == Version.V2
    check v1.version == Version.V1

  test "response version":
    var badv31 = response
    badv31.blobsBundle = Opt.none(BlobsBundleV1)
    var badv32 = response
    badv32.shouldOverrideBuilder = Opt.none(bool)
    var v2 = response
    v2.blobsBundle = Opt.none(BlobsBundleV1)
    v2.shouldOverrideBuilder = Opt.none(bool)
    var v1 = v2
    v1.blockValue = Opt.none(UInt256)
    check badv31.version == Version.V3
    check badv32.version == Version.V3
    check v2.version == Version.V2
    check v1.version == Version.V1
    check response.version == Version.V3

    let v31 = badv31.V3
    check v31.blobsBundle == BlobsBundleV1()
    check v31.shouldOverrideBuilder == response.shouldOverrideBuilder.get

    let v32 = badv32.V3
    check v32.blobsBundle == response.blobsBundle.get
    check v32.shouldOverrideBuilder == false

    check responseV6.version == Version.V6

  test "ExecutionPayload roundtrip":
    let v3 = payload.V3
    check v3 == v3.executionPayload.V3

    let v2 = payload.V2
    check v2 == v2.executionPayload.V2

    let v1 = payload.V1
    check v1 == v1.executionPayload.V1

  test "PayloadAttributes roundtrip":
    let v3 = attr.V3
    check v3 == v3.payloadAttributes.V3

    let v2 = attr.V2
    check v2 == v2.payloadAttributes.V2

    let v1 = attr.V1
    check v1 == v1.payloadAttributes.V1

  test "GetPayloadResponse roundtrip":
    let v3 = response.V3
    check v3 == v3.getPayloadResponse.V3

    let v2 = response.V2
    check v2 == v2.getPayloadResponse.V2

    let v1 = response.V1
    check v1 == v1.getPayloadResponse.V1
