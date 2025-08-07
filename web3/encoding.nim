# nim-web3
# Copyright (c) 2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[sequtils, macros],
  faststreams/outputs,
  stint,
  stew/[byteutils, endians2],
  serialization,
  ./eth_api_types,
  ./abi_utils,
  ./abi_serialization

{.push raises: [].}

export abi_serialization, abi_utils

type
  AbiEncoder* = object
    output: OutputStream

func finish(encoder: var AbiEncoder): seq[byte] =
  encoder.output.getOutput(seq[byte])

proc write(encoder: var AbiEncoder, bytes: openArray[byte]) {.raises: [SerializationError]} =
  try:
    encoder.output.write(bytes)
  except IOError as e:
    raise newException(SerializationError, "Failed to write bytes: " & e.msg)

proc padleft(encoder: var AbiEncoder, bytes: openArray[byte], padding: byte = 0'u8) {.raises: [SerializationError]} =
  let padSize = abiSlotSize - bytes.len
  if padSize > 0:
    encoder.write(repeat(padding, padSize))
  encoder.write(bytes)

# When padding right, the byte length may exceed abiSlotSize.
# So we first apply a modulo operation to compute the remainder.
# If the result is 0, we apply a second modulo  to avoid adding
# a full slot of padding.
proc padright(encoder: var AbiEncoder, bytes: openArray[byte], padding: byte = 0'u8) {.raises: [SerializationError]} =
  encoder.write(bytes)
  let padSize = (abiSlotSize - (bytes.len mod abiSlotSize)) mod abiSlotSize

  if padSize > 0:
    encoder.write(repeat(padding, padSize))

proc encode(encoder: var AbiEncoder, value: SomeUnsignedInt | StUint) {.raises: [SerializationError]} =
  encoder.padleft(value.toBytesBE)

proc encode(encoder: var AbiEncoder, value: SomeSignedInt | StInt) {.raises: [SerializationError]} =
  when typeof(value) is StInt:
    let unsignedValue = cast[StInt[(type value).bits]](value)
    let isNegative = value.isNegative
  else:
    let unsignedValue = cast[(type value).toUnsigned](value)
    let isNegative = value < 0

  let bytes = unsignedValue.toBytesBE
  let padding = if isNegative: 0xFF'u8 else: 0x00'u8
  encoder.padleft(bytes, padding)

proc encode(encoder: var AbiEncoder, value: bool) {.raises: [SerializationError]} =
  encoder.padleft([if value: 1'u8 else: 0'u8])

proc encode(encoder: var AbiEncoder, value: enum) {.raises: [SerializationError]} =
  encoder.encode(uint64(ord(value)))

proc encode(encoder: var AbiEncoder, value: Address) {.raises: [SerializationError]} =
  encoder.padleft(array[20, byte](value))

proc encode(encoder: var AbiEncoder, value: Bytes32) {.raises: [SerializationError]} =
  encoder.padleft(array[32, byte](value))

proc encode[I](encoder: var AbiEncoder, bytes: array[I, byte]) {.raises: [SerializationError]} =
  encoder.padright(bytes)

proc encode(encoder: var AbiEncoder, bytes: seq[byte]) {.raises: [SerializationError]} =
  encoder.encode(bytes.len.uint64)
  encoder.padright(bytes)

proc encode(encoder: var AbiEncoder, value: string) {.raises: [SerializationError]} =
  encoder.encode(value.toBytes)

proc encode(encoder: var AbiEncoder, value: distinct) {.raises: [SerializationError]} =
  type Base = distinctBase(typeof(value))
  encoder.encode(Base(value))

proc encode[T](encoder: var AbiEncoder, value: seq[T]) {.raises: [SerializationError].}
proc encode[T: tuple](encoder: var AbiEncoder, tupl: T) {.raises: [SerializationError]}

  ## When T is dynamic, ABI layout looks like:
  ##
  ## +----------------------------+
  ## | offset to element 0       |  <-- 32
  ## +----------------------------+
  ## | offset to element 1       |  <-- 32 + size of encoded element 0
  ## +----------------------------+
  ## | ...                        |
  ## +----------------------------+
  ## | encoded element 0         |  <-- item at offset 0
  ## +----------------------------+
  ## | encoded element 1         |  <-- item at offset 1
  ## +----------------------------+
  ## | ...                        |
  ## +----------------------------+
  ##
  ## When T is static, ABI layout looks like:
  ##
  ## +----------------------------+
  ## | element 0                 |  <-- 32
  ## +----------------------------+
  ## | element 1                 |  <-- 32
  ## +----------------------------+
  ## | ...                        |
  ## +----------------------------+
  ## | element N-1               |
  ## +----------------------------+
template encodeCollection(encoder: var AbiEncoder, value: untyped) =
  if isDynamic(typeof(value[0])):
    var blocks: seq[seq[byte]] = @[]
    var offset = value.len * abiSlotSize

    # Encode offset first
    for element in value:
      var e = AbiEncoder(output: memoryOutput())
      e.encode(element)
      let bytes = e.finish()
      blocks.add(bytes)

      encoder.encode(offset.uint64)
      offset += bytes.len

    # Then encode the data
    for data in blocks:
      encoder.write(data)
  else:
    for element in value:
      encoder.encode(element)

# Fixed array does not include the length in the ABI encoding.
proc encode[T, I](encoder: var AbiEncoder, value: array[I, T]) {.raises: [SerializationError].} =
  encodeCollection(encoder, value)

# Sequences are dynamic by definition, so we always encode their length first.
proc encode[T](encoder: var AbiEncoder, value: seq[T]) {.raises: [SerializationError].} =
  encoder.encode(value.len.uint64)

  encodeCollection(encoder, value)

## Tuple can contain both static and dynamic elements.
## When the data is dynamic, the offset to the data is encoded first.
##
## Example: (static, dynamic, dynamic)
##
## +------------------------------+
## | element 1                   |
## +------------------------------+
## | offset to element 2         |
## +------------------------------+
## | offset to element 3         |
## +------------------------------+
## | element 2                   |
## +------------------------------+
## | element 3                   |
## +------------------------------+
proc encode[T: tuple](encoder: var AbiEncoder, tupl: T) {.raises: [SerializationError]} =
  var data: seq[seq[byte]] = @[]
  var offset = T.arity * abiSlotSize

  for field in tupl.fields:
    when isDynamic(typeof(field)):
      # Store the encoded element in order
      # to add the data after the offsets
      let bytes = Abi.encode(field)
      data.add(bytes)

      # Encode the offset of the dynamic data
      encoder.encode(offset.uint64)

      offset += bytes.len
    else:
      encoder.encode(field)

  # Avoid compiler hint message about unused variable
  # when tuple has no dynamic fields
  discard offset

  for data in data:
    encoder.write(data)

proc writeValue*[T](w: var AbiWriter, value: T) {.raises: [SerializationError]} =
  var encoder = AbiEncoder(output: memoryOutput())
  type StInts = StInt | StUint

  when T is object and T is not StInts:
    var data: seq[seq[byte]] = @[]
    var offset = totalSerializedFields(T) * abiSlotSize

    value.enumInstanceSerializedFields(_, fieldValue):
      when isDynamic(typeof(fieldValue)):
        # Store the encoded element in order
        # to add the data after the offsets
        let bytes = Abi.encode(fieldValue)
        data.add(bytes)

        # Encode the offset of the dynamic data
        encoder.encode(offset.uint64)
        offset += bytes.len
      else:
        encoder.encode(fieldValue)

    # Avoid compiler hint message about unused variable
    # when tuple has no dynamic fields
    discard offset

    for data in data:
      encoder.write(data)

    try:
      w.write encoder.finish()
    except IOError as e:
      raise newException(SerializationError, "Failed to write value: " & e.msg)
  else:
    try:
        encoder.encode(value)
        w.write encoder.finish()
    except IOError as e:
      raise newException(SerializationError, "Failed to write value: " & e.msg)

# Keep the old encode functions for compatibility
func encode*[bits: static[int]](x: StUint[bits]): seq[byte] {.deprecated: "use Abi.encode instead" .} =
  @(x.toBytesBE())

func encode*[bits: static[int]](x: StInt[bits]): seq[byte] {.deprecated: "use Abi.encode instead" .} =
  @(x.toBytesBE())

func encodeFixed(a: openArray[byte]): seq[byte] =
  var padding = a.len mod 32
  if padding != 0: padding = 32 - padding
  result.setLen(padding) # Zero fill padding
  result.add(a)

func encode*[N: static int](b: FixedBytes[N]): seq[byte] {.deprecated: "use Abi.encode instead" .} = encodeFixed(b.data)
func encode*(b: Address): seq[byte] {.deprecated: "use Abi.encode instead" .} = encodeFixed(b.data)
func encode*[N](b: array[N, byte]): seq[byte] {.inline, deprecated: "use Abi.encode instead".} = encodeFixed(b)

func encodeDynamic(v: openArray[byte]): seq[byte] =
  result = encode(v.len.u256)
  result.add(v)
  let pad = v.len mod 32
  if pad != 0:
    result.setLen(result.len + 32 - pad)

func encode*(x: DynamicBytes): seq[byte] {.inline, deprecated: "use Abi.encode instead".} =
  encodeDynamic(distinctBase x)

func encode*(x: seq[byte]): seq[byte] {.inline, deprecated: "use Abi.encode instead".} =
  encodeDynamic(x)

func encode*(x: string): seq[byte] {.inline, deprecated: "use Abi.encode instead".} =
  encodeDynamic(x.toOpenArrayByte(0, x.high))

func encode*(x: bool): seq[byte] {.deprecated: "use Abi.encode instead" .} = encode(x.int.u256)

func encode*(x: tuple): seq[byte] {.deprecated: "use Abi.encode instead" .}

func encode*[T](x: openArray[T]): seq[byte] {.deprecated: "use Abi.encode instead" .} =
  result = encode(x.len.u256)
  when isDynamicType(T):
    result.setLen((1 + x.len) * 32)
    for i in 0 ..< x.len:
      let offset = result.len - 32
      result &= encode(x[i])
      result[(i + 1) * 32 .. (i + 2) * 32 - 1] = encode(offset.u256)
  else:
    for i in 0 ..< x.len:
      result &= encode(x[i])

func getTupleImpl(t: NimNode): NimNode =
  getTypeImpl(t)[1].getTypeImpl()

macro typeListLen*(t: typedesc[tuple]): int =
  newLit(t.getTupleImpl().len)

func encode*(x: tuple): seq[byte] {.deprecated: "use Abi.encode instead" .} =
  var offsets {.used.}: array[typeListLen(typeof(x)), int]
  var i = 0
  for v in fields(x):
    when isDynamicType(typeof(v)):
      offsets[i] = result.len
      result.setLen(result.len + 32)
    else:
      result &= encode(v)
    inc i
  i = 0
  for v in fields(x):
    when isDynamicType(typeof(v)):
      let offset = result.len
      let o = offsets[i]
      result[o .. o + 31] = encode(offset.u256)
      result &= encode(v)
    inc i