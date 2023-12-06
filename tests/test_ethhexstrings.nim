# nim-web3
# Copyright (c) 2018-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  unittest2, json,
  ../web3/ethhexstrings

suite "Hex quantity":
  test "Empty string":
    expect ValueError:
      let
        source = ""
        x = hexQuantityStr source
      check %x == %source
  test "Even length":
    let
      source = "0x123"
      x = hexQuantityStr source
    check %x == %source
  test "Odd length":
    let
      source = "0x123"
      x = hexQuantityStr"0x123"
    check %x == %source
  test "Missing header":
    expect ValueError:
      let
        source = "1234"
        x = hexQuantityStr source
      check %x != %source
    expect ValueError:
      let
        source = "01234"
        x = hexQuantityStr source
      check %x != %source
    expect ValueError:
      let
        source = "x1234"
        x = hexQuantityStr source
      check %x != %source
  test "Hex encoded 0x0":
    let
      source = "0x0"
      x = hexQuantityStr"0x0"
    check %x == %source

suite "Hex data":
  test "Even length":
    let
      source = "0x1234"
      x = hexDataStr source
    check %x == %source
  test "Empty data":
    let
      source = "0x"
      x = hexDataStr source
    check %x == %source
  test "Odd length":
    expect ValueError:
      let
        source = "0x123"
        x = hexDataStr source
      check %x != %source
  test "Missing header":
    expect ValueError:
      let
        source = "1234"
        x = hexDataStr source
      check %x != %source
    expect ValueError:
      let
        source = "01234"
        x = hexDataStr source
      check %x != %source
    expect ValueError:
      let
        source = "x1234"
        x = hexDataStr source
      check %x != %source

