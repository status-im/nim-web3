# nim-web3
# Copyright (c) 2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/macros,
  stint, ./eth_api_types, stew/[assign2, byteutils, endians2]

type
  AbiEncoder* = object
    stack: seq[Tuple]
  Tuple = object
    bytes: seq[byte]
    postponed: seq[Split]
    dynamic: bool
  Split = object
    head: Slice[int]
    tail: seq[byte]

func write*[T](encoder: var AbiEncoder, value: T)
func encode*[T](_: type AbiEncoder, value: T): seq[byte]

func init(_: type AbiEncoder): AbiEncoder =
  AbiEncoder(stack: @[Tuple()])

func append(tupl: var Tuple, bytes: openArray[byte]) =
  tupl.bytes.add(bytes)

func postpone(tupl: var Tuple, bytes: seq[byte]) =
  var split: Split
  split.head.a = tupl.bytes.len
  tupl.append(AbiEncoder.encode(0'u64))
  split.head.b = tupl.bytes.high
  split.tail = bytes
  tupl.postponed.add(split)

func finish(tupl: Tuple): seq[byte] =
  var bytes = tupl.bytes
  for split in tupl.postponed:
    let offset = bytes.len
    bytes[split.head] = AbiEncoder.encode(offset.uint64)
    bytes.add(split.tail)
  bytes

func append(encoder: var AbiEncoder, bytes: openArray[byte]) =
  encoder.stack[^1].append(bytes)

func postpone(encoder: var AbiEncoder, bytes: seq[byte]) =
  if encoder.stack.len > 1:
    encoder.stack[^1].postpone(bytes)
  else:
    encoder.stack[0].append(bytes)

func setDynamic(encoder: var AbiEncoder) =
  encoder.stack[^1].dynamic = true

func startTuple*(encoder: var AbiEncoder) =
  encoder.stack.add(Tuple())

func encode(encoder: var AbiEncoder, tupl: Tuple) =
  if tupl.dynamic:
    encoder.postpone(tupl.finish())
    encoder.setDynamic()
  else:
    encoder.append(tupl.finish())

func finishTuple*(encoder: var AbiEncoder) =
  encoder.encode(encoder.stack.pop())

func pad(encoder: var AbiEncoder, len: int, padding=0'u8) =
  let padlen = (32 - len mod 32) mod 32
  for _ in 0..<padlen:
    encoder.append([padding])

func padleft(encoder: var AbiEncoder, bytes: openArray[byte], padding=0'u8) =
  encoder.pad(bytes.len, padding)
  encoder.append(bytes)

func padright(encoder: var AbiEncoder, bytes: openArray[byte], padding=0'u8) =
  encoder.append(bytes)
  encoder.pad(bytes.len, padding)

func encode(encoder: var AbiEncoder, value: SomeUnsignedInt | StUint) =
  encoder.padleft(value.toBytesBE)

func encode(encoder: var AbiEncoder, value: SomeSignedInt) =
  type unsignedType = (type value).toUnsigned
  let unsignedValue = cast[unsignedType](value)
  let bytes = unsignedValue.toBytesBE
  let padding = if value < 0: 0xFF'u8 else: 0x00'u8
  encoder.padleft(bytes, padding)

func encode(encoder: var AbiEncoder, value: StInt) =
  type unsignedType = StUint[(type value).bits]
  let unsignedValue = cast[unsignedType](value)
  let bytes = unsignedValue.toBytesBE
  let padding = if value.isNegative: 0xFF'u8 else: 0x00'u8
  encoder.padleft(bytes, padding)

func encode(encoder: var AbiEncoder, value: bool) =
  encoder.encode(if value: 1'u8 else: 0'u8)

func encode(encoder: var AbiEncoder, value: enum) =
  encoder.encode(uint64(ord(value)))

func encode(encoder: var AbiEncoder, value: Address) =
  encoder.padleft(array[20, byte](value))

func encode(encoder: var AbiEncoder, value: Bytes32) =
  encoder.padleft(array[32, byte](value))

func encode[I](encoder: var AbiEncoder, bytes: array[I, byte]) =
  encoder.padright(bytes)

func encode(encoder: var AbiEncoder, bytes: seq[byte]) =
  encoder.encode(bytes.len.uint64)
  encoder.padright(bytes)
  encoder.setDynamic()

func encode[I, T](encoder: var AbiEncoder, value: array[I, T]) =
  encoder.startTuple()
  for element in value:
    encoder.write(element)
  encoder.finishTuple()

func encode[T](encoder: var AbiEncoder, value: seq[T]) =
  encoder.encode(value.len.uint64)
  encoder.startTuple()
  for element in value:
    encoder.write(element)
  encoder.finishTuple()
  encoder.setDynamic()

func encode(encoder: var AbiEncoder, value: string) =
  encoder.encode(value.toBytes)

func encode(encoder: var AbiEncoder, tupl: tuple) =
  encoder.startTuple()
  for element in tupl.fields:
    encoder.write(element)
  encoder.finishTuple()

func encode(encoder: var AbiEncoder, value: distinct) =
  type Base = distinctBase(typeof(value))
  encoder.write(Base(value))

func finish(encoder: var AbiEncoder): Tuple =
  doAssert encoder.stack.len == 1, "not all tuples were finished"
  doAssert encoder.stack[0].bytes.len mod 32 == 0, "encoding invariant broken"
  encoder.stack[0]

func write*[T](encoder: var AbiEncoder, value: T) =
  var writer = AbiEncoder.init()
  writer.encode(value)
  encoder.encode(writer.finish())

func encode*[T](_: type AbiEncoder, value: T): seq[byte] =
  var encoder = AbiEncoder.init()
  encoder.write(value)
  encoder.finish().bytes

proc isDynamic*(_: type AbiEncoder, T: type): bool {.compileTime.} =
  var encoder = AbiEncoder.init()
  encoder.write(T.default)
  encoder.finish().dynamic

proc isStatic*(_: type AbiEncoder, T: type): bool {.compileTime.} =
  not AbiEncoder.isDynamic(T)

# Keep the old encode functions for compatibility
func encode*[bits: static[int]](x: StUint[bits]): seq[byte] =
  AbiEncoder.encode(x)

func encode*[bits: static[int]](x: StInt[bits]): seq[byte] =
  AbiEncoder.encode(x)

func encode*(b: Address): seq[byte] = 
  AbiEncoder.encode(b)

func encode*[N: static int](b: FixedBytes[N]): seq[byte] = 
  AbiEncoder.encode(b)

func encode*[N](b: array[N, byte]): seq[byte] {.inline.} = 
  AbiEncoder.encode(b)

func encode*(x: seq[byte]): seq[byte] {.inline.} =
  AbiEncoder.encode(x)

func encode*(value: SomeUnsignedInt | StUint): seq[byte] =
  AbiEncoder.encode(value)

func encode*(x: bool): seq[byte] = 
  AbiEncoder.encode(x)

func encode*(x: string): seq[byte] {.inline.} =
  AbiEncoder.encode(x)

func encode*(x: tuple): seq[byte] =
  AbiEncoder.encode(x)

func encode*[T](x: openArray[T]): seq[byte] =
  AbiEncoder.encode(@x)

func encode*(x: DynamicBytes): seq[byte] {.inline.} =
  AbiEncoder.encode(x)

func isDynamicObject(T: typedesc): bool

template isDynamicType(a: typedesc): bool =
  when a is seq | openArray | string | DynamicBytes:
    true
  elif a is object:
    const r = isDynamicObject(a)
    r
  else:
    false

func isDynamicObject(T: typedesc): bool =
  var a: T
  for v in fields(a):
    if isDynamicType(typeof(v)): return true
  false

func getTupleImpl(t: NimNode): NimNode =
  getTypeImpl(t)[1].getTypeImpl()

macro typeListLen*(t: typedesc[tuple]): int =
  newLit(t.getTupleImpl().len)

func decode*(input: openArray[byte], baseOffset, offset: int, to: var StUint): int =
  const meaningfulLen = to.bits div 8
  let offset = offset + baseOffset
  to = type(to).fromBytesBE(input.toOpenArray(offset, offset + meaningfulLen - 1))
  meaningfulLen

func decode*[N](input: openArray[byte], baseOffset, offset: int, to: var StInt[N]): int =
  const meaningfulLen = N div 8
  let offset = offset + baseOffset
  to = type(to).fromBytesBE(input.toOpenArray(offset, offset + meaningfulLen - 1))
  meaningfulLen

func decodeFixed(input: openArray[byte], baseOffset, offset: int, to: var openArray[byte]): int =
  let meaningfulLen = to.len
  var padding = to.len mod 32
  if padding != 0:
    padding = 32 - padding
  let offset = baseOffset + offset + padding
  if to.len != 0:
    assign(to, input.toOpenArray(offset, offset + meaningfulLen - 1))
  meaningfulLen + padding

func decode*[N](input: openArray[byte], baseOffset, offset: int, to: var FixedBytes[N]): int {.inline.} =
  decodeFixed(input, baseOffset, offset, array[N, byte](to))

func decode*(input: openArray[byte], baseOffset, offset: int, to: var Address): int {.inline.} =
  decodeFixed(input, baseOffset, offset, array[20, byte](to))

func decode*(input: openArray[byte], baseOffset, offset: int, to: var seq[byte]): int =
  var dataOffsetBig, dataLenBig: UInt256
  result = decode(input, baseOffset, offset, dataOffsetBig)
  let dataOffset = dataOffsetBig.truncate(int)
  discard decode(input, baseOffset, dataOffset, dataLenBig)
  let dataLen = dataLenBig.truncate(int)
  let actualDataOffset = baseOffset + dataOffset + 32
  to = input[actualDataOffset ..< actualDataOffset + dataLen]

func decode*(input: openArray[byte], baseOffset, offset: int, to: var string): int =
  var dataOffsetBig, dataLenBig: UInt256
  result = decode(input, baseOffset, offset, dataOffsetBig)
  let dataOffset = dataOffsetBig.truncate(int)
  discard decode(input, baseOffset, dataOffset, dataLenBig)
  let dataLen = dataLenBig.truncate(int)
  let actualDataOffset = baseOffset + dataOffset + 32
  to = string.fromBytes(input.toOpenArray(actualDataOffset, actualDataOffset + dataLen - 1))

func decode*(input: openArray[byte], baseOffset, offset: int, to: var DynamicBytes): int {.inline.} =
  var s: seq[byte]
  result = decode(input, baseOffset, offset, s)
  # TODO: Check data len, and raise?
  to = typeof(to)(move(s))

func decode*(input: openArray[byte], baseOffset, offset: int, obj: var object): int

func decode*[T](input: openArray[byte], baseOffset, offset: int, to: var seq[T]): int {.inline.} =
  var dataOffsetBig, dataLenBig: UInt256
  result = decode(input, baseOffset, offset, dataOffsetBig)
  let dataOffset = dataOffsetBig.truncate(int)
  discard decode(input, baseOffset, dataOffset, dataLenBig)
  # TODO: Check data len, and raise?
  let dataLen = dataLenBig.truncate(int)
  to.setLen(dataLen)
  let baseOffset = baseOffset + dataOffset + 32
  var offset = 0
  for i in 0 ..< dataLen:
    offset += decode(input, baseOffset, offset, to[i])



func decode*(input: openArray[byte], baseOffset, offset: int, to: var bool): int =
  var i: Int256
  result = decode(input, baseOffset, offset, i)
  to = not i.isZero()

func decode*(input: openArray[byte], baseOffset, offset: int, obj: var object): int =
  when isDynamicObject(typeof(obj)):
    var dataOffsetBig: UInt256
    result = decode(input, baseOffset, offset, dataOffsetBig)
    let dataOffset = dataOffsetBig.truncate(int)
    let offset = baseOffset + dataOffset
    var offset2 = 0
    for k, field in fieldPairs(obj):
      let sz = decode(input, offset, offset2, field)
      offset2 += sz
  else:
    var offset = offset
    for field in fields(obj):
      let sz = decode(input, baseOffset, offset, field)
      offset += sz
      result += sz


# Obsolete
func decode*(input: string, offset: int, to: var DynamicBytes): int {.inline, deprecated: "Use decode(openArray[byte], ...) instead".} =
  decode(hexToSeqByte(input), 0, offset div 2, to) * 2
