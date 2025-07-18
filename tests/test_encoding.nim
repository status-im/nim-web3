
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

  proc randomSeq(): seq[byte] =
    let length = rand(0..<20)
    newSeqWith(length, rand(byte)) 

  test "encodes uint8":
    check AbiEncoder.encode(42'u8) == 31.zeroes & 42'u8

  test "encodes booleans":
    check AbiEncoder.encode(false) == 31.zeroes & 0'u8
    check AbiEncoder.encode(true) == 31.zeroes & 1'u8

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
    check AbiEncoder.encode(1'i8) == 31.zeroes & 0x01'u8
    check AbiEncoder.encode(-1'i8) == 0xFF'u8.repeat(32)
    check AbiEncoder.encode(1'i16) == 31.zeroes & 0x01'u8
    check AbiEncoder.encode(-1'i16) == 0xFF'u8.repeat(32)
    check AbiEncoder.encode(1'i32) == 31.zeroes & 0x01'u8
    check AbiEncoder.encode(-1'i32) == 0xFF'u8.repeat(32)
    check AbiEncoder.encode(1'i64) == 31.zeroes & 0x01'u8
    check AbiEncoder.encode(-1'i64) == 0xFF'u8.repeat(32)

  test "encodes ranges":
    type SomeRange = range[0x0000'u16..0xAAAA'u16]
    check AbiEncoder.encode(SomeRange(0x1122)) == 30.zeroes & 0x11'u8 & 0x22'u8

  test "encodes enums":
    type SomeEnum = enum
      one = 1
      two = 2
    check AbiEncoder.encode(one) == 31.zeroes & 1'u8
    check AbiEncoder.encode(two) == 31.zeroes & 2'u8

  test "encodes stints":
    let uint256 = UInt256.fromBytes(randomBytes[32](), bigEndian)
    let uint128 = UInt128.fromBytes(randomBytes[32](), bigEndian)
    check AbiEncoder.encode(uint256) == @(uint256.toBytesBE)
    check AbiEncoder.encode(uint128) == 16.zeroes & @(uint128.toBytesBE)
    check AbiEncoder.encode(1.i256) == 31.zeroes & 0x01'u8
    check AbiEncoder.encode(1.i128) == 31.zeroes & 0x01'u8
    check AbiEncoder.encode(-1.i256) == 0xFF'u8.repeat(32)
    check AbiEncoder.encode(-1.i128) == 0xFF'u8.repeat(32)

  test "encodes addresses":
    let address = address(3)
    check AbiEncoder.encode(address) == 12.zeroes & @(array[20, byte](address))

  test "encodes hashes":
    let hash =  txhash(3)
    check AbiEncoder.encode(hash) == @(array[32, byte](hash))

  test "encodes byte arrays":
    let bytes3 = [1'u8, 2'u8, 3'u8]
    check AbiEncoder.encode(bytes3) == @bytes3 & 29.zeroes
    let bytes32 = randomBytes[32]()
    check AbiEncoder.encode(bytes32) == @bytes32
    let bytes33 =randomBytes[33]()
    check AbiEncoder.encode(bytes33) == @bytes33 & 31.zeroes

  test "encodes byte sequences":
    let bytes3 = @[1'u8, 2'u8, 3'u8]
    let bytes3len = AbiEncoder.encode(bytes3.len.uint64)
    check AbiEncoder.encode(bytes3) == bytes3len & bytes3 & 29.zeroes
    let bytes32 = @(randomBytes[32]())
    let bytes32len = AbiEncoder.encode(bytes32.len.uint64)
    check AbiEncoder.encode(bytes32) == bytes32len & bytes32
    let bytes33 = @(randomBytes[33]())
    let bytes33len = AbiEncoder.encode(bytes33.len.uint64)
    check AbiEncoder.encode(bytes33) == bytes33len & bytes33 & 31.zeroes

  test "encodes tuples":
    let a = true
    let b = @[1'u8, 2'u8, 3'u8]
    let c = 0xAABBCCDD'u32
    let d = @[4'u8, 5'u8, 6'u8]
    check AbiEncoder.encode( (a, b, c, d) ) ==
      AbiEncoder.encode(a) &
      AbiEncoder.encode(4 * 32'u8) & # offset in tuple
      AbiEncoder.encode(c) &
      AbiEncoder.encode(6 * 32'u8) & # offset in tuple
      AbiEncoder.encode(b) &
      AbiEncoder.encode(d)

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

  test "encodes arrays":
    let a, b = randomSeq()
    check AbiEncoder.encode([a, b]) == AbiEncoder.encode( (a,b) )

  test "encodes sequences":
    let a, b = randomSeq()
    check AbiEncoder.encode(@[a, b]) ==
      AbiEncoder.encode(2'u64) &
      AbiEncoder.encode( (a, b) )

  test "encodes sequence as dynamic element":
    let s = @[42.u256, 43.u256]
    check AbiEncoder.encode( (s,) ) ==
      AbiEncoder.encode(32'u8) & # offset in tuple
      AbiEncoder.encode(s)

  test "encodes array of static elements as static element":
    let a = [[42'u8], [43'u8]]
    check AbiEncoder.encode( (a,) ) == AbiEncoder.encode(a)

  test "encodes array of dynamic elements as dynamic element":
    let a = [@[42'u8], @[43'u8]]
    check AbiEncoder.encode( (a,) ) ==
      AbiEncoder.encode(32'u8) & # offset in tuple
      AbiEncoder.encode(a)

  test "encodes strings as UTF-8 byte sequence":
    check AbiEncoder.encode("hello!☺") == AbiEncoder.encode("hello!☺".toBytes)

  test "encodes distinct types as their base type":
    type SomeDistinctType = distinct uint16
    let value = 0xAABB'u16
    check AbiEncoder.encode(SomeDistinctType(value)) == AbiEncoder.encode(value)

  test "can determine whether types are dynamic or static":
    check static AbiEncoder.isStatic(uint8)
    check static AbiEncoder.isDynamic(seq[byte])
    check static AbiEncoder.isStatic(array[2, array[2, byte]])
    check static AbiEncoder.isDynamic(array[2, seq[byte]])

  test "encodes mixed static/dynamic tuple":
    let staticPart = 123'u32
    let dynamicPart = @[1'u8, 2'u8, 3'u8, 4'u8, 5'u8]
    let anotherStatic = true
    check AbiEncoder.encode((staticPart, dynamicPart, anotherStatic)) ==
      AbiEncoder.encode(staticPart) &
      AbiEncoder.encode(3 * 32'u8) &
      AbiEncoder.encode(anotherStatic) &
      AbiEncoder.encode(dynamicPart)

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