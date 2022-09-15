import
  unittest, std/json,
  stint,
  ../web3/[conversions, ethtypes]

proc `==`(x, y: Quantity): bool {.borrow, noSideEffect.}

suite "JSON-RPC Quantity":
  test "Valid":
    for (validQuantityStr, validQuantity) in [
        ("0x0", 0),
        ("0x123", 291),
        ("0x1234", 4660)]:
      var resQuantity: Quantity
      var resUInt256: UInt256
      var resUInt256Ref: ref UInt256
      fromJson(%validQuantityStr, "", resQuantity)
      fromJson(%validQuantityStr, "", resUInt256)
      fromJson(%validQuantityStr, "", resUInt256Ref)
      check:
        resQuantity == validQuantity.Quantity
        resUInt256 == validQuantity.u256
        resUInt256Ref[] == validQuantity.u256

  test "Invalid Quantity/UInt256/ref UInt256":
    # TODO once https://github.com/status-im/nimbus-eth2/pull/3850 addressed,
    # re-add "0x0400" test case as invalid.
    for invalidStr in [
        "", "1234", "01234", "x1234", "0x", "ff"]:
      template checkInvalids(typeName: untyped) =
        var resQuantity: `typeName`
        try:
          fromJson(%invalidStr, "", resQuantity)
          echo `typeName`, invalidStr
          check: false
        except ValueError:
          check: true
        except CatchableError:
          check: false

      checkInvalids(Quantity)
      checkInvalids(UInt256)
      checkInvalids(ref UInt256)
