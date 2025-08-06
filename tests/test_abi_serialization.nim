import
    std/unittest,
    serialization,
    ../web3/encoding,
    ../web3/decoding,
    ../web3/eth_api_types,
    ../web3/abi_serialization,
    ./helpers/primitives_utils

type Contract = object
  a: uint64
  b {.dontSerialize.}: string
  c: bool
  d: string

suite "ABI serialization":
  test "encode and decode custom type":
    let x = Contract(a: 1, b: "SECRET", c: true, d: "hello")

    let encoded = Abi.encode(x)
    check encoded == Abi.encode((x.a, x.c, x.d))

    let decoded = Abi.decode(encoded, Contract)
    check decoded.a == x.a
    check decoded.b == ""
    check decoded.c == x.c
    check decoded.d == x.d