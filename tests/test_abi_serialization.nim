import
    std/unittest,
    serialization,
    std/random,
    ../web3/encoding,
    ../web3/decoding,
    ../web3/eth_api_types,
    ../web3/abi_serialization

type Contract = object
  a: uint64
  b {.dontSerialize.}: string
  c: bool
  d: string

type StorageDeal = object
  client: array[20, byte]
  provider: array[20, byte]
  cid: array[32, byte]
  size: uint64
  duration: uint64
  pricePerByte: UInt256
  signature: array[65, byte]
  metadata: string

proc randomBytes[N: static int](): array[N, byte] =
  var a: array[N, byte]
  for b in a.mitems:
      b = rand(byte)
  return a

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

  test "encode and decode complex type":
    let deal = StorageDeal(
      client: randomBytes[20](),
      provider: randomBytes[20](),
      cid: randomBytes[32](),
      size: 1024'u64,
      duration: 365'u64,
      pricePerByte: 1000.u256,
      signature: randomBytes[65](),
      metadata: "Sample metadata for storage deal"
    )

    let encoded = Abi.encode(deal)
    let decoded = Abi.decode(encoded, StorageDeal)

    check decoded.client == deal.client
    check decoded.provider == deal.provider
    check decoded.cid == deal.cid
    check decoded.size == deal.size
    check decoded.duration == deal.duration
    check decoded.pricePerByte == deal.pricePerByte
    check decoded.signature == deal.signature
    check decoded.metadata == deal.metadata