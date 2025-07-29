import 
    std/unittest,
    std/sequtils,
    std/random,
    stint,
    stew/[byteutils],
    ../web3/encoding,
    ../web3/eth_api_types,
    ./helpers/primitives_utils

suite "ABI encoding":
  proc zeroes(amount: int): seq[byte] =
    newSeq[byte](amount)

  proc randomBytes[N: static int](): array[N, byte] =
    var a: array[N, byte]
    for b in a.mitems:
        b = rand(byte)
    return a

  test "encodes uint8":
    check AbiEncoder.encode(42'u8) == 31.zeroes & 42'u8 # [0, 0, ..., 0, 2a] (2a = 42)

  test "encodes booleans":
    check AbiEncoder.encode(false) == 31.zeroes & 0'u8 # [0, 0, ..., 0, 0]
    check AbiEncoder.encode(true) == 31.zeroes & 1'u8 # [0, 0, ..., 0, 1]

  test "encodes uint16, 32, 64":
    check AbiEncoder.encode(0xABCD'u16) ==
      30.zeroes & 0xAB'u8 & 0xCD'u8
    check AbiEncoder.encode(0x11223344'u32) ==
      28.zeroes & 0x11'u8 & 0x22'u8 & 0x33'u8 & 0x44'u8
    check AbiEncoder.encode(0x1122334455667788'u64) ==
      24.zeroes &
      0x11'u8 & 0x22'u8 & 0x33'u8 & 0x44'u8 &
      0x55'u8 & 0x66'u8 & 0x77'u8 & 0x88'u8

  test "encodes int8, 16, 32, 64":
    check AbiEncoder.encode(1'i8) == 31.zeroes & 0x01'u8  # [0, 0, ..., 0, 1]
    check AbiEncoder.encode(1'i16) == 31.zeroes & 0x01'u8 # [0, 0, ..., 0, 1]
    check AbiEncoder.encode(1'i32) == 31.zeroes & 0x01'u8 # [0, 0, ..., 0, 1]
    check AbiEncoder.encode(1'i64) == 31.zeroes & 0x01'u8 # [0, 0, ..., 0, 1]

    check AbiEncoder.encode(-1'i8) == 0xFF'u8.repeat(32)  # [255, 255, ..., 255] (signed value)
    check AbiEncoder.encode(-1'i16) == 0xFF'u8.repeat(32) # [255, 255, ..., 255] (signed value)
    check AbiEncoder.encode(-1'i32) == 0xFF'u8.repeat(32) # [255, 255, ..., 255] (signed value)
    check AbiEncoder.encode(-1'i64) == 0xFF'u8.repeat(32) # [255, 255, ..., 255] (signed value)

  test "encodes ranges":
    type SomeRange = range[0x0000'u16..0xAAAA'u16]
    check AbiEncoder.encode(SomeRange(0x1122)) == 30.zeroes & 0x11'u8 & 0x22'u8

  test "encodes enums":
    type SomeEnum = enum
      one = 1
      two = 2
    check AbiEncoder.encode(one) == 31.zeroes & 1'u8 # [0, 0, ..., 0, 1]
    check AbiEncoder.encode(two) == 31.zeroes & 2'u8 # [0, 0, ..., 0, 2]

  test "encodes stints":
    let uint256 = UInt256.fromBytes(randomBytes[32](), bigEndian)
    let uint128 = UInt128.fromBytes(randomBytes[32](), bigEndian)
    check AbiEncoder.encode(uint256) == @(uint256.toBytesBE)
    check AbiEncoder.encode(uint128) == 16.zeroes & @(uint128.toBytesBE)

    check AbiEncoder.encode(1.i256) == 31.zeroes & 0x01'u8 # [0, 0, ..., 0, 1]
    check AbiEncoder.encode(1.i128) == 31.zeroes & 0x01'u8 # [0, 0, ..., 0, 1]

    check AbiEncoder.encode(-1.i256) == 0xFF'u8.repeat(32) # [255, 255, ..., 255] (signed value)
    check AbiEncoder.encode(-1.i128) == 0xFF'u8.repeat(32) # [255, 255, ..., 255] (signed value)

  test "encodes addresses":
    let address = address(3)
    check AbiEncoder.encode(address) == 12.zeroes & @(array[20, byte](address))

  test "encodes hashes":
    let hash = txhash(3)
    check AbiEncoder.encode(hash) == @(array[32, byte](hash))

  test "encodes FixedBytes":
    let bytes3 = FixedBytes[3]([1'u8, 2'u8, 3'u8])
    check AbiEncoder.encode(bytes3) == @[1'u8, 2'u8, 3'u8] & 29.zeroes # Fixed array are right-padded with zeroes

    let bytes32 = FixedBytes[32](randomBytes[32]())
    check AbiEncoder.encode(bytes32) == @(bytes32.data)

    let bytes33 = FixedBytes[33](randomBytes[33]())
    check AbiEncoder.encode(bytes33) == @(bytes33.data) & 31.zeroes # Right-padded with another 32 zeroes

  test "encodes byte arrays":
    let bytes3 = [1'u8, 2'u8, 3'u8]
    check AbiEncoder.encode(bytes3) == @bytes3 & 29.zeroes # Fixed array are right-padded with zeroes.

    let bytes32 = randomBytes[32]()
    check AbiEncoder.encode(bytes32) == @bytes32

    let bytes33 =randomBytes[33]()
    check AbiEncoder.encode(bytes33) == @bytes33 & 31.zeroes # Right-padded with another 32 zeroes

  test "encodes byte sequences":
    let bytes3 = @[1'u8, 2'u8, 3'u8]
    let bytes3len = AbiEncoder.encode(bytes3.len.uint64)
    check AbiEncoder.encode(bytes3) == bytes3len & bytes3 & 29.zeroes
    check AbiEncoder.encode(bytes3) ==
      31.zeroes & 3'u8 & # [0, 0, ..., 0, 3] (length)
      bytes3 & 29.zeroes # [1, 2, 3, 0, ..., 0] (data)

    let bytes32 = @(randomBytes[32]())
    let bytes32len = AbiEncoder.encode(bytes32.len.uint64)
    check AbiEncoder.encode(bytes32) == bytes32len & bytes32

    let bytes33 = @(randomBytes[33]())
    let bytes33len = AbiEncoder.encode(bytes33.len.uint64)
    check AbiEncoder.encode(bytes33) == bytes33len & bytes33 & 31.zeroes

  test "encodes empty seq of seq":
    let v: seq[seq[int]] = @[]
    check AbiEncoder.encode(v) == AbiEncoder.encode(0'u64)
    check AbiEncoder.encode(v) == 32.zeroes # Encode the size only (zero)

  test "encodes tuples":
    let a = true
    let b = @[1'u8, 2'u8, 3'u8]
    let c = 0xAABBCCDD'u32
    let d = @[4'u8, 5'u8, 6'u8]
    check AbiEncoder.encode( (a, b, c, d) ) ==
      AbiEncoder.encode(a) &
      AbiEncoder.encode(4 * 32'u8) &
      AbiEncoder.encode(c) &
      AbiEncoder.encode(6 * 32'u8) &
      AbiEncoder.encode(b) &
      AbiEncoder.encode(d)
    check AbiEncoder.encode( (a, b, c, d) ) ==
      31.zeroes & 1'u8 &                          # boolean value
      31.zeroes & 128'u8 &                        # offset to b (4 (bool, offset, int, offset) * 32 bytes)
      28.zeroes & 0xAA'u8 & 0xBB & 0xCC & 0xDD &
      31.zeroes & 192'u8 &                        # offset to d ((4 + b length + b data) * 32 bytes)
      31.zeroes & 3'u8 & b & 29.zeroes &          # b (length + data)
      31.zeroes & 3'u8 & d & 29.zeroes            # d (length + data)

  test "encodes nested tuples":
    let a = true
    let b = @[1'u8, 2'u8, 3'u8]
    let c = 0xAABBCCDD'u32
    let d = @[4'u8, 5'u8, 6'u8]
    check AbiEncoder.encode( (a, b, (c, d)) ) ==
      AbiEncoder.encode(a) &
      AbiEncoder.encode(3 * 32'u8) & # offset of b in outer tuple
      AbiEncoder.encode(5 * 32'u8) & # offset of inner tuple in outer tuple
      AbiEncoder.encode(b) &
      AbiEncoder.encode(c) &
      AbiEncoder.encode(2 * 32'u8) & # offset of d in inner tuple
      AbiEncoder.encode(d)
    check AbiEncoder.encode( (a, b, (c, d)) ) ==
      31.zeroes & 1'u8 &                            # boolean value
      31.zeroes & 96'u8 &                           # offset to b ((bool, offset, tuple) * 32 bytes)
      31.zeroes & 160'u8 &                          # offset to tuple ((3 + b length + b data) * 32 bytes)
      31.zeroes & 3'u8 & b & 29.zeroes &            # b (length + data)
      28.zeroes & 0xAA'u8 & 0xBB & 0xCC & 0xDD &
      31.zeroes & 64'u8 &                           # offset to d ((static + offset) * 32 bytes)
      31.zeroes & 3'u8 & d & 29.zeroes              # d (length + data)

  test "encodes tuple with only dynamic fields":
    let t = (@[1'u8, 2'u8], @[3'u8, 4'u8])
    check AbiEncoder.encode(t) ==
      AbiEncoder.encode(2 * 32'u64) &
      AbiEncoder.encode(4 * 32'u64) &
      AbiEncoder.encode(@[1'u8, 2'u8]) &
      AbiEncoder.encode(@[3'u8, 4'u8])
    check AbiEncoder.encode(t) ==
      31.zeroes & 64'u8 &                            # offset to first
      31.zeroes & 128'u8 &                           # offset to second (first offset + length encoding + data length)
      31.zeroes & 2'u8 & @[1'u8, 2'u8] & 30.zeroes & # first element (length + data)
      31.zeroes & 2'u8 & @[3'u8, 4'u8] & 30.zeroes   # second element (length + data)

  test "encodes tuple with empty dynamic fields":
    var empty: seq[byte] = @[]
    let t = (empty, empty)
    check AbiEncoder.encode(t) ==
      AbiEncoder.encode(2 * 32'u64) &
      AbiEncoder.encode(2 * 32'u64 + AbiEncoder.encode(empty).len.uint64) &
      AbiEncoder.encode(empty) &
      AbiEncoder.encode(empty)
    check AbiEncoder.encode(t) ==
      31.zeroes & 64'u8 &  # offset to first
      31.zeroes & 96'u8 &  # offset to second (first offset + length encoding + data length)
      32.zeroes &          # empty sequence
      32.zeroes            # empty sequence

  test "encodes tuple with static and empty dynamic":
    var empty: seq[byte] = @[]
    let t = (42'u8, empty)
    check AbiEncoder.encode(t) ==
      AbiEncoder.encode(42'u8) &
      AbiEncoder.encode(2 * 32'u64) &
      AbiEncoder.encode(empty)
    check AbiEncoder.encode(t) ==
      31.zeroes & 42'u8 & # int left-padded with zeroes
      31.zeroes & 64'u8 & # offset to empty (static + offset)
      32.zeroes           # empty sequence

  test "encodes arrays":
    let a, b = randomBytes[32]()
    check AbiEncoder.encode([a, b]) ==
      AbiEncoder.encode((a, b)) # Encode as tuple because fixed arrays are static.

  test "encodes openArray":
    let a = [1'u8, 2'u8, 3'u8, 4'u8, 5'u8]
    check encode(a[1..3]) ==
      AbiEncoder.encode(3'u64) & @[2'u8, 3'u8, 4'u8] & 29.zeroes # [2, 3, 4, ..., 0, 0]

  test "encodes sequences":
    let a, b = @[randomBytes[32]()]
    #
    check AbiEncoder.encode(@[a, b]) ==
      AbiEncoder.encode(2'u64) &   # sequence length
      AbiEncoder.encode( (a, b) )  # encode as tuple because sequences are dynamic.

  test "encodes sequence as dynamic element":
    let s = @[42.u256, 43.u256]
    check AbiEncoder.encode( (s,) ) ==
      AbiEncoder.encode(32'u8) & # offset in tuple
      AbiEncoder.encode(s)

  test "encodes nested sequence":
    let nestedSeq = @[ @[1'u8, 2'u8], @[3'u8, 4'u8, 5'u8] ]
    check AbiEncoder.encode(nestedSeq) ==
      AbiEncoder.encode(2'u64) &
      AbiEncoder.encode(2 * 32'u64) &
      AbiEncoder.encode(4 * 32'u64) &
      AbiEncoder.encode(@[1'u8, 2'u8]) &
      AbiEncoder.encode(@[3'u8, 4'u8, 5'u8])
    check AbiEncoder.encode(nestedSeq) ==
      31.zeroes & 2'u8 &                                 # sequence length
      31.zeroes & 64'u8 &                                # offset to first item (2 offsets)
      31.zeroes & 128'u8 &                               # offset to second item (first offset + length + data length)
      31.zeroes & 2'u8 & @[1'u8, 2'u8] & 30.zeroes &     # first item (length + data)
      31.zeroes & 3'u8 & @[3'u8, 4'u8, 5'u8] & 29.zeroes # second item (length + data)

  test "encodes seq of empty seqs":
    let empty: seq[int] =  @[]
    let v: seq[seq[int]] = @[ empty, empty ]
    let expected =
      AbiEncoder.encode(2'u64) &
      AbiEncoder.encode(2 * 32'u64) &
      AbiEncoder.encode(2 * 32'u64 + AbiEncoder.encode(empty).len.uint64) &
      AbiEncoder.encode(empty) &
      AbiEncoder.encode(empty)
    check AbiEncoder.encode(v) ==
      31.zeroes & 2'u8 &   # sequence length
      31.zeroes & 64'u8 &  # offset to first item (2 offsets)
      31.zeroes & 96'u8 &  # offset to second item (first offset + zero length)
      32.zeroes         &  # empty sequence
      32.zeroes            # empty sequence

  test "encodes DynamicBytes":
    let bytes3 = DynamicBytes(@[1'u8, 2'u8, 3'u8])
    check AbiEncoder.encode(bytes3) ==
      AbiEncoder.encode(3'u64) & # data length right-padded with zeroes
      bytes3.data & 29.zeroes

    let bytes32 = DynamicBytes(@(randomBytes[32]()))
    check AbiEncoder.encode(bytes32) ==
      AbiEncoder.encode(32'u64) & # data length
        bytes32.data

    let bytes33 = DynamicBytes(@(randomBytes[33]()))
    check AbiEncoder.encode(bytes33) ==
      AbiEncoder.encode(33'u64) & # data length right-padded with zeroes
        bytes33.data & 31.zeroes

  test "encodes array of static elements as static element":
    let a = [[42'u8], [43'u8]]
    check AbiEncoder.encode( (a,) ) ==
      AbiEncoder.encode(a) # The tuple encoding does not add offset for static elements (fixed length array).

  test "encodes array of dynamic elements as dynamic element":
    let a = [@[42'u8], @[43'u8]]
    check AbiEncoder.encode( (a,) ) ==
      AbiEncoder.encode(32'u8) & # offset in tuple
      AbiEncoder.encode(a)

  test "encodes strings as UTF-8 byte sequence":
    check AbiEncoder.encode("hello!☺") == AbiEncoder.encode("hello!☺".toBytes)
    check encode("hello!☺") == encode("hello!☺".toBytes)

  test "encodes distinct types as their base type":
    type SomeDistinctType = distinct uint16
    let value = 0xAABB'u16
    check AbiEncoder.encode(SomeDistinctType(value)) == AbiEncoder.encode(value)

  test "encodes zero values":
    check AbiEncoder.encode(UInt256.zero) == 32.zeroes
    check AbiEncoder.encode(UInt256.zero) == 32.zeroes
    check AbiEncoder.encode(@[0'u8, 0'u8]) == 
      AbiEncoder.encode(2'u64) & @[0'u8, 0'u8] & 30.zeroes

  test "encodes large arrays":
    let largeArray = newSeqWith(100, 42'u8)
    let encoded = AbiEncoder.encode(largeArray)
    check encoded[0..31] == AbiEncoder.encode(100'u64) 

  test "encodes very long strings":
    let longString = "a".repeat(1000)
    let encoded = AbiEncoder.encode(longString)
    check encoded[0..31] == AbiEncoder.encode(1000'u64)