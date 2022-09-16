import os
import macros
import std/json
import pkg/unittest2
import stint
import ../web3
import ../web3/[conversions, ethtypes]

proc `==`(x, y: Quantity): bool {.borrow, noSideEffect.}

suite "Deposit contract":
  test "deposits with nully values":
    for jsonExample in parseFile(getAppDir() & "/test_deposits.json"):
      discard $jsonExample

  test "passing nully values to normal convertors":
    var resAddress: Address
    var resDynamicBytes: DynamicBytes
    var resFixedBytes: FixedBytes[5]
    var resQuantity: Quantity
    var resRlpEncodedBytes: RlpEncodedBytes
    var resTypedTransaction: TypedTransaction
    var resUInt256: UInt256
    var resUInt256Ref: ref UInt256

    expect ValueError:
      fromJson("%null", resAddress)
      fromJson("%null", resDynamicBytes)
      fromJson("%null", resFixedBytes)
      fromJson("%null", resQuantity)
      fromJson("%null", resRlpEncodedBytes)
      fromJson("%null", resTypedTransaction)
      fromJson("%null", resUInt256)
      fromJson("%null", resUInt256Ref)
