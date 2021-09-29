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

