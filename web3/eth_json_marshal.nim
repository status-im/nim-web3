# nim-web3
# Copyright (c) 2019-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push gcsafe, raises: [].}

import json_serialization

export json_serialization

createJsonFlavor EthJson,
  automaticObjectSerialization = false,
  requireAllFields = false,
  omitOptionalFields = false, # Don't skip optional fields==none in Writer
  allowUnknownFields = true,
  skipNullFields = true,      # Skip optional fields==null in Reader
  automaticPrimitivesSerialization = false

EthJson.automaticSerialization(JsonNode, true)
