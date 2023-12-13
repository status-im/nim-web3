# nim-web3
# Copyright (c) 2018-2023 Status Research & Development GmbH
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
  ./helpers/utils

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
      prevRandao: h256(6),
      blockNumber: 7.Quantity,
      gasLimit: 8.Quantity,
      gasUsed: 9.Quantity,
      timestamp: 10.Quantity,
      extraData: DynamicBytes[0, 32].conv(11),
      baseFeePerGas: 12.u256,
      blockHash: h256(13),
      transactions: @[TypedTransaction.conv(14)],
      withdrawals: some(@[wd]),
      blobGasUsed: some(15.Quantity),
      excessBlobGas: some(16.Quantity),
    )

    attr = PayloadAttributes(
      timestamp: 1.Quantity,
      prevRandao: h256(2),
      suggestedFeeRecipient: address(3),
      withdrawals: some(@[wd]),
      parentBeaconBlockRoot: some(h256(4)),
    )

    blobs = BlobsBundleV1(
      commitments: @[KZGCommitment.conv(1)],
      proofs: @[KZGProof.conv(2)],
      blobs: @[Blob.conv(3)],
    )

    response = GetPayloadResponse(
      executionPayload: payload,
      blockValue: some(1.u256),
      blobsBundle: some(blobs),
      shouldOverrideBuilder: some(false),
    )

  test "payload version":
    var badv31 = payload
    badv31.excessBlobGas = none(Quantity)
    var badv32 = payload
    badv32.blobGasUsed = none(Quantity)
    var v2 = payload
    v2.excessBlobGas = none(Quantity)
    v2.blobGasUsed = none(Quantity)
    var v1 = v2
    v1.withdrawals = none(seq[WithdrawalV1])
    check badv31.version == Version.V2
    check badv32.version == Version.V2
    check v2.version == Version.V2
    check v1.version == Version.V1
    check payload.version == Version.V3

  test "attr version":
    var v2 = attr
    v2.parentBeaconBlockRoot = none(Hash256)
    var v1 = v2
    v1.withdrawals = none(seq[WithdrawalV1])
    check attr.version == Version.V3
    check v2.version == Version.V2
    check v1.version == Version.V1

  test "response version":
    var badv31 = response
    badv31.blobsBundle = none(BlobsBundleV1)
    var badv32 = response
    badv32.shouldOverrideBuilder = none(bool)
    var v2 = response
    v2.blobsBundle = none(BlobsBundleV1)
    v2.shouldOverrideBuilder = none(bool)
    var v1 = v2
    v1.blockValue = none(UInt256)
    check badv31.version == Version.V2
    check badv32.version == Version.V2
    check v2.version == Version.V2
    check v1.version == Version.V1
    check response.version == Version.V3

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

