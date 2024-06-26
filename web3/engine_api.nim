# nim-web3
# Copyright (c) 2022-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  json_serialization/stew/results,
  serialization/errors,
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

  proc engine_newPayloadV1(payload: ExecutionPayloadV1): PayloadStatusV1
  proc engine_newPayloadV2(payload: ExecutionPayloadV2): PayloadStatusV1
  proc engine_newPayloadV3(payload: ExecutionPayloadV3, expectedBlobVersionedHashes: seq[VersionedHash], parentBeaconBlockRoot: FixedBytes[32]): PayloadStatusV1
  proc engine_newPayloadV4(payload: ExecutionPayloadV4, expectedBlobVersionedHashes: seq[VersionedHash], parentBeaconBlockRoot: FixedBytes[32]): PayloadStatusV1
  proc engine_forkchoiceUpdatedV1(forkchoiceState: ForkchoiceStateV1, payloadAttributes: Opt[PayloadAttributesV1]): ForkchoiceUpdatedResponse
  proc engine_forkchoiceUpdatedV2(forkchoiceState: ForkchoiceStateV1, payloadAttributes: Opt[PayloadAttributesV2]): ForkchoiceUpdatedResponse
  proc engine_forkchoiceUpdatedV3(forkchoiceState: ForkchoiceStateV1, payloadAttributes: Opt[PayloadAttributesV3]): ForkchoiceUpdatedResponse
  proc engine_getPayloadV1(payloadId: PayloadID): ExecutionPayloadV1
  proc engine_getPayloadV2(payloadId: PayloadID): GetPayloadV2Response
  proc engine_getPayloadV2_exact(payloadId: PayloadID): GetPayloadV2ResponseExact
  proc engine_getPayloadV3(payloadId: PayloadID): GetPayloadV3Response
  proc engine_getPayloadV4(payloadId: PayloadID): GetPayloadV4Response
  proc engine_exchangeTransitionConfigurationV1(transitionConfiguration: TransitionConfigurationV1): TransitionConfigurationV1
  proc engine_getPayloadBodiesByHashV1(hashes: seq[BlockHash]): seq[Opt[ExecutionPayloadBodyV1]]
  proc engine_getPayloadBodiesByRangeV1(start: Quantity, count: Quantity): seq[Opt[ExecutionPayloadBodyV1]]

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
    parentBeaconBlockRoot: Opt[FixedBytes[32]]): PayloadStatusV1
  proc engine_newPayloadV4(payload: ExecutionPayload,
    expectedBlobVersionedHashes: Opt[seq[VersionedHash]],
    parentBeaconBlockRoot: Opt[FixedBytes[32]]): PayloadStatusV1
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

template getPayload*(
    rpcClient: RpcClient,
    T: type ExecutionPayloadV1,
    payloadId: PayloadID): Future[ExecutionPayloadV1] =
  engine_getPayloadV1(rpcClient, payloadId)

template getPayload*(
    rpcClient: RpcClient,
    T: type GetPayloadV2Response,
    payloadId: PayloadID): Future[GetPayloadV2Response] =
  engine_getPayloadV2(rpcClient, payloadId)

template getPayload*(
    rpcClient: RpcClient,
    T: type GetPayloadV2ResponseExact,
    payloadId: PayloadID): Future[GetPayloadV2ResponseExact] =
  engine_getPayloadV2_exact(rpcClient, payloadId)

template getPayload*(
    rpcClient: RpcClient,
    T: type GetPayloadV3Response,
    payloadId: PayloadID): Future[GetPayloadV3Response] =
  engine_getPayloadV3(rpcClient, payloadId)

template getPayload*(
    rpcClient: RpcClient,
    T: type GetPayloadV4Response,
    payloadId: PayloadID): Future[GetPayloadV4Response] =
  engine_getPayloadV4(rpcClient, payloadId)

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
    parentBeaconBlockRoot: FixedBytes[32]): Future[PayloadStatusV1] =
  engine_newPayloadV3(
    rpcClient, payload, versionedHashes, parentBeaconBlockRoot)

template newPayload*(
    rpcClient: RpcClient,
    payload: ExecutionPayloadV4,
    versionedHashes: seq[VersionedHash],
    parentBeaconBlockRoot: FixedBytes[32]): Future[PayloadStatusV1] =
  engine_newPayloadV4(
    rpcClient, payload, versionedHashes, parentBeaconBlockRoot)

template exchangeCapabilities*(
    rpcClient: RpcClient,
    methods: seq[string]): Future[seq[string]] =
  engine_exchangeCapabilities(rpcClient, methods)

template getClientVersion*(
    rpcClient: RpcClient,
    version: ClientVersionV1): Future[seq[ClientVersionV1]] =
  engine_getClientVersionV1(rpcClient, version)
