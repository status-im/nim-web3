import
  std/[unittest, random],
  stew/[endians2],
  stint,
  ../web3/eth_api_types,
  ../web3/decoding,
  ../web3/encoding,
  ./helpers/primitives_utils

randomize()

type SomeDistinctType = distinct uint16

type CustomType = object
    a: uint16
    b: string

proc encode(encoder: var AbiEncoder, custom: CustomType) {.raises: [AbiEncodingError]} =
  encoder.encode((custom.a, custom.b))

proc decode(decoder: var AbiDecoder, T: type CustomType): T {.raises: [AbiDecodingError]}  =
  let (a, b) = decoder.decode( (uint16, string) )
  return CustomType(a: a, b: b)

func `==`*(a, b: SomeDistinctType): bool =
  uint16(a) == uint16(b)

suite "ABI decoding":
  proc checkDecode[T](value: T) =
    let encoded = AbiEncoder.encode(value)
    check AbiDecoder.decode(encoded, T) == value

  proc randomBytes[N: static int](): array[N, byte] =
    var a: array[N, byte]
    for b in a.mitems:
        b = rand(byte)
    return a

  proc checkDecode(T: type) =
    checkDecode(T.default)
    checkDecode(T.low)
    checkDecode(T.high)

  test "decodes uint8, uint16, 32, 64":
    checkDecode(uint8)
    checkDecode(uint16)
    checkDecode(uint32)
    checkDecode(uint64)

  test "decodes int8, int16, int32, int64":
    checkDecode(int8)
    checkDecode(int16)
    checkDecode(int32)
    checkDecode(int64)

  test "fails to decode when reading past end":
    var encoded = AbiEncoder.encode(uint8.fromBytes(randomBytes[8](), bigEndian))
    encoded.delete(encoded.len-1)

    try:
      discard AbiDecoder.decode(encoded, uint8)
      fail()
    except AbiDecodingError as decoded:
      check decoded.msg == "reading past end of bytes"

  test "fails to decode when trailing bytes remain":
    var encoded = AbiEncoder.encode(uint8.fromBytes(randomBytes[8](), bigEndian))
    encoded.add(uint8.fromBytes(randomBytes[8](), bigEndian))

    try:
      discard AbiDecoder.decode(encoded, uint8)
      fail()
    except AbiDecodingError as decoded:
      check decoded.msg == "unread trailing bytes found"

  test "fails to decode when padding does not consist of zeroes with unsigned value":
    var encoded = AbiEncoder.encode(uint8.fromBytes(randomBytes[8](), bigEndian))
    encoded[3] = 42'u8

    try:
      discard AbiDecoder.decode(encoded, uint8)
      fail()
    except AbiDecodingError as decoded:
      check decoded.msg == "invalid padding found"

  test "fails to decode when padding does not consist of zeroes":
    var encoded = AbiEncoder.encode(8.int8)
    encoded[3] = 42'u8

    try:
      discard AbiDecoder.decode(encoded, int8)
      fail()
    except AbiDecodingError as decoded:
      check decoded.msg == "invalid padding found"

  test "decodes booleans":
    checkDecode(false)
    checkDecode(true)

  test "fails to decode boolean when value is not 0 or 1":
    let encoded = AbiEncoder.encode(2'u8)

    try:
      discard AbiDecoder.decode(encoded, bool)
      fail()
    except AbiDecodingError as decoded:
      check decoded.msg == "invalid boolean value"

  test "decodes ranges":
    type SomeRange = range[0x0000'u16..0xAAAA'u16]
    checkDecode(SomeRange(42))
    checkDecode(SomeRange.low)
    checkDecode(SomeRange.high)

  test "fails to decode when value not in range":
    type SomeRange = range[0x0000'u16..0xAAAA'u16]
    let encoded = AbiEncoder.encode(0xFFFF'u16)

    try:
      discard AbiDecoder.decode(encoded, SomeRange)
      fail()
    except AbiDecodingError as decoded:
      check decoded.msg == "value not in range"

  test "decodes enums":
    type SomeEnum = enum
      one = 1
      two = 2
    checkDecode(one)
    checkDecode(two)

  test "fails to decode enum when encountering invalid value":
    type SomeEnum = enum
      one = 1
      two = 2
    let encoded = AbiEncoder.encode(3'u8)

    try:
      discard AbiDecoder.decode(encoded, SomeEnum)
      fail()
    except AbiDecodingError as decoded:
      check decoded.msg == "invalid enum value"

  test "decodes stints":
    checkDecode(UInt128)
    checkDecode(UInt256)
    checkDecode(Int128)
    checkDecode(Int256)

  test "decodes addresses":
    checkDecode(address(3))

  test "decodes byte arrays":
    checkDecode([1'u8, 2'u8, 3'u8])
    checkDecode(randomBytes[32]())
    checkDecode(randomBytes[33]())

  test "fails to decode array when padding does not consist of zeroes":
    var arr = randomBytes[33]()
    var encoded = AbiEncoder.encode(arr)
    encoded[62] = 42'u8

    try:
      discard AbiDecoder.decode(encoded, type(arr))
      fail()
    except AbiDecodingError as decoded:
      check decoded.msg == "invalid padding found"

  test "decodes byte sequences":
    checkDecode(@[1'u8, 2'u8, 3'u8])
    checkDecode(@(randomBytes[32]()))
    checkDecode(@(randomBytes[33]()))

  test "fails to decode seq when padding does not consist of zeroes":
    var value = @(randomBytes[64]())
    value[62] = 42'u8

    try:
      discard AbiDecoder.decode(value, seq[byte])
      fail()
    except AbiDecodingError as decoded:
      check decoded.msg == "invalid padding found"

  test "decodes sequences":
    let seq1 = @(randomBytes[33]())
    let seq2 = @(randomBytes[32]())
    let value = @[seq1, seq2]
    checkDecode(value)

  test "decodes arrays with static elements":
    checkDecode([randomBytes[32](), randomBytes[32]()])

  test "decodes arrays with dynamic elements":
    let seq1 = @(randomBytes[32]())
    let seq2 = @(randomBytes[32]())
    checkDecode([seq1, seq2])

  test "decodes arrays with string":
    checkDecode(["hello", "world"])

  test "decodes strings":
    checkDecode("hello!☺")

  test "decodes distinct types as their base type":
    checkDecode(SomeDistinctType(0xAABB'u16))

  test "decodes tuples":
    let a = true
    let b = @[1'u8, 2'u8, 3'u8]
    let c = 0xAABBCCDD'u32
    let d = @[4'u8, 5'u8, 6'u8]
    checkDecode( (a, b, c, d) )

  test "decodes nested tuples":
    let a = true
    let b = @[1'u8, 2'u8, 3'u8]
    let c = 0xAABBCCDD'u32
    let d = @[4'u8, 5'u8, 6'u8]
    checkDecode( (a, b, (c, d)) )

  test "reads elements after dynamic tuple":
    let a = @[1'u8, 2'u8, 3'u8]
    let b = 0xAABBCCDD'u32
    checkDecode( ((a,), b) )

  test "reads elements after static tuple":
    let a = 0x123'u16
    let b = 0xAABBCCDD'u32
    checkDecode( ((a,), b) )

  test "reads static tuple inside dynamic tuple":
    let a = @[1'u8, 2'u8, 3'u8]
    let b = 0xAABBCCDD'u32
    checkDecode( (a, (b,)) )

  test "reads empty tuples":
    checkDecode( ((),) )

  test "reads empty tuple":
    checkDecode( (), )

  test "decodes custom type":

    let c : CustomType = CustomType(a: 42'u16, b: "hello")
    checkDecode(c)
