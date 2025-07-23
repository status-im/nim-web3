# nim-web3
# Copyright (c) 2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[sequtils],
  faststreams/outputs,
  stint,
  # TODO remove assign 2 when decoding.nim is updated
  stew/[assign2, byteutils, endians2],
  ./eth_api_types,
  ./abi_utils


{.push raises: [].}

type
  AbiEncoder* = object
    output: OutputStream
  AbiEncodingError* = object of CatchableError

func finish(encoder: var AbiEncoder): seq[byte] =
  encoder.output.getOutput(seq[byte])

proc write(encoder: var AbiEncoder, bytes: openArray[byte]) {.raises: [AbiEncodingError]} =
  try:
    encoder.output.write(bytes)
  except IOError as e:
    raise newException(AbiEncodingError, "Failed to write bytes: " & e.msg)

proc padleft(encoder: var AbiEncoder, bytes: openArray[byte], padding: byte = 0'u8) {.raises: [AbiEncodingError]} =
  let padSize = abiSlotSize - bytes.len
  if padSize > 0:
    encoder.write(repeat(padding, padSize))
  encoder.write(bytes)

# When padding right, the byte length may exceed abiSlotSize.
# So we first apply a modulo operation to compute the remainder.
# If the result is 0, we apply a second modulo  to avoid adding
# a full slot of padding.
proc padright(encoder: var AbiEncoder, bytes: openArray[byte], padding: byte = 0'u8) {.raises: [AbiEncodingError]} =
  encoder.write(bytes)
  let padSize = (abiSlotSize - (bytes.len mod abiSlotSize)) mod abiSlotSize
  if padSize > 0:
    encoder.write(repeat(padding, padSize))

proc encode(encoder: var AbiEncoder, value: SomeUnsignedInt | StUint) {.raises: [AbiEncodingError]} =
  encoder.padleft(value.toBytesBE)

proc encode(encoder: var AbiEncoder, value: SomeSignedInt | StInt) {.raises: [AbiEncodingError]} =
  when typeof(value) is StInt:
    let unsignedValue = cast[StUint[(type value).bits]](value)
    let isNegative = value.isNegative
  else:
    let unsignedValue = cast[(type value).toUnsigned](value)
    let isNegative = value < 0

  let bytes = unsignedValue.toBytesBE
  let padding = if isNegative: 0xFF'u8 else: 0x00'u8
  encoder.padleft(bytes, padding)

proc encode(encoder: var AbiEncoder, value: bool) {.raises: [AbiEncodingError]} =
  encoder.padleft([if value: 1'u8 else: 0'u8])

proc encode(encoder: var AbiEncoder, value: enum) {.raises: [AbiEncodingError]} =
  encoder.encode(uint64(ord(value)))

proc encode(encoder: var AbiEncoder, value: Address) {.raises: [AbiEncodingError]} =
  encoder.padleft(array[20, byte](value))

proc encode(encoder: var AbiEncoder, value: Bytes32) {.raises: [AbiEncodingError]} =
  encoder.padleft(array[32, byte](value))

proc encode[I](encoder: var AbiEncoder, bytes: array[I, byte]) {.raises: [AbiEncodingError]} =
  encoder.padright(bytes)

proc encode(encoder: var AbiEncoder, bytes: seq[byte]) {.raises: [AbiEncodingError]} =
  encoder.encode(bytes.len.uint64)
  encoder.padright(bytes)

proc encode(encoder: var AbiEncoder, value: string) {.raises: [AbiEncodingError]} =
  encoder.encode(value.toBytes)

proc encode(encoder: var AbiEncoder, value: distinct) {.raises: [AbiEncodingError]} =
  type Base = distinctBase(typeof(value))
  encoder.encode(Base(value))

proc encode[T](encoder: var AbiEncoder, value: seq[T]) {.raises: [AbiEncodingError].}

# When encoding a seq or an array with dynamic data, we need first
# to encode the offsets of each element, and then write the actual data.
template encodeCollection(encoder: var AbiEncoder, value: untyped) =
  if isDynamic(typeof(value[0])):
    var blocks: seq[seq[byte]] = @[]
    # Each item here will occupy a slot of 32 bytes.
    var offset = value.len * abiSlotSize

    for element in value:
      # Store the encoded element in order
      # to add the data after the offsets
      var e = AbiEncoder(output: memoryOutput())
      e.encode(element)
      let bytes = e.finish()
      blocks.add(bytes)

      # Encode the offset of the dynamic data
      encoder.encode(offset.uint64)
      offset += bytes.len

    for data in blocks:
      encoder.write(data)
  else:
    for element in value:
      encoder.encode(element)

proc encode[T, I](encoder: var AbiEncoder, value: array[I, T]) {.raises: [AbiEncodingError].} =
  encodeCollection(encoder, value)

proc encode[T](encoder: var AbiEncoder, value: seq[T]) {.raises: [AbiEncodingError].} =
  # The ABI specification requires that the length of the sequence is encoded first.
  encoder.encode(value.len.uint64)

  encodeCollection(encoder, value)

# When encoding a tuple, we need to handle each field separately.
# If a field is dynamic, we encode its offset first, then the data.
# Otherwise, we encode the field directly.
proc encode(encoder: var AbiEncoder, tupl: tuple) {.raises: [AbiEncodingError]} =
  var data: seq[seq[byte]] = @[]
  # Each item here will occupy a slot of 32 bytes.
  var offset = type(tupl).arity * abiSlotSize

  for field in tupl.fields:
    when isDynamic(typeof(field)) or (typeof(field) is tuple):
      # Store the encoded element in order
      # to add the data after the offsets
      var e = AbiEncoder(output: memoryOutput())
      e.encode(field)
      let bytes = e.finish()
      data.add(bytes)

      # Encode the offset of the dynamic data
      encoder.encode(offset.uint64)
      offset += bytes.len
    else:
      encoder.encode(field)

  for data in data:
    encoder.write(data)

proc encode*[T](_: type AbiEncoder, value: T): seq[byte] {.raises: [AbiEncodingError]} =
  try:
    var encoder = AbiEncoder(output: memoryOutput())
    encoder.encode(value)
    encoder.finish()
  except IOError as e:
    raise newException(AbiEncodingError, "Failed to encode value: " & e.msg)

# Keep the old encode functions for compatibility
proc encode*[bits: static[int]](x: StUint[bits]): seq[byte] {.raises: [AbiEncodingError]} =
  AbiEncoder.encode(x)

proc encode*[bits: static[int]](x: StInt[bits]): seq[byte] {.raises: [AbiEncodingError]} =
  AbiEncoder.encode(x)

proc encode*(b: Address): seq[byte] {.raises: [AbiEncodingError]} =
  AbiEncoder.encode(b)

proc encode*[N: static int](b: FixedBytes[N]): seq[byte] {.raises: [AbiEncodingError]} =
  AbiEncoder.encode(b)

proc encode*[N](b: array[N, byte]): seq[byte] {.inline, raises: [AbiEncodingError].} =
  AbiEncoder.encode(b)

proc encode*(x: seq[byte]): seq[byte] {.inline, raises: [AbiEncodingError].} =
  AbiEncoder.encode(x)

proc encode*(value: SomeUnsignedInt | StUint): seq[byte] =
  AbiEncoder.encode(value)

proc encode*(x: bool): seq[byte] {.raises: [AbiEncodingError]} =
  AbiEncoder.encode(x)

proc encode*(x: string): seq[byte] {.inline, raises: [AbiEncodingError].} =
  AbiEncoder.encode(x)

proc encode*(x: tuple): seq[byte] {.raises: [AbiEncodingError]} =
  AbiEncoder.encode(x)

proc encode*[T](x: openArray[T]): seq[byte] {.raises: [AbiEncodingError]} =
  AbiEncoder.encode(@x)

proc encode*(x: DynamicBytes): seq[byte] {.inline, raises: [AbiEncodingError].} =
  AbiEncoder.encode(x)

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
