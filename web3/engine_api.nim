# nim-web3
# Copyright (c) 2022-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  strutils,
  json_serialization/std/[sets, net], serialization/errors,
  json_rpc/[client, jsonmarshal],
  ./conversions,
  ./engine_api_types,
  ./execution_types

export
  engine_api_types,
  conversions,
  execution_types

from os import DirSep, AltSep
template sourceDir: string = currentSourcePath.rsplit({DirSep, AltSep}, 1)[0]

createRpcSigs(RpcClient, sourceDir & "/engine_api_callsigs.nim")

template forkchoiceUpdated*(
    rpcClient: RpcClient,
    forkchoiceState: ForkchoiceStateV1,
    payloadAttributes: Option[PayloadAttributesV1]): Future[ForkchoiceUpdatedResponse] =
  engine_forkchoiceUpdatedV1(rpcClient, forkchoiceState, payloadAttributes)

template forkchoiceUpdated*(
    rpcClient: RpcClient,
    forkchoiceState: ForkchoiceStateV1,
    payloadAttributes: Option[PayloadAttributesV2]): Future[ForkchoiceUpdatedResponse] =
  engine_forkchoiceUpdatedV2(rpcClient, forkchoiceState, payloadAttributes)

template forkchoiceUpdated*(
    rpcClient: RpcClient,
    forkchoiceState: ForkchoiceStateV1,
    payloadAttributes: Option[PayloadAttributesV3]): Future[ForkchoiceUpdatedResponse] =
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

template exchangeCapabilities*(
    rpcClient: RpcClient,
    methods: seq[string]): Future[seq[string]] =
  engine_exchangeCapabilities(rpcClient, methods)
