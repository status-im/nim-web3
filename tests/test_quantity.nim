import
  std/typetraits,
  unittest, std/json, json_serialization,
  stint,
  ../web3/[conversions, ethtypes]

proc `==`(x, y: Quantity): bool {.borrow, noSideEffect.}

suite "JSON-RPC Quantity":
  test "Valid":
    for (validQuantityStr, validQuantity) in [
        ("0x0", Quantity 0),
        ("0x123", Quantity 291),
        ("0x1234", Quantity 4660)]:
      let validQuantityJson = $(%validQuantityStr)
      var resQuantity: Quantity
      var resUInt256: UInt256
      var resUInt256Ref: ref UInt256
      fromJson(%validQuantityStr, "", resQuantity)
      fromJson(%validQuantityStr, "", resUInt256)
      fromJson(%validQuantityStr, "", resUInt256Ref)
      check:
        Json.decode(validQuantityJson, Quantity) == validQuantity
        Json.encode(validQuantity) == validQuantityJson
        resQuantity == validQuantity
        resUInt256 == validQuantity.distinctBase.u256
        resUInt256Ref[] == validQuantity.distinctBase.u256

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
