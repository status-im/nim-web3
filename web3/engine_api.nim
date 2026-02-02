# nim-web3
# Copyright (c) 2022-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  json_rpc/client,
  ./conversions,
  ./engine_api_types,
  ./execution_types

export
  engine_api_types,
  conversions,
  execution_types

createRpcSigsFromNim(RpcClient):
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.3/src/engine/paris.md#methods
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.3/src/engine/shanghai.md#methods
  # https://github.com/ethereum/execution-apis/blob/ee3df5bc38f28ef35385cefc9d9ca18d5e502778/src/engine/cancun.md#methods
  # https://github.com/ethereum/execution-apis/tree/v1.0.0-beta.4/src/engine/openrpc/methods

  proc engine_newPayloadV1(payload: ExecutionPayloadV1): PayloadStatusV1
  proc engine_newPayloadV2(payload: ExecutionPayloadV2): PayloadStatusV1
  proc engine_newPayloadV3(payload: ExecutionPayloadV3, expectedBlobVersionedHashes: seq[VersionedHash], parentBeaconBlockRoot: Hash32): PayloadStatusV1
  proc engine_newPayloadV4(payload: ExecutionPayloadV3, expectedBlobVersionedHashes: seq[VersionedHash], parentBeaconBlockRoot: Hash32, executionRequests: seq[seq[byte]]): PayloadStatusV1
  proc engine_newPayloadV5(payload: ExecutionPayloadV4, expectedBlobVersionedHashes: seq[VersionedHash], parentBeaconBlockRoot: Hash32, executionRequests: seq[seq[byte]]): PayloadStatusV1
  proc engine_forkchoiceUpdatedV1(forkchoiceState: ForkchoiceStateV1, payloadAttributes: Opt[PayloadAttributesV1]): ForkchoiceUpdatedResponse
  proc engine_forkchoiceUpdatedV2(forkchoiceState: ForkchoiceStateV1, payloadAttributes: Opt[PayloadAttributesV2]): ForkchoiceUpdatedResponse
  proc engine_forkchoiceUpdatedV3(forkchoiceState: ForkchoiceStateV1, payloadAttributes: Opt[PayloadAttributesV3]): ForkchoiceUpdatedResponse
  proc engine_forkchoiceUpdatedV4(forkchoiceState: ForkchoiceStateV1, payloadAttributes: Opt[PayloadAttributesV4]): ForkchoiceUpdatedResponse
  proc engine_getPayloadV1(payloadId: Bytes8): ExecutionPayloadV1
  proc engine_getPayloadV2(payloadId: Bytes8): GetPayloadV2Response
  proc engine_getPayloadV2_exact(payloadId: Bytes8): GetPayloadV2ResponseExact
  proc engine_getPayloadV3(payloadId: Bytes8): GetPayloadV3Response
  proc engine_getPayloadV4(payloadId: Bytes8): GetPayloadV4Response
  proc engine_getPayloadV5(payloadId: Bytes8): GetPayloadV5Response
  proc engine_getPayloadV6(payloadId: Bytes8): GetPayloadV6Response
  proc engine_getPayloadBodiesByHashV1(hashes: seq[Hash32]): seq[Opt[ExecutionPayloadBodyV1]]
  proc engine_getPayloadBodiesByRangeV1(start: Quantity, count: Quantity): seq[Opt[ExecutionPayloadBodyV1]]
  proc engine_getBlobsV1(blob_versioned_hashes: seq[VersionedHash]): GetBlobsV1Response
  proc engine_getBlobsV2(blob_versioned_hashes: seq[VersionedHash]): GetBlobsV2Response
  proc engine_getBlobsV3(blob_versioned_hashes: seq[VersionedHash]): GetBlobsV3Response

  # https://github.com/ethereum/execution-apis/blob/9301c0697e4c7566f0929147112f6d91f65180f6/src/engine/common.md
  proc engine_exchangeCapabilities(methods: seq[string]): seq[string]

  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.4/src/engine/identification.md#engine_getclientversionv1
  proc engine_getClientVersionV1(version: ClientVersionV1): seq[ClientVersionV1]

  # convenience apis
  proc engine_newPayloadV1(payload: ExecutionPayload): PayloadStatusV1
  proc engine_newPayloadV2(payload: ExecutionPayload): PayloadStatusV1
  proc engine_newPayloadV2(payload: ExecutionPayloadV1OrV2): PayloadStatusV1
  proc engine_newPayloadV3(payload: ExecutionPayload,
    expectedBlobVersionedHashes: Opt[seq[VersionedHash]],
    parentBeaconBlockRoot: Opt[Hash32]): PayloadStatusV1
  proc engine_newPayloadV4(payload: ExecutionPayload,
    expectedBlobVersionedHashes: Opt[seq[VersionedHash]],
    parentBeaconBlockRoot: Opt[Hash32],
    executionRequests: Opt[seq[seq[byte]]]): PayloadStatusV1
  proc engine_newPayloadV5(payload: ExecutionPayload,
    expectedBlobVersionedHashes: Opt[seq[VersionedHash]],
    parentBeaconBlockRoot: Opt[Hash32],
    executionRequests: Opt[seq[seq[byte]]]): PayloadStatusV1
  proc engine_forkchoiceUpdatedV2(forkchoiceState: ForkchoiceStateV1, payloadAttributes: Opt[PayloadAttributes]): ForkchoiceUpdatedResponse
  proc engine_forkchoiceUpdatedV3(forkchoiceState: ForkchoiceStateV1, payloadAttributes: Opt[PayloadAttributes]): ForkchoiceUpdatedResponse

template forkchoiceUpdated*(
    rpcClient: RpcClient,
    forkchoiceState: ForkchoiceStateV1,
    payloadAttributes: Opt[PayloadAttributesV1]): Future[ForkchoiceUpdatedResponse] =
  engine_forkchoiceUpdatedV1(rpcClient, forkchoiceState, payloadAttributes)

template forkchoiceUpdated*(
    rpcClient: RpcClient,
    forkchoiceState: ForkchoiceStateV1,
    payloadAttributes: Opt[PayloadAttributesV2]): Future[ForkchoiceUpdatedResponse] =
  engine_forkchoiceUpdatedV2(rpcClient, forkchoiceState, payloadAttributes)

template forkchoiceUpdated*(
    rpcClient: RpcClient,
    forkchoiceState: ForkchoiceStateV1,
    payloadAttributes: Opt[PayloadAttributesV3]): Future[ForkchoiceUpdatedResponse] =
  engine_forkchoiceUpdatedV3(rpcClient, forkchoiceState, payloadAttributes)

template forkchoiceUpdated*(
    rpcClient: RpcClient,
    forkchoiceState: ForkchoiceStateV1,
    payloadAttributes: Opt[PayloadAttributesV4]): Future[ForkchoiceUpdatedResponse] =
  engine_forkchoiceUpdatedV4(rpcClient, forkchoiceState, payloadAttributes)

template getPayload*(
    rpcClient: RpcClient,
    T: type ExecutionPayloadV1,
    payloadId: Bytes8): Future[ExecutionPayloadV1] =
  engine_getPayloadV1(rpcClient, payloadId)

template getPayload*(
    rpcClient: RpcClient,
    T: type GetPayloadV2Response,
    payloadId: Bytes8): Future[GetPayloadV2Response] =
  engine_getPayloadV2(rpcClient, payloadId)

template getPayload*(
    rpcClient: RpcClient,
    T: type GetPayloadV2ResponseExact,
    payloadId: Bytes8): Future[GetPayloadV2ResponseExact] =
  engine_getPayloadV2_exact(rpcClient, payloadId)

template getPayload*(
    rpcClient: RpcClient,
    T: type GetPayloadV3Response,
    payloadId: Bytes8): Future[GetPayloadV3Response] =
  engine_getPayloadV3(rpcClient, payloadId)

template getPayload*(
    rpcClient: RpcClient,
    T: type GetPayloadV4Response,
    payloadId: Bytes8): Future[GetPayloadV4Response] =
  engine_getPayloadV4(rpcClient, payloadId)

template getPayload*(
    rpcClient: RpcClient,
    T: type GetPayloadV5Response,
    payloadId: Bytes8): Future[GetPayloadV5Response] =
  engine_getPayloadV5(rpcClient, payloadId)

template getPayload*(
    rpcClient: RpcClient,
    T: type GetPayloadV6Response,
    payloadId: Bytes8): Future[GetPayloadV6Response] =
  engine_getPayloadV6(rpcClient, payloadId)

template getBlobs*(
    rpcClient: RpcClient,
    T: type GetBlobsV1Response,
    blob_versioned_hashes: seq[VersionedHash]):
    Future[GetBlobsV1Response] =
  engine_getBlobsV1(rpcClient, blob_versioned_hashes)

template getBlobs*(
    rpcClient: RpcClient,
    T: type GetBlobsV2Response,
    blob_versioned_hashes: seq[VersionedHash]):
    Future[GetBlobsV2Response] =
  engine_getBlobsV2(rpcClient, blob_versioned_hashes)

template newPayload*(
    rpcClient: RpcClient,
    payload: ExecutionPayloadV1): Future[PayloadStatusV1] =
  engine_newPayloadV1(rpcClient, payload)

template newPayload*(
    rpcClient: RpcClient,
    payload: ExecutionPayloadV2): Future[PayloadStatusV1] =
  engine_newPayloadV2(rpcClient, payload)

template newPayload*(
    rpcClient: RpcClient,
    payload: ExecutionPayloadV3,
    versionedHashes: seq[VersionedHash],
    parentBeaconBlockRoot: Hash32): Future[PayloadStatusV1] =
  engine_newPayloadV3(
    rpcClient, payload, versionedHashes, parentBeaconBlockRoot)

template newPayload*(
    rpcClient: RpcClient,
    payload: ExecutionPayloadV3,
    versionedHashes: seq[VersionedHash],
    parentBeaconBlockRoot: Hash32,
    executionRequests: seq[seq[byte]]): Future[PayloadStatusV1] =
  engine_newPayloadV4(
    rpcClient, payload, versionedHashes, parentBeaconBlockRoot, executionRequests)

template exchangeCapabilities*(
    rpcClient: RpcClient,
    methods: seq[string]): Future[seq[string]] =
  engine_exchangeCapabilities(rpcClient, methods)

template getClientVersion*(
    rpcClient: RpcClient,
    version: ClientVersionV1): Future[seq[ClientVersionV1]] =
  engine_getClientVersionV1(rpcClient, version)
