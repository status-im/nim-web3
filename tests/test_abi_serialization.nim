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
  client: FixedBytes[20]
  provider: FixedBytes[20]
  cid: FixedBytes[32]
  size: uint64
  duration: uint64
  pricePerByte: UInt256
  r: FixedBytes[32]
  s: FixedBytes[32]
  v: uint8
  metadata: string

type StaticArrayContract = object
  a: uint8
  b: array[2, uint16]
  c: DynBytes

proc randomBytes[N: static int](): array[N, byte] =
  var a: array[N, byte]
  for b in a.mitems:
    b = rand(byte)
  a

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
      client: FixedBytes[20](randomBytes[20]()),
      provider: FixedBytes[20](randomBytes[20]()),
      cid: FixedBytes[32](randomBytes[32]()),
      size: 1024'u64,
      duration: 365'u64,
      pricePerByte: 1000.u256,
      r: FixedBytes[32](randomBytes[32]()),
      s: FixedBytes[32](randomBytes[32]()),
      v: rand(uint8),
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
    check decoded.r == deal.r
    check decoded.s == deal.s
    check decoded.v == deal.v
    check decoded.metadata == deal.metadata

  test "encode and decode type with static array":
    let x = StaticArrayContract(
      a: 1, b: [2'u16, 3'u16], c: DynBytes(@[4'u8]))

    let encoded = Abi.encode(x)
    check encoded == Abi.encode((x.a, x.b, x.c))

    let decoded = Abi.decode(encoded, StaticArrayContract)
    check decoded == x
