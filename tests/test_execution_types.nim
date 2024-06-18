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
      prevRandao: h256(6),
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
      excessBlobGas: Opt.some(16.Quantity),
    )

    attr = PayloadAttributes(
      timestamp: 1.Quantity,
      prevRandao: h256(2),
      suggestedFeeRecipient: address(3),
      withdrawals: Opt.some(@[wd]),
      parentBeaconBlockRoot: Opt.some(h256(4)),
    )

    blobs = BlobsBundleV1(
      commitments: @[KZGCommitment.conv(1)],
      proofs: @[KZGProof.conv(2)],
      blobs: @[Blob.conv(3)],
    )

    response = GetPayloadResponse(
      executionPayload: payload,
      blockValue: Opt.some(1.u256),
      blobsBundle: Opt.some(blobs),
      shouldOverrideBuilder: Opt.some(false),
    )

    deposit = DepositRequestV1(
      pubkey: FixedBytes[48].conv(1),
      withdrawalCredentials: FixedBytes[32].conv(3),
      amount: 5.Quantity,
      signature: FixedBytes[96].conv(7),
      index: 9.Quantity
    )

    withdrawal = WithdrawalRequestV1(
      sourceAddress: address(7),
      validatorPublicKey: FixedBytes[48].conv(9)
    )

    consolidation = ConsolidationRequestV1(
      sourceAddress: address(8),
      sourcePubkey: FixedBytes[48].conv(10),
      targetPubkey: FixedBytes[48].conv(11)
    )

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


  test "attr version":
    var v2 = attr
    v2.parentBeaconBlockRoot = Opt.none(Hash256)
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

  test "payload version 4":
    var v4 = payload
    v4.depositRequests = Opt.some(@[deposit])
    v4.withdrawalRequests  = Opt.some(@[withdrawal])
    v4.consolidationRequests = Opt.some(@[consolidation])
    check v4.version == Version.V4

    var bad41 = v4
    bad41.depositRequests = Opt.none(seq[DepositRequestV1])
    check bad41.version == Version.V4

    var bad42 = v4
    bad42.withdrawalRequests  = Opt.none(seq[WithdrawalRequestV1])
    check bad42.version == Version.V4

    var bad43 = v4
    bad43.consolidationRequests  = Opt.none(seq[ConsolidationRequestV1])
    check bad43.version == Version.V4

    let v41 = bad41.V4
    check v41.depositRequests == newSeq[DepositRequestV1]()
    check v41.withdrawalRequests == v4.withdrawalRequests.get
    check v41.consolidationRequests == v4.consolidationRequests.get

    let v42 = bad42.V4
    check v42.depositRequests == v4.depositRequests.get
    check v42.withdrawalRequests == newSeq[WithdrawalRequestV1]()
    check v41.consolidationRequests == v4.consolidationRequests.get

    let v43 = bad43.V4
    check v43.depositRequests == v4.depositRequests.get
    check v43.withdrawalRequests == v4.withdrawalRequests.get
    check v43.consolidationRequests == newSeq[ConsolidationRequestV1]()

    # roundtrip
    let v4p = v4.V4
    check v4p == v4p.executionPayload.V4

    # response version 4
    var resv4 = response
    resv4.executionPayload = v4
    check resv4.version == Version.V4

    # response roundtrip
    let rv3p = resv4.V4
    check rv3p == rv3p.getPayloadResponse.V4