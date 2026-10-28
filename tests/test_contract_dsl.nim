# nim-web3
# Copyright (c) 2018-2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  pkg/unittest2,
  chronos,
  stew/byteutils,
  stint,
  ../web3,
  ../web3/encoding,
  ../web3/contract_dsl

type
  DummySender = object

func createMutableContractInvocation(s: DummySender, t: typedesc, data: seq[byte]): seq[byte] = data
func createImmutableContractInvocation(
    s: DummySender, t: typedesc, data: seq[byte]): seq[byte] = data
func createContractDeployment(s: DummySender, t: typedesc, data: seq[byte]): seq[byte] = data

func instantiateContract(t: typedesc): ContractInstance[t, DummySender] =
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
  proc g(a: seq[seq[UInt256]], b: seq[string])

contract(TestContractWithConstructor):
  proc init(someArg1, someArg2: UInt256) {.constructor.}

contract(TestContractWithoutConstructor):
  proc dummy()

contract(TestContractWithPragmaArguments):
  proc getBool(): bool {.foo: 1, bar(2), view.}

contract(TestContractWithExportMarker):
  proc getBool*(): bool

contract(TestContractWithQuotedName):
  proc `get$`(): bool

contract(TestContractWithParameterPragma):
  proc setBool(a {.foo.}: bool)

contract(TestContractWithQualifiedEventType):
  proc Stored(value: web3.FixedBytes[32]) {.event.}

template declareTemplateEvents() =
  contract(TestContractWithTemplateEvent):
    proc TemplateStored(value: indexed[web3.FixedBytes[32]]) {.event.}

declareTemplateEvents()

suite "Contract DSL":
  test "Function calls":
    let c = instantiateContract(TestContract)
    checkData(c.getBool(), "0x12a7b914")
    checkData(c.setBool(true), "0x1e26fd330000000000000000000000000000000000000000000000000000000000000001")
    checkData(c.setBool(false), "0x1e26fd330000000000000000000000000000000000000000000000000000000000000000")
    checkData(c.setString("hello"), "0x7fcaf6660000000000000000000000000000000000000000000000000000000000000020000000000000000000000000000000000000000000000000000000000000000568656c6c6f000000000000000000000000000000000000000000000000000000")

    # Example taken from https://docs.soliditylang.org/en/latest/abi-spec.html#use-of-dynamic-types
    checkData(c.g(@[@[1.u256, 2.u256], @[3.u256]], @["one", "two", "three"]), "0x2289b18c000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001400000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000000a0000000000000000000000000000000000000000000000000000000000000000200000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000030000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000006000000000000000000000000000000000000000000000000000000000000000a000000000000000000000000000000000000000000000000000000000000000e000000000000000000000000000000000000000000000000000000000000000036f6e650000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000374776f000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000057468726565000000000000000000000000000000000000000000000000000000")

  test "Constructors":
    let s = DummySender()
    let dummyContractCode = hexToSeqByte "0xDEADC0DE"
    checkData(s.deployContract(TestContractWithConstructor, dummyContractCode, 1.u256, 2.u256), "0xDEADC0DE00000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000000000002")
    checkData(s.deployContract(TestContractWithoutConstructor, dummyContractCode), "0xDEADC0DE")

  test "Pragmas with arguments":
    let c = instantiateContract(TestContractWithPragmaArguments)
    checkData(c.getBool(), "0x12a7b914")

  test "Export markers":
    let c = instantiateContract(TestContractWithExportMarker)
    checkData(c.getBool(), "0x12a7b914")

  test "Quoted names":
    let c = instantiateContract(TestContractWithQuotedName)
    checkData(c.`get$`(), "0x3e04788a")

  test "Parameter pragmas":
    let c = instantiateContract(TestContractWithParameterPragma)
    checkData(c.setBool(true), "0x1e26fd33" &
        "0000000000000000000000000000000000000000000000000000000000000001")

  test "Qualified event parameter types":
    check eventTopic(Stored).to0xHex ==
        "0x7e4295c947f81979a9d2366bc4f2edcfd2f59b4d21e7cff89868d3cd87393730"

  test "Indexed event parameters in templates":
    check eventTopic(TemplateStored).to0xHex ==
        "0xd4e5c243a557315eb4af280c711a188025f227e9806c8007b285534bebec50b4"
