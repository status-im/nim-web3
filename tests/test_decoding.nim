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

func `==`*(a, b: SomeDistinctType): bool =
  uint16(a) == uint16(b)

suite "ABI decoding":
  proc checkDecodee[T](value: T) =
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

  proc checkDecodee(T: type) =
    checkDecodee(T.default)
    checkDecodee(T.low)
    checkDecodee(T.high)

  test "decodes uint8, uint16, 32, 64":
    checkDecodee(uint8)
    checkDecodee(uint16)
    checkDecodee(uint32)
    checkDecodee(uint64)

  test "decodes int8, int16, int32, int64":
    checkDecodee(int8)
    checkDecodee(int16)
    checkDecodee(int32)
    checkDecodee(int64)

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
    checkDecodee(false)
    checkDecodee(true)

  test "fails to decode boolean when value is not 0 or 1":
    let encoded = AbiEncoder.encode(2'u8)

    try:
      discard AbiDecoder.decode(encoded, bool)
      fail()
    except AbiDecodingError as decoded:
      check decoded.msg == "invalid boolean value"

  test "decodes ranges":
    type SomeRange = range[0x0000'u16..0xAAAA'u16]
    checkDecodee(SomeRange(42))
    checkDecodee(SomeRange.low)
    checkDecodee(SomeRange.high)

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
    checkDecodee(one)
    checkDecodee(two)

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
    checkDecodee(UInt128)
    checkDecodee(UInt256)
    checkDecodee(Int128)
    checkDecodee(Int256)

  test "decodes addresses":
    checkDecodee(address(3))

  test "decodes byte arrays":
    checkDecodee([1'u8, 2'u8, 3'u8])
    checkDecodee(randomBytes[32]())
    checkDecodee(randomBytes[33]())

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
    checkDecodee(@[1'u8, 2'u8, 3'u8])
    checkDecodee(@(randomBytes[32]()))
    checkDecodee(@(randomBytes[33]()))

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
    checkDecodee(value)

  test "decodes arrays with static elements":
    checkDecodee([randomBytes[32](), randomBytes[32]()])

  test "decodes arrays with dynamic elements":
    let seq1 = @(randomBytes[32]())
    let seq2 = @(randomBytes[32]())
    checkDecodee([seq1, seq2])

  test "decodes arrays with string":
    checkDecodee(["hello", "world"])

  test "decodes strings":
    checkDecodee("hello!☺")

  test "decodes distinct types as their base type":
    checkDecodee(SomeDistinctType(0xAABB'u16))

  test "decodes tuples":
    let a = true
    let b = @[1'u8, 2'u8, 3'u8]
    let c = 0xAABBCCDD'u32
    let d = @[4'u8, 5'u8, 6'u8]
    checkDecodee( (a, b, c, d) )

  test "decodes nested tuples":
    let a = true
    let b = @[1'u8, 2'u8, 3'u8]
    let c = 0xAABBCCDD'u32
    let d = @[4'u8, 5'u8, 6'u8]
    checkDecodee( (a, b, (c, d)) )

  test "reads elements after dynamic tuple":
    let a = @[1'u8, 2'u8, 3'u8]
    let b = 0xAABBCCDD'u32
    checkDecodee( ((a,), b) )

  test "reads elements after static tuple":
    let a = 0x123'u16
    let b = 0xAABBCCDD'u32
    checkDecodee( ((a,), b) )

  test "reads static tuple inside dynamic tuple":
    let a = @[1'u8, 2'u8, 3'u8]
    let b = 0xAABBCCDD'u32
    checkDecodee( (a, (b,)) )

  test "reads empty tuples":
    checkDecodee( ((),) )

  test "reads empty tuple":
    checkDecodee( (), )