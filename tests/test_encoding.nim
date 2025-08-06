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
    return a

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

    check Abi.encode(1.i256) == 31.zeroes & 0x01'u8 # [0, 0, ..., 0, 1]
    check Abi.encode(1.i128) == 31.zeroes & 0x01'u8 # [0, 0, ..., 0, 1]

    check Abi.encode(-1.i256) == 0xFF'u8.repeat(32) # [255, 255, ..., 255] (signed value)
    check Abi.encode(-1.i128) == 0xFF'u8.repeat(32) # [255, 255, ..., 255] (signed value)

  test "encodes addresses":
    let address = address(3)
    check Abi.encode(address) == 12.zeroes & @(array[20, byte](address))

  test "encodes hashes":
    let hash = txhash(3)
    check Abi.encode(hash) == @(array[32, byte](hash))

  test "encodes FixedBytes":
    let bytes3 = FixedBytes[3]([1'u8, 2'u8, 3'u8])
    check Abi.encode(bytes3) == @[1'u8, 2'u8, 3'u8] & 29.zeroes # Fixed array are right-padded with zeroes

    let bytes32 = FixedBytes[32](randomBytes[32]())
    check Abi.encode(bytes32) == @(bytes32.data)

    let bytes33 = FixedBytes[33](randomBytes[33]())
    check Abi.encode(bytes33) == @(bytes33.data) & 31.zeroes # Right-padded with another 32 zeroes

  test "encodes byte arrays":
    let bytes3 = [1'u8, 2'u8, 3'u8]
    check Abi.encode(bytes3) == @bytes3 & 29.zeroes # Fixed array are right-padded with zeroes.

    let bytes32 = randomBytes[32]()
    check Abi.encode(bytes32) == @bytes32

    let bytes33 =randomBytes[33]()
    check Abi.encode(bytes33) == @bytes33 & 31.zeroes # Right-padded with another 32 zeroes

  test "encodes byte sequences":
    let bytes3 = @[1'u8, 2'u8, 3'u8]
    let bytes3len = Abi.encode(bytes3.len.uint64)
    check Abi.encode(bytes3) == bytes3len & bytes3 & 29.zeroes
    check Abi.encode(bytes3) ==
      31.zeroes & 3'u8 & # [0, 0, ..., 0, 3] (length)
      bytes3 & 29.zeroes # [1, 2, 3, 0, ..., 0] (data)

    let bytes32 = @(randomBytes[32]())
    let bytes32len = Abi.encode(bytes32.len.uint64)
    check Abi.encode(bytes32) == bytes32len & bytes32

    let bytes33 = @(randomBytes[33]())
    let bytes33len = Abi.encode(bytes33.len.uint64)
    check Abi.encode(bytes33) == bytes33len & bytes33 & 31.zeroes

  test "encodes empty seq of seq":
    let v: seq[seq[int]] = @[]
    check Abi.encode(v) == Abi.encode(0'u64)
    check Abi.encode(v) == 32.zeroes # Encode the size only (zero)

  test "encodes tuples":
    let a = true
    let b = @[1'u8, 2'u8, 3'u8]
    let c = 0xAABBCCDD'u32
    let d = @[4'u8, 5'u8, 6'u8]
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
    let b = @[1'u8, 2'u8, 3'u8]
    let c = 0xAABBCCDD'u32
    let d = @[4'u8, 5'u8, 6'u8]
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

  test "encodes tuple with only dynamic fields":
    let t = (@[1'u8, 2'u8], @[3'u8, 4'u8])
    check Abi.encode(t) ==
      Abi.encode(2 * 32'u64) &
      Abi.encode(4 * 32'u64) &
      Abi.encode(@[1'u8, 2'u8]) &
      Abi.encode(@[3'u8, 4'u8])
    check Abi.encode(t) ==
      31.zeroes & 64'u8 &                            # offset to first
      31.zeroes & 128'u8 &                           # offset to second (first offset + length encoding + data length)
      31.zeroes & 2'u8 & @[1'u8, 2'u8] & 30.zeroes & # first element (length + data)
      31.zeroes & 2'u8 & @[3'u8, 4'u8] & 30.zeroes   # second element (length + data)

  test "encodes tuple with empty dynamic fields":
    var empty: seq[byte] = @[]
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
    var empty: seq[byte] = @[]
    let t = (42'u8, empty)
    check Abi.encode(t) ==
      Abi.encode(42'u8) &
      Abi.encode(2 * 32'u64) &
      Abi.encode(empty)
    check Abi.encode(t) ==
      31.zeroes & 42'u8 & # int left-padded with zeroes
      31.zeroes & 64'u8 & # offset to empty (static + offset)
      32.zeroes           # empty sequence

  test "encodes arrays":
    let a, b = randomBytes[32]()
    check Abi.encode([a, b]) ==
      Abi.encode((a, b)) # Encode as tuple because fixed arrays are static.

  test "encodes openArray":
    let a = [1'u8, 2'u8, 3'u8, 4'u8, 5'u8]
    check encode(a[1..3]) ==
      Abi.encode(3'u64) & @[2'u8, 3'u8, 4'u8] & 29.zeroes # [2, 3, 4, ..., 0, 0]

  test "encodes sequences":
    let a, b = @[randomBytes[32]()]
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
    let nestedSeq = @[ @[1'u8, 2'u8], @[3'u8, 4'u8, 5'u8] ]
    check Abi.encode(nestedSeq) ==
      Abi.encode(2'u64) &
      Abi.encode(2 * 32'u64) &
      Abi.encode(4 * 32'u64) &
      Abi.encode(@[1'u8, 2'u8]) &
      Abi.encode(@[3'u8, 4'u8, 5'u8])
    check Abi.encode(nestedSeq) ==
      31.zeroes & 2'u8 &                                 # sequence length
      31.zeroes & 64'u8 &                                # offset to first item (2 offsets)
      31.zeroes & 128'u8 &                               # offset to second item (first offset + length + data length)
      31.zeroes & 2'u8 & @[1'u8, 2'u8] & 30.zeroes &     # first item (length + data)
      31.zeroes & 3'u8 & @[3'u8, 4'u8, 5'u8] & 29.zeroes # second item (length + data)

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
    let bytes3 = DynamicBytes(@[1'u8, 2'u8, 3'u8])
    check Abi.encode(bytes3) ==
      Abi.encode(3'u64) & # data length right-padded with zeroes
      bytes3.data & 29.zeroes

    let bytes32 = DynamicBytes(@(randomBytes[32]()))
    check Abi.encode(bytes32) ==
      Abi.encode(32'u64) & # data length
        bytes32.data

    let bytes33 = DynamicBytes(@(randomBytes[33]()))
    check Abi.encode(bytes33) ==
      Abi.encode(33'u64) & # data length right-padded with zeroes
        bytes33.data & 31.zeroes

  test "encodes array of static elements as static element":
    let a = [[42'u8], [43'u8]]
    check Abi.encode( (a,) ) ==
      Abi.encode(a) # The tuple encoding does not add offset for static elements (fixed length array).

  test "encodes array of dynamic elements as dynamic element":
    let a = [@[42'u8], @[43'u8]]
    check Abi.encode( (a,) ) ==
      Abi.encode(32'u8) & # offset in tuple
      Abi.encode(a)

  test "encodes strings as UTF-8 byte sequence":
    check Abi.encode("hello!☺") == Abi.encode("hello!☺".toBytes)

  test "encodes empty strings":
    let encoded = Abi.encode("")
    check encoded == Abi.encode(0'u64)
    check encoded == 32.zeroes

  test "encodes distinct types as their base type":
    type SomeDistinctType = distinct uint16
    let value = 0xAABB'u16
    check Abi.encode(SomeDistinctType(value)) == Abi.encode(value)

  test "encodes zero values":
    check Abi.encode(UInt256.zero) == 32.zeroes
    check Abi.encode(UInt256.zero) == 32.zeroes
    check Abi.encode(@[0'u8, 0'u8]) ==
      Abi.encode(2'u64) & @[0'u8, 0'u8] & 30.zeroes

  test "encodes large arrays":
    let largeArray = newSeqWith(100, 42'u8)
    let encoded = Abi.encode(largeArray)
    check encoded[0..31] == Abi.encode(100'u64)

  test "encodes very long strings":
    let longString = "a".repeat(1000)
    let encoded = Abi.encode(longString)
    check encoded[0..31] == Abi.encode(1000'u64)