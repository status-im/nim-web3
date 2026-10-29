import
  std/[unittest, random],
  stew/[endians2],
  stint,
  serialization,
  ../web3/eth_api_types,
  ../web3/decoding,
  ../web3/encoding,
  ../web3/abi_serialization,
  ./helpers/primitives_utils

randomize()

type SomeDistinctType = distinct uint16

func `==`*(a, b: SomeDistinctType): bool =
  uint16(a) == uint16(b)

type
  DistinctArray = distinct array[2, uint16]
  DistinctTuple = distinct (uint8, DynBytes)
  DistinctBytes = distinct DynBytes

func `==`*(a, b: DistinctArray): bool =
  array[2, uint16](a) == array[2, uint16](b)

func `==`*(a, b: DistinctTuple): bool =
  distinctBase(a) == distinctBase(b)

func `==`*(a, b: DistinctBytes): bool =
  distinctBase(a) == distinctBase(b)

suite "ABI decoding":
  proc checkDecode[T](value: T) =
    let encoded = Abi.encode(value)
    check Abi.decode(encoded, T) == value

  proc randomBytes[N: static int](): array[N, byte] =
    var a: array[N, byte]
    for b in a.mitems:
        b = rand(byte)
    a

  proc checkDecode(T: type) =
    checkDecode(T.default)
    checkDecode(T.low)
    checkDecode(T.high)

  proc checkDeprecatedDecode[T](value: T) =
    var decoded: T
    check:
      decode(Abi.encode((value,)), 0, 0, decoded) == 32
      decoded == value

  template checkPastEnd(encoded: seq[byte], T: type) =
    try:
      discard Abi.decode(encoded, T)
      fail()
    except SerializationError as decoded:
      check decoded.msg == "reading past end of bytes"

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

  test "fails when trying to decode overfow data":
    try:
      let encoded = Abi.encode(int16.high)
      discard Abi.decode(encoded, int8)
      fail()
    except SerializationError:
      discard

  test "fails to decode when reading past end":
    var encoded = Abi.encode(uint8.fromBytes(randomBytes[8](), bigEndian))
    encoded.delete(encoded.len-1)

    try:
      discard Abi.decode(encoded, uint8)
      fail()
    except SerializationError as decoded:
      check decoded.msg == "reading past end of bytes"

  test "fails to decode offsets and lengths past end":
    let tail = Abi.encode(DistinctBytes(@[1'u8]))
    checkPastEnd(Abi.encode(4096'u64) & tail, (DistinctBytes,))
    checkPastEnd(Abi.encode(uint64.high) & tail, (DistinctBytes,))
    for length in [1'u64 shl 62, uint64.high]:
      let encoded = Abi.encode(32'u64) & Abi.encode(length)
      checkPastEnd(encoded, (DistinctBytes,))
      checkPastEnd(encoded, (seq[UInt256],))
      checkPastEnd(encoded, (seq[DistinctBytes],))

  test "ignores trailing bytes":
    let
      value = uint8.fromBytes(randomBytes[8](), bigEndian)
      encoded = Abi.encode(value) & @(randomBytes[8]())
    check Abi.decode(encoded, uint8) == value

  test "fails to decode when padding does not consist of zeroes with unsigned value":
    var encoded = Abi.encode(uint8.fromBytes(randomBytes[8](), bigEndian))
    encoded[3] = 42'u8

    try:
      discard Abi.decode(encoded, uint8)
      fail()
    except SerializationError as decoded:
      check decoded.msg == "invalid padding found"

  test "fails to decode when padding does not consist of zeroes":
    var encoded = Abi.encode(8.int8)
    encoded[3] = 42'u8

    try:
      discard Abi.decode(encoded, int8)
      fail()
    except SerializationError as decoded:
      check decoded.msg == "invalid padding found"

  test "decodes booleans":
    checkDecode(false)
    checkDecode(true)

  test "fails to decode boolean when value is not 0 or 1":
    let encoded = Abi.encode(2'u8)

    try:
      discard Abi.decode(encoded, bool)
      fail()
    except SerializationError as decoded:
      check decoded.msg == "invalid boolean value"

  test "decodes ranges":
    type SomeRange = range[0x0000'u16..0xAAAA'u16]
    checkDecode(SomeRange)

  test "fails to decode when value not in range":
    type SomeRange = range[0x0000'u16..0xAAAA'u16]
    let encoded = Abi.encode(0xFFFF'u16)

    try:
      discard Abi.decode(encoded, SomeRange)
      fail()
    except SerializationError as decoded:
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
    let encoded = Abi.encode(3'u8)

    try:
      discard Abi.decode(encoded, SomeEnum)
      fail()
    except SerializationError as decoded:
      check decoded.msg == "invalid enum value"

  test "decodes stints":
    checkDecode(UInt128)
    checkDecode(StUint[160])
    checkDecode(UInt256)
    checkDecode(Int128)
    checkDecode(StInt[160])
    checkDecode(Int256)
    checkDeprecatedDecode(UInt128.high)
    checkDeprecatedDecode(Int128.low)
    check:
      not compiles(Abi.decode(newSeq[byte](64), StUint[512]))
      not compiles(Abi.decode(newSeq[byte](64), StInt[512]))

    var uint512: StUint[512]
    var int512: StInt[512]
    check:
      not compiles(decode(newSeq[byte](64), 0, 0, uint512))
      not compiles(decode(newSeq[byte](64), 0, 0, int512))

  test "decodes addresses":
    checkDecode(address(3))

  test "fails to decode address when padding does not consist of zeroes":
    var encoded = Abi.encode(address(3))
    encoded[11] = 42'u8

    try:
      discard Abi.decode(encoded, Address)
      fail()
    except SerializationError as decoded:
      check decoded.msg == "invalid padding found"

  test "decodes FixedBytes":
    checkDecode(FixedBytes[3]([1'u8, 2'u8, 3'u8]))
    checkDecode(FixedBytes[32](randomBytes[32]()))
    check not compiles(checkDecode(FixedBytes[33](randomBytes[33]())))
    checkDeprecatedDecode(FixedBytes[3]([1'u8, 2'u8, 3'u8]))

    var bytes33: FixedBytes[33]
    check not compiles(decode(newSeq[byte](64), 0, 0, bytes33))

  test "decodes uint8 arrays":
    # Only FixedBytes arrays are packed, not uint8 (or Nim byte) arrays
    checkDecode([1'u8, 2'u8, 3'u8])
    checkDecode(randomBytes[32]())
    checkDecode(randomBytes[33]())
    checkDecode(randomBytes[65]())

  test "fails to decode array when padding does not consist of zeroes":
    var arr = FixedBytes[25](randomBytes[25]())
    var encoded = Abi.encode(arr)
    encoded[29] = 42'u8

    try:
      discard Abi.decode(encoded, type(arr))
      fail()
    except SerializationError as decoded:
      check decoded.msg == "invalid padding found"

  test "decodes byte sequences":
    checkDecode(DynBytes(@[1'u8, 2'u8, 3'u8]))
    checkDecode(DynBytes(@(randomBytes[32]())))
    checkDecode(DynBytes(@(randomBytes[33]())))
    checkDeprecatedDecode(DynBytes(@[1'u8, 2'u8, 3'u8]))

  test "ignores padding of byte sequences and strings":
    let
      bytes = DynBytes(@[1'u8, 2'u8, 3'u8])
      encodedBytes = Abi.encode(bytes)
      encodedString = Abi.encode("hello")
    var
      dirtyBytes = encodedBytes
      dirtyString = encodedString
    dirtyBytes[^1] = 42'u8
    dirtyString[^1] = 42'u8
    check:
      Abi.decode(dirtyBytes, DynBytes) == bytes
      Abi.decode(encodedBytes[0 ..< 35], DynBytes) == bytes
      Abi.decode(dirtyString, string) == "hello"
      Abi.decode(encodedString[0 ..< 37], string) == "hello"

    let
      first = DynBytes(@[1'u8])
      second = DynBytes(@(randomBytes[300]()))
      unpadded =
        Abi.encode((64'u64, 97'u64, 1'u64)) & @[1'u8] &
        Abi.encode(300'u64) & distinctBase(second)
    check Abi.decode(unpadded, (DynBytes, DynBytes)) == (first, second)

  test "decodes sequences":
    let
      seq1 = DynBytes(@(randomBytes[33]()))
      seq2 = DynBytes(@(randomBytes[32]()))
      value = @[seq1, seq2]
    checkDecode(value)

  test "decodes arrays with static elements":
    checkDecode([
      FixedBytes[32](randomBytes[32]()),
      FixedBytes[32](randomBytes[32]())])

  test "decodes arrays with dynamic elements":
    let
      seq1 = DynBytes(@(randomBytes[32]()))
      seq2 = DynBytes(@(randomBytes[32]()))
    checkDecode([seq1, seq2])

  test "decodes arrays with string":
    checkDecode(["hello", "world"])

  test "decodes nested collections":
    let a = @[@[1.u256, 2.u256], @[3.u256]]
    checkDecode(a)
    checkDecode([@[1'u16, 2'u16], @[3'u16]])
    checkDecode([[1'u16, 2'u16], [3'u16, 4'u16]])
    checkDecode(@[[1'u16, 2'u16], [3'u16, 4'u16]])
    let encoded =
      Abi.encode(64'u64) &  # offset to a
      Abi.encode(7'u8) &
      Abi.encode(2'u64) &   # a length
      Abi.encode(64'u64) &  # offset to a[0]
      Abi.encode(160'u64) & # offset to a[1]
      Abi.encode(2'u64) & Abi.encode(a[0][0]) & Abi.encode(a[0][1]) &
      Abi.encode(1'u64) & Abi.encode(a[1][0])
    check Abi.decode(encoded, (seq[seq[UInt256]], uint8)) == (a, 7'u8)

  test "decodes strings":
    checkDecode("hello!☺")

  test "decodes distinct types as their base type":
    checkDecode(SomeDistinctType(0xAABB'u16))

    let
      a = [1'u16, 2'u16]
      b = (3'u8, DynBytes(@[4'u8]))
      c = DynBytes(@[5'u8])
      distinctTuple = (DistinctArray(a), DistinctTuple(b), DistinctBytes(c))
    checkDecode(distinctTuple)
    check Abi.decode(Abi.encode( (a, b, c) ), typeof(distinctTuple)) ==
      distinctTuple

  test "decodes tuples":
    let
      a = true
      b = DynBytes(@[1'u8, 2'u8, 3'u8])
      c = 0xAABBCCDD'u32
      d = DynBytes(@[4'u8, 5'u8, 6'u8])
    checkDecode( (a, b, c, d) )

  test "decodes nested tuples":
    let
      a = true
      b = DynBytes(@[1'u8, 2'u8, 3'u8])
      c = 0xAABBCCDD'u32
      d = DynBytes(@[4'u8, 5'u8, 6'u8])
    checkDecode( (a, b, (c, d)) )

  test "reads elements after dynamic tuple":
    let
      a = DynBytes(@[1'u8, 2'u8, 3'u8])
      b = 0xAABBCCDD'u32
    checkDecode( ((a,), b) )

  test "reads elements after static tuple":
    let
      a = 0x123'u16
      b = 0xAABBCCDD'u32
    checkDecode( ((a,), b) )

  test "reads static tuple inside dynamic tuple":
    let
      a = DynBytes(@[1'u8, 2'u8, 3'u8])
      b = 0xAABBCCDD'u32
    checkDecode( (a, (b,)) )
    checkDecode( (a, (b, [b, b])) )

  test "reads static array inside dynamic tuple":
    let
      a = DynBytes(@[1'u8, 2'u8, 3'u8])
      b = 0xAABBCCDD'u32
    checkDecode( (a, [b, b]) )
    checkDecode( ([b, b], a) )

  test "decodes offsets relative to the enclosing tuple":
    let
      a = DynBytes(@[1'u8])
      encoded =
        Abi.encode(1'u8) &
        Abi.encode(64'u64) & # offset to inner tuple
        Abi.encode(2'u8) &
        Abi.encode(96'u64) & # offset to a, relative to inner tuple
        Abi.encode(32'u64) & # unused
        Abi.encode(a)
    check Abi.decode(
      encoded, (uint8, (uint8, DynBytes))) == (1'u8, (2'u8, a))
    let encodedSeq =
      Abi.encode(32'u64) & # offset to sequence
      Abi.encode(1'u64) &  # sequence length
      Abi.encode(64'u64) & # offset to a, relative to sequence items
      Abi.encode(32'u64) & # unused
      Abi.encode(a)
    check Abi.decode(encodedSeq, (seq[DynBytes],)) == (@[a],)

  test "decodes out-of-order and shared offsets":
    let
      a = DynBytes(@[10'u8])
      b = DynBytes(@[11'u8])
      reversed =
        Abi.encode(1'u8) &
        Abi.encode(64'u64) &  # offset to inner tuple
        Abi.encode(128'u64) & # offset to a, relative to inner tuple
        Abi.encode(64'u64) &  # offset to b, relative to inner tuple
        Abi.encode(b) &
        Abi.encode(a)
    check Abi.decode(reversed, (uint8, (DynBytes, DynBytes))) == (1'u8, (a, b))
    let shared =
      Abi.encode(1'u8) &
      Abi.encode(64'u64) & # offset to inner tuple
      Abi.encode(64'u64) & # offset to a, relative to inner tuple
      Abi.encode(64'u64) & # offset to a, relative to inner tuple
      Abi.encode(a) &
      Abi.encode(b)
    check Abi.decode(shared, (uint8, (DynBytes, DynBytes))) == (1'u8, (a, a))
    let reversedSeq =
      Abi.encode(32'u64) &  # offset to sequence
      Abi.encode(2'u64) &   # sequence length
      Abi.encode(128'u64) & # offset to a, relative to sequence items
      Abi.encode(64'u64) &  # offset to b, relative to sequence items
      Abi.encode(b) &
      Abi.encode(a)
    check Abi.decode(reversedSeq, (seq[DynBytes],)) == (@[a, b],)

  test "limits memory used by decoding":
    let a = DynBytes(@(randomBytes[256]()))
    var shared = Abi.encode(32'u64) & Abi.encode(8'u64)
    for _ in 0 ..< 8:
      shared &= Abi.encode(256'u64) # offset to a, relative to sequence items
    shared &= Abi.encode(a)
    expect(SerializationError):
      discard Abi.decode(shared, (seq[DynBytes],))
    let decoded = (@[a, a, a, a, a, a, a, a],)
    check:
      Abi.decode(shared, (seq[DynBytes],), maxMemoryFactor = 5'u) == decoded
      Abi.decode(shared, (seq[DynBytes],), maxMemoryFactor = 0'u) == decoded

    let empty = Abi.encode(32'u64) & Abi.encode(1'u64 shl 24)
    expect(SerializationError):
      discard Abi.decode(empty, (seq[tuple[]],))
    check Abi.decode(
      Abi.encode(32'u64) & Abi.encode(2'u64), (seq[tuple[]],)) == (@[(), ()],)

  test "reads empty tuples":
    checkDecode( ((),) )

  test "reads empty tuple":
    checkDecode( (), )

  test "encodes strings":
    let encoded = Abi.encode("hello")
    check Abi.decode(encoded, string) == "hello"

  test "encodes empty strings":
    let
      encoded = Abi.encode("")
      decoded = Abi.decode(encoded, string)
    check:
      decoded == ""
      len(decoded) == 0
