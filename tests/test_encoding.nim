import
  std/unittest,
  std/sequtils,
  std/random,
  stint,
  stew/[byteutils],
  serialization,
  ../web3/encoding,
  ../web3/eth_api_types,
  ../web3/abi_serialization,
  ./helpers/primitives_utils

suite "ABI encoding":
  proc zeroes(amount: int): seq[byte] =
    newSeq[byte](amount)

  proc randomBytes[N: static int](): array[N, byte] =
    var a: array[N, byte]
    for b in a.mitems:
      b = rand(byte)
    a

  test "encodes uint8":
    check Abi.encode(42'u8) == 31.zeroes & 42'u8 # [0, 0, ..., 0, 2a] (2a = 42)

  test "encodes booleans":
    check Abi.encode(false) == 31.zeroes & 0'u8 # [0, 0, ..., 0, 0]
    check Abi.encode(true) == 31.zeroes & 1'u8 # [0, 0, ..., 0, 1]

  test "encodes uint16, 32, 64":
    check Abi.encode(0xABCD'u16) ==
      30.zeroes & 0xAB'u8 & 0xCD'u8
    check Abi.encode(0x11223344'u32) ==
      28.zeroes & 0x11'u8 & 0x22'u8 & 0x33'u8 & 0x44'u8
    check Abi.encode(0x1122334455667788'u64) ==
      24.zeroes &
      0x11'u8 & 0x22'u8 & 0x33'u8 & 0x44'u8 &
      0x55'u8 & 0x66'u8 & 0x77'u8 & 0x88'u8

  test "encodes int8, 16, 32, 64":
    check Abi.encode(1'i8) == 31.zeroes & 0x01'u8  # [0, 0, ..., 0, 1]
    check Abi.encode(1'i16) == 31.zeroes & 0x01'u8 # [0, 0, ..., 0, 1]
    check Abi.encode(1'i32) == 31.zeroes & 0x01'u8 # [0, 0, ..., 0, 1]
    check Abi.encode(1'i64) == 31.zeroes & 0x01'u8 # [0, 0, ..., 0, 1]

    check Abi.encode(-1'i8) == 0xFF'u8.repeat(32)  # [255, 255, ..., 255] (signed value)
    check Abi.encode(-1'i16) == 0xFF'u8.repeat(32) # [255, 255, ..., 255] (signed value)
    check Abi.encode(-1'i32) == 0xFF'u8.repeat(32) # [255, 255, ..., 255] (signed value)
    check Abi.encode(-1'i64) == 0xFF'u8.repeat(32) # [255, 255, ..., 255] (signed value)

  test "encodes ranges":
    type SomeRange = range[0x0000'u16..0xAAAA'u16]
    check Abi.encode(SomeRange(0x1122)) == 30.zeroes & 0x11'u8 & 0x22'u8

  test "encodes enums":
    type SomeEnum = enum
      one = 1
      two = 2
    check Abi.encode(one) == 31.zeroes & 1'u8 # [0, 0, ..., 0, 1]
    check Abi.encode(two) == 31.zeroes & 2'u8 # [0, 0, ..., 0, 2]

  test "encodes stints":
    let uint256 = UInt256.fromBytes(randomBytes[32](), bigEndian)
    let uint128 = UInt128.fromBytes(randomBytes[32](), bigEndian)
    check Abi.encode(uint256) == @(uint256.toBytesBE)
    check Abi.encode(uint128) == 16.zeroes & @(uint128.toBytesBE)
    check encode(uint128) == 16.zeroes & @(uint128.toBytesBE)

    check Abi.encode(1.i256) == 31.zeroes & 0x01'u8 # [0, 0, ..., 0, 1]
    check Abi.encode(1.i128) == 31.zeroes & 0x01'u8 # [0, 0, ..., 0, 1]

    check Abi.encode(-1.i256) == 0xFF'u8.repeat(32) # [255, 255, ..., 255] (signed value)
    check Abi.encode(-1.i128) == 0xFF'u8.repeat(32) # [255, 255, ..., 255] (signed value)
    check encode(-1.i128) == 0xFF'u8.repeat(32)

    check not compiles(Abi.encode(1.stuint(512)))
    check not compiles(Abi.encode(1.stint(512)))

  test "encodes addresses":
    let address = address(3)
    check Abi.encode(address) == 12.zeroes & @(array[20, byte](address))

  test "encodes hashes":
    let hash = txhash(3)
    check Abi.encode(hash) == @(array[32, byte](hash))

  test "encodes FixedBytes":
    let bytes3 = FixedBytes[3]([1'u8, 2'u8, 3'u8])
    check Abi.encode(bytes3) == @[1'u8, 2'u8, 3'u8] & 29.zeroes # Fixed array are right-padded with zeroes
    check encode(bytes3) == @[1'u8, 2'u8, 3'u8] & 29.zeroes

    let bytes32 = FixedBytes[32](randomBytes[32]())
    check Abi.encode(bytes32) == @(bytes32.data)

    let bytes33 = FixedBytes[33](randomBytes[33]())
    check not compiles(Abi.encode(bytes33))
    check not compiles(encode(bytes33))

  test "encodes uint8 arrays":
    # Only FixedBytes arrays are packed, not uint8 (or Nim byte) arrays
    let bytes3 = [1'u8, 2'u8, 3'u8]
    check Abi.encode(bytes3) == bytes3.mapIt(31.zeroes & it).concat()
    check encode(bytes3) == bytes3.mapIt(31.zeroes & it).concat()

    let bytes32 = randomBytes[32]()
    check Abi.encode(bytes32) == bytes32.mapIt(31.zeroes & it).concat()

    let bytes33 = randomBytes[33]()
    check Abi.encode(bytes33) == bytes33.mapIt(31.zeroes & it).concat()
    check encode(bytes33) == bytes33.mapIt(31.zeroes & it).concat()

  test "encodes byte sequences":
    let bytes3 = DynBytes(@[1'u8, 2'u8, 3'u8])
    let bytes3len = Abi.encode(bytes3.len.uint64)
    check Abi.encode(bytes3) == bytes3len & bytes3 & 29.zeroes
    check Abi.encode(bytes3) ==
      31.zeroes & 3'u8 & # [0, 0, ..., 0, 3] (length)
      bytes3 & 29.zeroes # [1, 2, 3, 0, ..., 0] (data)

    let bytes32 = DynBytes(@(randomBytes[32]()))
    let bytes32len = Abi.encode(bytes32.len.uint64)
    check Abi.encode(bytes32) == bytes32len & bytes32

    let bytes33 = DynBytes(@(randomBytes[33]()))
    let bytes33len = Abi.encode(bytes33.len.uint64)
    check Abi.encode(bytes33) == bytes33len & bytes33 & 31.zeroes

  test "encodes empty seq of seq":
    let v: seq[seq[int]] = @[]
    check Abi.encode(v) == Abi.encode(0'u64)
    check Abi.encode(v) == 32.zeroes # Encode the size only (zero)

  test "encodes tuples":
    let a = true
    let b = DynBytes(@[1'u8, 2'u8, 3'u8])
    let c = 0xAABBCCDD'u32
    let d = DynBytes(@[4'u8, 5'u8, 6'u8])
    check Abi.encode( (a, b, c, d) ) ==
      Abi.encode(a) &
      Abi.encode(4 * 32'u8) &
      Abi.encode(c) &
      Abi.encode(6 * 32'u8) &
      Abi.encode(b) &
      Abi.encode(d)
    check Abi.encode( (a, b, c, d) ) ==
      31.zeroes & 1'u8 &                          # boolean value
      31.zeroes & 128'u8 &                        # offset to b (4 (bool, offset, int, offset) * 32 bytes)
      28.zeroes & 0xAA'u8 & 0xBB & 0xCC & 0xDD &
      31.zeroes & 192'u8 &                        # offset to d ((4 + b length + b data) * 32 bytes)
      31.zeroes & 3'u8 & b & 29.zeroes &          # b (length + data)
      31.zeroes & 3'u8 & d & 29.zeroes            # d (length + data)

  test "encodes nested tuples":
    let a = true
    let b = DynBytes(@[1'u8, 2'u8, 3'u8])
    let c = 0xAABBCCDD'u32
    let d = DynBytes(@[4'u8, 5'u8, 6'u8])
    check Abi.encode( (a, b, (c, d)) ) ==
      Abi.encode(a) &
      Abi.encode(3 * 32'u8) & # offset of b in outer tuple
      Abi.encode(5 * 32'u8) & # offset of inner tuple in outer tuple
      Abi.encode(b) &
      Abi.encode(c) &
      Abi.encode(2 * 32'u8) & # offset of d in inner tuple
      Abi.encode(d)
    check Abi.encode( (a, b, (c, d)) ) ==
      31.zeroes & 1'u8 &                            # boolean value
      31.zeroes & 96'u8 &                           # offset to b ((bool, offset, tuple) * 32 bytes)
      31.zeroes & 160'u8 &                          # offset to tuple ((3 + b length + b data) * 32 bytes)
      31.zeroes & 3'u8 & b & 29.zeroes &            # b (length + data)
      28.zeroes & 0xAA'u8 & 0xBB & 0xCC & 0xDD &
      31.zeroes & 64'u8 &                           # offset to d ((static + offset) * 32 bytes)
      31.zeroes & 3'u8 & d & 29.zeroes              # d (length + data)

  test "encodes tuple with static array and dynamic":
    let a = 1'u8
    let b = [2'u16, 3'u16]
    let c = DynBytes(@[4'u8])
    check Abi.encode( (a, b, c) ) ==
      Abi.encode(a) &
      Abi.encode(b) &
      Abi.encode(4 * 32'u8) & # offset of c after inline b
      Abi.encode(c)
    check Abi.encode( (a, b, c) ) ==
      31.zeroes & 1'u8 &                # a
      31.zeroes & 2'u8 &                # b[0]
      31.zeroes & 3'u8 &                # b[1]
      31.zeroes & 128'u8 &              # offset to c (4 * 32 bytes)
      31.zeroes & 1'u8 & c & 31.zeroes  # c (length + data)

  test "encodes tuple with nested static tuple and dynamic":
    let a = 1'u8
    let b = (2'u8, [3'u16, 4'u16])
    let c = DynBytes(@[5'u8])
    check Abi.encode( (a, b, c) ) ==
      Abi.encode(a) &
      Abi.encode(b) &
      Abi.encode(5 * 32'u8) & # offset of c after inline b
      Abi.encode(c)
    check Abi.encode( (a, b, c) ) ==
      31.zeroes & 1'u8 &                # a
      31.zeroes & 2'u8 &                # b[0]
      31.zeroes & 3'u8 &                # b[1][0]
      31.zeroes & 4'u8 &                # b[1][1]
      31.zeroes & 160'u8 &              # offset to c (5 * 32 bytes)
      31.zeroes & 1'u8 & c & 31.zeroes  # c (length + data)

  test "encodes tuple with nested static array and dynamic":
    let a = 1'u8
    let b = [[2'u16, 3'u16], [4'u16, 5'u16]]
    let c = DynBytes(@[6'u8])
    check Abi.encode( (a, b, c) ) ==
      Abi.encode(a) &
      Abi.encode(b) &
      Abi.encode(6 * 32'u8) & # offset of c after inline b
      Abi.encode(c)
    check Abi.encode( (a, b, c) ) ==
      31.zeroes & 1'u8 &                # a
      31.zeroes & 2'u8 &                # b[0][0]
      31.zeroes & 3'u8 &                # b[0][1]
      31.zeroes & 4'u8 &                # b[1][0]
      31.zeroes & 5'u8 &                # b[1][1]
      31.zeroes & 192'u8 &              # offset to c (6 * 32 bytes)
      31.zeroes & 1'u8 & c & 31.zeroes  # c (length + data)

  test "encodes tuple with only dynamic fields":
    let t = (DynBytes(@[1'u8, 2'u8]), DynBytes(@[3'u8, 4'u8]))
    check Abi.encode(t) ==
      Abi.encode(2 * 32'u64) &
      Abi.encode(4 * 32'u64) &
      Abi.encode(DynBytes(@[1'u8, 2'u8])) &
      Abi.encode(DynBytes(@[3'u8, 4'u8]))
    check Abi.encode(t) ==
      31.zeroes & 64'u8 &                            # offset to first
      31.zeroes & 128'u8 &                           # offset to second (first offset + length encoding + data length)
      31.zeroes & 2'u8 & @[1'u8, 2'u8] & 30.zeroes & # first element (length + data)
      31.zeroes & 2'u8 & @[3'u8, 4'u8] & 30.zeroes   # second element (length + data)

  test "encodes tuple with empty dynamic fields":
    var empty: DynBytes
    let t = (empty, empty)
    check Abi.encode(t) ==
      Abi.encode(2 * 32'u64) &
      Abi.encode(2 * 32'u64 + Abi.encode(empty).len.uint64) &
      Abi.encode(empty) &
      Abi.encode(empty)
    check Abi.encode(t) ==
      31.zeroes & 64'u8 &  # offset to first
      31.zeroes & 96'u8 &  # offset to second (first offset + length encoding + data length)
      32.zeroes &          # empty sequence
      32.zeroes            # empty sequence

  test "encodes tuple with static and empty dynamic":
    var empty: DynBytes
    let t = (42'u8, empty)
    check Abi.encode(t) ==
      Abi.encode(42'u8) &
      Abi.encode(2 * 32'u64) &
      Abi.encode(empty)
    check Abi.encode(t) ==
      31.zeroes & 42'u8 & # int left-padded with zeroes
      31.zeroes & 64'u8 & # offset to empty (static + offset)
      32.zeroes           # empty sequence

  test "encodes objects inside tuples":
    type
      StaticObject = object
        a: uint8
        skipped {.dontSerialize.}: DynBytes
      DynamicObject = object
        a: (uint8, DynBytes)
    let value = (
      StaticObject(a: 1, skipped: DynBytes(@[9'u8])),
      DynamicObject(a: (2'u8, DynBytes(@[3'u8]))))
    check Abi.encode(value) ==
      31.zeroes & 1'u8 &  # value[0].a
      31.zeroes & 64'u8 & # offset to value[1] (2 * 32 bytes)
      31.zeroes & 32'u8 & # offset to value[1].a
      31.zeroes & 2'u8 &  # value[1].a[0]
      31.zeroes & 64'u8 & # offset to value[1].a[1] (2 * 32 bytes)
      31.zeroes & 1'u8 &  # value[1].a[1] length
      3'u8 & 31.zeroes    # value[1].a[1] data

  test "encodes arrays":
    let a, b = FixedBytes[32](randomBytes[32]())
    check Abi.encode([a, b]) ==
      Abi.encode((a, b)) # Encode as tuple because fixed arrays are static.
    check encode([a, b]) == @(a.data) & @(b.data)

  test "encodes openArray":
    let a = [1'u8, 2'u8, 3'u8, 4'u8, 5'u8]
    check encode(DynBytes(a[1..3])) ==
      Abi.encode(3'u64) & @[2'u8, 3'u8, 4'u8] & 29.zeroes # [2, 3, 4, ..., 0, 0]

  test "encodes sequences":
    let a, b = @[FixedBytes[32](randomBytes[32]())]
    #
    check Abi.encode(@[a, b]) ==
      Abi.encode(2'u64) &   # sequence length
      Abi.encode( (a, b) )  # encode as tuple because sequences are dynamic.

  test "encodes sequence as dynamic element":
    let s = @[42.u256, 43.u256]
    check Abi.encode( (s,) ) ==
      Abi.encode(32'u8) & # offset in tuple
      Abi.encode(s)

  test "encodes nested sequence":
    let nestedSeq = @[
      DynBytes(@[1'u8, 2'u8]),
      DynBytes(@[3'u8, 4'u8, 5'u8])]
    check Abi.encode(nestedSeq) ==
      Abi.encode(2'u64) &
      Abi.encode(2 * 32'u64) &
      Abi.encode(4 * 32'u64) &
      Abi.encode(DynBytes(@[1'u8, 2'u8])) &
      Abi.encode(DynBytes(@[3'u8, 4'u8, 5'u8]))
    check Abi.encode(nestedSeq) ==
      31.zeroes & 2'u8 &                                 # sequence length
      31.zeroes & 64'u8 &                                # offset to first item (2 offsets)
      31.zeroes & 128'u8 &                               # offset to second item (first offset + length + data length)
      31.zeroes & 2'u8 & @[1'u8, 2'u8] & 30.zeroes &     # first item (length + data)
      31.zeroes & 3'u8 & @[3'u8, 4'u8, 5'u8] & 29.zeroes # second item (length + data)

  test "encodes sequence of static arrays":
    let a = @[[1'u16, 2'u16], [3'u16, 4'u16]]
    check Abi.encode(a) ==
      Abi.encode(2'u64) &
      Abi.encode(a[0]) &
      Abi.encode(a[1])
    check Abi.encode( (a,) ) ==
      31.zeroes & 32'u8 & # offset to a
      31.zeroes & 2'u8 &  # a length
      31.zeroes & 1'u8 &  # a[0][0]
      31.zeroes & 2'u8 &  # a[0][1]
      31.zeroes & 3'u8 &  # a[1][0]
      31.zeroes & 4'u8    # a[1][1]

  test "encodes seq of empty seqs":
    let empty: seq[int] =  @[]
    let v: seq[seq[int]] = @[ empty, empty ]
    check Abi.encode(v) ==
      Abi.encode(2'u64) &
      Abi.encode(2 * 32'u64) &
      Abi.encode(2 * 32'u64 + Abi.encode(empty).len.uint64) &
      Abi.encode(empty) &
      Abi.encode(empty)
    check Abi.encode(v) ==
      31.zeroes & 2'u8 &   # sequence length
      31.zeroes & 64'u8 &  # offset to first item (2 offsets)
      31.zeroes & 96'u8 &  # offset to second item (first offset + zero length)
      32.zeroes         &  # empty sequence
      32.zeroes            # empty sequence

  test "encodes DynamicBytes":
    # [0, high(int)]: https://github.com/nim-lang/Nim/issues/26336
    let bytes3 = DynamicBytes[0, high(int)](@[1'u8, 2'u8, 3'u8])
    check Abi.encode(bytes3) ==
      Abi.encode(3'u64) & # data length right-padded with zeroes
      bytes3.data & 29.zeroes

    let bytes32 = DynamicBytes[0, high(int)](@(randomBytes[32]()))
    check Abi.encode(bytes32) ==
      Abi.encode(32'u64) & # data length
        bytes32.data

    let bytes33 = DynamicBytes[0, high(int)](@(randomBytes[33]()))
    check Abi.encode(bytes33) ==
      Abi.encode(33'u64) & # data length right-padded with zeroes
        bytes33.data & 31.zeroes

  test "encodes array of static elements as static element":
    let a = [FixedBytes[1]([42'u8]), FixedBytes[1]([43'u8])]
    check Abi.encode( (a,) ) ==
      Abi.encode(a) # The tuple encoding does not add offset for static elements (fixed length array).

  test "encodes array of dynamic elements as dynamic element":
    let a = [DynBytes(@[42'u8]), DynBytes(@[43'u8])]
    check Abi.encode( (a,) ) ==
      Abi.encode(32'u8) & # offset in tuple
      Abi.encode(a)

  test "encodes strings as UTF-8 byte sequence":
    check Abi.encode("hello!☺") == Abi.encode(DynBytes("hello!☺".toBytes))

  test "encodes empty strings":
    let encoded = Abi.encode("")
    check encoded == Abi.encode(0'u64)
    check encoded == 32.zeroes

  test "encodes distinct types as their base type":
    type SomeDistinctType = distinct uint16
    let value = 0xAABB'u16
    check Abi.encode(SomeDistinctType(value)) == Abi.encode(value)

    type
      DistinctArray = distinct array[2, uint16]
      DistinctTuple = distinct (uint8, DynBytes)
      DistinctBytes = distinct DynBytes
    let a = [1'u16, 2'u16]
    let b = (3'u8, DynBytes(@[4'u8]))
    let c = DynBytes(@[5'u8])
    let distinctTuple = (DistinctArray(a), DistinctTuple(b), DistinctBytes(c))
    check Abi.encode(distinctTuple) == Abi.encode( (a, b, c) )
    check Abi.encode( (a, b, c) ) ==
      31.zeroes & 1'u8 &                    # a[0]
      31.zeroes & 2'u8 &                    # a[1]
      31.zeroes & 128'u8 &                  # offset to b (4 * 32 bytes)
      30.zeroes & 1'u8 & 0'u8 &             # offset to c (8 * 32 bytes)
      31.zeroes & 3'u8 &                    # b[0]
      31.zeroes & 64'u8 &                   # offset to b[1] (2 * 32 bytes)
      31.zeroes & 1'u8 & b[1] & 31.zeroes & # b[1] (length + data)
      31.zeroes & 1'u8 & c & 31.zeroes      # c (length + data)

  test "encodes zero values":
    check Abi.encode(UInt256.zero) == 32.zeroes
    check Abi.encode(UInt256.zero) == 32.zeroes
    check Abi.encode(DynBytes(@[0'u8, 0'u8])) ==
      Abi.encode(2'u64) & @[0'u8, 0'u8] & 30.zeroes

  test "encodes large arrays":
    let largeArray = newSeqWith(100, 42'u8)
    let encoded = Abi.encode(largeArray)
    check encoded[0..31] == Abi.encode(100'u64)

  test "encodes very long strings":
    let longString = "a".repeat(1000)
    let encoded = Abi.encode(longString)
    check encoded[0..31] == Abi.encode(1000'u64)
