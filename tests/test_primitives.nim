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
  ../web3/primitives,
  ./helpers/primitives_utils

suite "Primitives":
  const
    addr1 = address(1)
    txhash1 = txhash(1)
    blob1 = blob(1)

    addr2 = address(2)
    txhash2 = txhash(2)
    blob2 = blob(2)

  test "Comparators":
    check addr1 == addr1
    check addr1 != addr2

    check txhash1 == txhash1
    check txhash1 != txhash2

    check blob1 == blob1
    check blob1 != blob2

  test "toHex":
    check addr1.toHex == "0000000000000000000000000000000000000001"
    check addr2.toHex == "0000000000000000000000000000000000000002"

    check txhash1.toHex == "0000000000000000000000000000000000000000000000000000000000000001"
    check txhash2.toHex == "0000000000000000000000000000000000000000000000000000000000000002"

    check blob1.toHex == "01"
    check blob2.toHex == "02"

  test "fromHex":
    let
      addr3 = Address.fromHex("0000000000000000000000000000000000000123")
      txhash3 = Hash32.fromHex("0000000000000000000000000000000000000000000000000000000000000456")
      blob3 = BlobData.fromHex("7890")

    check addr3.toHex == "0000000000000000000000000000000000000123"
    check txhash3.toHex == "0000000000000000000000000000000000000000000000000000000000000456"
    check blob3.toHex == "7890"

  test "to bytes":
    let
      ab2 = addr2.bytes
      tb2 = txhash2.bytes
      bb2 = blob2.bytes

    check ab2.toHex == "0000000000000000000000000000000000000002"
    check tb2.toHex == "0000000000000000000000000000000000000000000000000000000000000002"
    check bb2.toHex == "02"

  test "len":
    check addr1.len == 20
    check txhash1.len == 32
    check blob1.len == 1

  test "dollar":
    check $addr1 == "0x0000000000000000000000000000000000000001"
    check $txhash1 == "0x0000000000000000000000000000000000000000000000000000000000000001"
    check $blob1 == "0x01"
