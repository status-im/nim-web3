# nim-web3
# Copyright (c) 2018-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  pkg/unittest2,
  stew/byteutils,
  stint,
  ../web3/contract_dsl

type
  DummySender = object

proc createMutableContractInvocation(s: DummySender, t: typedesc, data: seq[byte]): seq[byte] = data
proc createImmutableContractInvocation(s: DummySender, t: typedesc, data: seq[byte]): seq[byte] = data
proc createContractDeployment(s: DummySender, t: typedesc, data: seq[byte]): seq[byte] = data

proc instantiateContract(t: typedesc): ContractInstance[t, DummySender] =
  discard

proc checkData(a: seq[byte], expectedData: string) =
  let b = hexToSeqByte(expectedData)
  if a != b:
    echo "actual: ", a.to0xHex()
    echo "expect: ", b.to0xHex()
  doAssert(a == b)

contract(TestContract):
  proc getBool(): bool
  proc setBool(a: bool)
  proc setString(a: string)

contract(TestContractWithConstructor):
  proc init(someArg1, someArg2: UInt256) {.constructor.}

contract(TestContractWithoutConstructor):
  proc dummy()

suite "Contract DSL":
  test "Function calls":
    let c = instantiateContract(TestContract)
    checkData(c.getBool(), "0x12a7b914")
    checkData(c.setBool(true), "0x1e26fd330000000000000000000000000000000000000000000000000000000000000001")
    checkData(c.setBool(false), "0x1e26fd330000000000000000000000000000000000000000000000000000000000000000")
    checkData(c.setString("hello"), "0x7fcaf6660000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000568656c6c6f0000000000")

  test "Constructors":
    let s = DummySender()
    let dummyContractCode = hexToSeqByte "0xDEADC0DE"
    checkData(s.deployContract(TestContractWithConstructor, dummyContractCode, 1.u256, 2.u256), "0xDEADC0DE00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002")
    checkData(s.deployContract(TestContractWithoutConstructor, dummyContractCode), "0xDEADC0DE")
