import os
import macros
import std/json
import pkg/unittest2
import stint
import ../web3
import ../web3/[conversions, ethtypes]

proc `==`(x, y: Address): bool {.borrow, noSideEffect.}
proc `==`(x, y: Quantity): bool {.borrow, noSideEffect.}

suite "Deposit contract":
  test "deposits with nully values":
    for jsonExample in parseFile(getAppDir() & "/test_deposits.json"):
      discard $jsonExample

  test "passing nully values to normal convertors":
    var resAddress: Address
    var resFixedBytes: FixedBytes[5]
    var resQuantity: Quantity
    var resRlpEncodedBytes: RlpEncodedBytes
    var resTypedTransaction: TypedTransaction
    var resUInt256: UInt256
    var resUInt256Ref: ref UInt256

    # TODO: @tavurth
    # var resDynamicBytes: DynamicBytes
    # check_type("null", resDynamicBytes)

    template should_be_value_error(input: string, value: untyped): void =
      expect ValueError:
        fromJson(%input, "", value)

      # Nully values
    should_be_value_error("null", resAddress)
    should_be_value_error("null", resAddress)
    should_be_value_error("null", resFixedBytes)
    should_be_value_error("null", resQuantity)
    should_be_value_error("null", resRlpEncodedBytes)
    should_be_value_error("null", resTypedTransaction)
    should_be_value_error("null", resUInt256)
    should_be_value_error("null", resUInt256Ref)

      # Empty values
    should_be_value_error("", resAddress)
    should_be_value_error("", resFixedBytes)
    should_be_value_error("", resQuantity)
    should_be_value_error("", resRlpEncodedBytes)
    should_be_value_error("", resTypedTransaction)
    should_be_value_error("", resUInt256)
    should_be_value_error("", resUInt256Ref)

      # Empty hex values
    should_be_value_error("0x", resAddress)
    should_be_value_error("0x", resFixedBytes)
    should_be_value_error("0x", resQuantity)
    should_be_value_error("0x", resRlpEncodedBytes)
    should_be_value_error("0x", resTypedTransaction)
    should_be_value_error("0x", resUInt256)
    should_be_value_error("0x", resUInt256Ref)
