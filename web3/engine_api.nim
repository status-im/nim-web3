import
  strutils,
  json_serialization/std/[sets, net], serialization/errors,
  json_rpc/[client, jsonmarshal],
  conversions, engine_api_types

export
  engine_api_types, conversions

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
