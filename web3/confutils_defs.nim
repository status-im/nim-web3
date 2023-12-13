# nim-web3
# Copyright (c) 2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [].}

import
  ./primitives

func parseCmdArg*(T: type Address, input: string): T
                 {.raises: [ValueError].} =
  fromHex(T, string input)

func completeCmdArg*(T: type Address, input: string): seq[string] =
  @[]

func parseCmdArg*(T: type BlockHash, input: string): T
                 {.raises: [ValueError].} =
  fromHex(T, string input)

func completeCmdArg*(T: type BlockHash, input: string): seq[string] =
  @[]
