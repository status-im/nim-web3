import
    std/typetraits,
    stint,
    faststreams/inputs,
    stew/[byteutils, endians2, assign2],
    serialization,
    ./eth_api_types,
    ./abi_utils

from ./abi_serialization import AbiReader

{.push raises: [].}

export abi_serialization

type
  AbiDecoder* = object
    input: InputStream
  UInt = SomeUnsignedInt | StUint

template basetype(Range: type range): untyped =
  when Range isnot SomeUnsignedInt: {.error: "only uint ranges supported".}
  elif sizeof(Range) == sizeof(uint8): uint8
  elif sizeof(Range) == sizeof(uint16): uint16
  elif sizeof(Range) == sizeof(uint32): uint32
  elif sizeof(Range) == sizeof(uint64): uint64
  else:
    {.error "unsupported range type".}

proc finish(decoder: var AbiDecoder) {.raises: [SerializationError].} =
  try:
    if decoder.input.readable:
      raise newException(SerializationError, "unread trailing bytes found")
  except IOError as e:
    raise newException(SerializationError, "Failed to finish decoding: " & e.msg)

proc read(decoder: var AbiDecoder, size = abiSlotSize): seq[byte] {.raises: [SerializationError].} =
  var buf = newSeq[byte]((size + 31) div 32 * 32)

  try:
    if not decoder.input.readInto(buf):
      raise newException(SerializationError, "reading past end of bytes")
  except IOError as e:
    raise newException(SerializationError, "Failed to read bytes: " & e.msg)

  return buf

proc readAll(decoder: var AbiDecoder) : seq[byte] {.raises: [SerializationError].} =
  try:
    while decoder.input.readable:
      result.add decoder.input.read
    return result
  except IOError as e:
    raise newException(SerializationError, "Failed to read bytes: " & e.msg)

template checkLeftPadding(buf: openArray[byte], padding: int, expected: uint8) =
  for i in 0 ..< padding:
    if buf[i] != expected:
      raise newException(SerializationError, "invalid padding found")

template checkRightPadding(buf: openArray[byte], paddingStart: int, paddingEnd: int) =
  for i in paddingStart ..< paddingEnd:
    if buf[i] != 0x00'u8:
      raise newException(SerializationError, "invalid padding found")

proc decode(decoder: var AbiDecoder, T: type UInt): T {.raises: [SerializationError].} =
  var buf = decoder.read(sizeof(T))

  let padding = abiSlotSize - sizeof(T)
  checkLeftPadding(buf, padding, 0x00'u8)

  return T.fromBytesBE(buf[padding ..< abiSlotSize])

proc decode(decoder: var AbiDecoder, T: type StInt): T {.raises: [SerializationError].} =
  var buf = decoder.read(sizeof(T))

  let padding = abiSlotSize - sizeof(T)
  let value = T.fromBytesBE(buf[padding ..< abiSlotSize])

  let b = if value.isNegative: 0xFF'u8 else: 0x00'u8
  checkLeftPadding(buf, padding, b)

  return value

proc decode(decoder: var AbiDecoder, T: type SomeSignedInt): T {.raises: [SerializationError].} =
  var buf = decoder.read(sizeof(T))

  let padding = abiSlotSize - sizeof(T)
  let unsigned = T.toUnsigned.fromBytesBE(buf[padding ..< abiSlotSize])
  let value = cast[T](unsigned)

  let b = if value < 0: 0xFF'u8 else: 0x00'u8
  checkLeftPadding(buf, padding, b)

  return value

proc decode(decoder: var AbiDecoder, T: type bool): T {.raises: [SerializationError].} =
  case decoder.decode(uint8)
    of 0: false
    of 1: true
    else: raise newException(SerializationError, "invalid boolean value")

proc decode(decoder: var AbiDecoder, T: type range): T {.raises: [SerializationError].} =
  let value = decoder.decode(basetype(T))
  if value in T.low..T.high:
    T(value)
  else:
    raise newException(SerializationError, "value not in range")

proc decode(decoder: var AbiDecoder, T: type enum): T {.raises: [SerializationError].}=
  let value = decoder.decode(uint64)
  if value in T.low.uint64..T.high.uint64:
    T(value)
  else:
    raise newException(SerializationError, "invalid enum value")

proc decode(decoder: var AbiDecoder, T: type Address): T {.raises: [SerializationError].} =
  var bytes: array[sizeof(T), byte]
  let padding = abiSlotSize - sizeof(T)

  try:
    bytes[0..<sizeof(T)] =(decoder.read(sizeof(T)))[padding ..< abiSlotSize]
  except IOError as e:
    raise newException(SerializationError, "Failed to read address: " & e.msg)

  T(bytes)

proc decode[I](decoder: var AbiDecoder, T: type array[I, byte]): T {.raises: [SerializationError].} =
  var arr: T
  let bytes = (arr.len + 31) div 32 * 32
  let buf = decoder.read(bytes)
  arr[0..<arr.len] = buf[0..<arr.len]

  checkRightPadding(buf, arr.len, bytes)

  return arr

proc decode(decoder: var AbiDecoder, T: type seq[byte]): T {.raises: [SerializationError].} =
  let len = decoder.decode(uint64)
  let bytes = ((len + 31) div 32 * 32).int
  let buf = decoder.read(bytes)

  checkRightPadding(buf, len.int, bytes)

  return buf[0 ..< len]

proc decode(decoder: var AbiDecoder, T: type string): T {.raises: [SerializationError].} =
  string.fromBytes(decoder.decode(seq[byte]))

proc decode[T: distinct](decoder: var AbiDecoder, _: type T): T {.raises: [SerializationError].} =
  T(decoder.decode(distinctBase T))

## When T is dynamic, ABI layout looks like:
## +----------------------------+
## | size of the dynamic array |  <-- 32 (optional ONLY for dynamic arrays)
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
## +----------------------------+
## | size of the dynamic array |  <-- 32 (optional ONLY for dynamic arrays)
## +----------------------------+
## | element 0                 |  <-- 32
## +----------------------------+
## | element 1                 |  <-- 32
## +----------------------------+
## | ...                        |
## +----------------------------+
## | element N-1               |
## +----------------------------+
##
## The size of the static array is passed as an argument to the decoder.
## For the dynamic array, the size is should be None,
## and the decoder will read the size from the input stream.
proc decodeCollection[T](decoder: var AbiDecoder, size: Opt[uint64]): seq[T] {.raises: [SerializationError].} =
  if isDynamic(T):
    # Since we cannot seek the position in the input stream,
    # we need to read the whole buffer first.
    var buf = decoder.readAll()
    var offset = 0.uint64
    var len = 0.uint64
    if size.isNone:
      # Get the length of the dynamic array from the first slot.
      # Add assign one slot to the offset,
      # so that the first element starts at the second slot.
      var decoder = AbiDecoder(input: memoryInput(buf[0 ..< abiSlotSize]))
      len = decoder.decode(uint64)
      decoder.finish()
      offset = 1
    else:
      len = size.get()

    var offsets = newSeq[uint64](len)
    for i in 0..<len:
      let start = abiSlotSize * (i + offset)
      var decoder = AbiDecoder(input: memoryInput(buf[start ..< start + abiSlotSize]))
      let value = decoder.decode(uint64)
      decoder.finish()
      offsets[i] = value + (abiSlotSize * offset).uint64

    result = newSeq[T](len)
    for i in 0..<len:
      let start = offsets[i].int
      # Here we need to take only the data that is between the offsets.
      let stop = if i+1 < result.len.uint64: offsets[i+1].int else: buf.len
      let data = buf[start ..< stop]
      var decoder = AbiDecoder(input: memoryInput(data))
      result[i] = decoder.decode(T)

    return result
  else:
    let len = if size.isNone: decoder.decode(uint64) else: size.get()
    result = newSeq[T](len)
    for i in 0..<len:
      result[i] = decoder.decode(T)

    return result

proc decode[T](decoder: var AbiDecoder, _: type seq[T]): seq[T] {.raises: [SerializationError].} =
  return decodeCollection[T](decoder, Opt.none(uint64))

proc decode[I,T](decoder: var AbiDecoder, _: type array[I,T]): array[I,T] {.raises: [SerializationError].} =
  var res: array[I, T]
  let data = decodeCollection[T](decoder, Opt.some(res.len.uint64))
  for i in 0..<res.len:
    res[i] = data[i]

  return res

## When T is a tuple, ABI layout looks like:
## +----------------------------+
## | static field 0 or offset   |  <-- 32
## +----------------------------+
## | static field 1 or offset   |  <-- 32
## +----------------------------+
## | ...                        |
## +----------------------------+
## | static field N-1 or offset |  <-- 32
## +----------------------------+
## | dynamic field 0 data       |  <-- at offset
## +----------------------------+
## | dynamic field 1 data       |  <-- at offset
## +----------------------------+
## | ...                        |
## +----------------------------+
proc decode[T: tuple](decoder: var AbiDecoder, _: typedesc[T]): T {.raises: [SerializationError].} =
  var res: T
  let arity = type(res).arity
  var offsets = newSeq[uint64](arity)

  # Since we cannot seek the position in the input stream,
  # we need to read the whole buffer first.
  var buf = decoder.readAll()

  var i = 0
  for field in res.fields:
    if buf.len == 0:
      discard
    else:
      let start = abiSlotSize * i
      let data = buf[start ..< start + abiSlotSize]
      var decoder = AbiDecoder(input: memoryInput(data))
      when isDynamic(typeof(field)):
        offsets[i] = decoder.decode(uint64)
      else:
        field = decoder.decode(typeof(field))
      decoder.finish()
    inc i

  i = 0
  for field in res.fields:
    if offsets[i] > 0:
      let start = offsets[i].int

      var stop = buf.len
      for j in i+1 ..< arity:
        if offsets[j] > 0:
          stop = offsets[j].int
          break

      let data = buf[start ..< stop]
      var decoder = AbiDecoder(input: memoryInput(data))
      field = decoder.decode(typeof(field))
    inc i

  # Avoid compiler hint message about unused variable
  # when tuple has no dynamic fields
  discard offsets

  return res

proc readValue*[T](r: var AbiReader, value: T): T {.raises: [SerializationError]} =
  try:
    readValue[T](r, T)
  except SerializationError as e:
    raise newException(SerializationError, e.msg)

proc readValue*[T](r: var AbiReader, _: typedesc[T]): T {.raises: [SerializationError]} =
  var resultObj: T
  var decoder = AbiDecoder(input: r.getStream)
  type StInts = StInt | StUint

  when T is object and T is not StInts:
    resultObj.enumInstanceSerializedFields(fieldName, fieldValue):
      fieldValue = decoder.decode(typeof(fieldValue))
  else:
    resultObj = decoder.decode(T)

  decoder.finish()

  result = resultObj

# Keep the old encode functions for compatibility
func decode*(input: openArray[byte], baseOffset, offset: int, to: var StUint): int {.deprecated: "use Abi.decode instead"} =
  const meaningfulLen = to.bits div 8
  let offset = offset + baseOffset
  to = type(to).fromBytesBE(input.toOpenArray(offset, offset + meaningfulLen - 1))
  meaningfulLen

func decode*[N](input: openArray[byte], baseOffset, offset: int, to: var StInt[N]): int {.deprecated: "use Abi.decode instead"} =
  const meaningfulLen = N div 8
  let offset = offset + baseOffset
  to = type(to).fromBytesBE(input.toOpenArray(offset, offset + meaningfulLen - 1))
  meaningfulLen

func decodeFixed(input: openArray[byte], baseOffset, offset: int, to: var openArray[byte]): int {.deprecated: "use Abi.decode instead"} =
  let meaningfulLen = to.len
  var padding = to.len mod 32
  if padding != 0:
    padding = 32 - padding
  let offset = baseOffset + offset + padding
  if to.len != 0:
    assign(to, input.toOpenArray(offset, offset + meaningfulLen - 1))
  meaningfulLen + padding

func decode*[N](input: openArray[byte], baseOffset, offset: int, to: var FixedBytes[N]): int {.inline, deprecated: "use Abi.decode instead".} =
  decodeFixed(input, baseOffset, offset, array[N, byte](to))

func decode*(input: openArray[byte], baseOffset, offset: int, to: var Address): int {.inline, deprecated: "use Abi.decode instead".} =
  decodeFixed(input, baseOffset, offset, array[20, byte](to))

func decode*(input: openArray[byte], baseOffset, offset: int, to: var seq[byte]): int {.deprecated: "use Abi.decode instead"} =
  var dataOffsetBig, dataLenBig: UInt256
  result = decode(input, baseOffset, offset, dataOffsetBig)
  let dataOffset = dataOffsetBig.truncate(int)
  discard decode(input, baseOffset, dataOffset, dataLenBig)
  let dataLen = dataLenBig.truncate(int)
  let actualDataOffset = baseOffset + dataOffset + 32
  to = input[actualDataOffset ..< actualDataOffset + dataLen]

func decode*(input: openArray[byte], baseOffset, offset: int, to: var string): int {.deprecated: "use Abi.decode instead"} =
  var dataOffsetBig, dataLenBig: UInt256
  result = decode(input, baseOffset, offset, dataOffsetBig)
  let dataOffset = dataOffsetBig.truncate(int)
  discard decode(input, baseOffset, dataOffset, dataLenBig)
  let dataLen = dataLenBig.truncate(int)
  let actualDataOffset = baseOffset + dataOffset + 32
  to = string.fromBytes(input.toOpenArray(actualDataOffset, actualDataOffset + dataLen - 1))

func decode*(input: openArray[byte], baseOffset, offset: int, to: var DynamicBytes): int {.inline, deprecated: "use Abi.decode instead".} =
  var s: seq[byte]
  result = decode(input, baseOffset, offset, s)
  # TODO: Check data len, and raise?
  to = typeof(to)(move(s))

func decode*(input: openArray[byte], baseOffset, offset: int, obj: var object): int {.deprecated: "use Abi.decode instead"}

func decode*[T](input: openArray[byte], baseOffset, offset: int, to: var seq[T]): int {.inline, deprecated: "use Abi.decode instead".} =
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

func decode*(input: openArray[byte], baseOffset, offset: int, to: var bool): int {.deprecated: "use Abi.decode instead"} =
  var i: Int256
  result = decode(input, baseOffset, offset, i)
  to = not i.isZero()

func decode*(input: openArray[byte], baseOffset, offset: int, obj: var object): int {.deprecated: "use Abi.decode instead"} =
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
