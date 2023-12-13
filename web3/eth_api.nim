# nim-web3
# Copyright (c) 2019-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE) or
#    http://www.apache.org/licenses/LICENSE-2.0)
#  * MIT license ([LICENSE-MIT](LICENSE-MIT) or
#    http://opensource.org/licenses/MIT)
# at your option. This file may not be copied, modified, or distributed except
# according to those terms.

import
  strutils,
  json_serialization/std/[sets, net],
  json_rpc/[client, jsonmarshal],
  stint,
  ./conversions,
  ./eth_api_types

export
  eth_api_types,
  conversions

from os import DirSep, AltSep
template sourceDir: string = currentSourcePath.rsplit({DirSep, AltSep}, 1)[0]

createRpcSigs(RpcClient, sourceDir & "/eth_api_callsigs.nim")
