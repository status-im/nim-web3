import
  std/typetraits,
  stint,
  faststreams/inputs,
  stew/[byteutils, endians2, assign2],
  serialization,
  ./abi_serialization,
  ./eth_api_types,
  ./abi_utils

{.push raises: [].}

export abi_serialization, abi_utils

type
  AbiDecoder* = object
    data: seq[byte]
    pos: int
    maxMemoryFactor: uint64
    remainingMemory: uint64

  UInt = AbiUnsignedInt | StUint

template basetype(Range: type range): untyped =
  when Range isnot AbiUnsignedInt: {.error: "only uint ranges supported".}
  elif sizeof(Range) == sizeof(uint8): uint8
  elif sizeof(Range) == sizeof(uint16): uint16
  elif sizeof(Range) == sizeof(uint32): uint32
  elif sizeof(Range) == sizeof(uint64): uint64
  else:
    {.error "unsupported range type".}

proc init(
    T: type AbiDecoder, input: InputStream,
    maxMemoryFactor: uint64): T {.raises: [SerializationError].} =
  var data: seq[byte]
  try:
    if input.len.isSome:
      data.setLenUninit(input.len.get)
      data.setLen(input.readIntoEx(data))
    while input.readable:
      data.add input.read
  except IOError as e:
    raise newException(SerializationError, "Failed to read bytes: " & e.msg)

  let remainingMemory =
    if maxMemoryFactor == 0 or
        data.len.uint64 > uint64.high div maxMemoryFactor:
      uint64.high
    else:
      maxMemoryFactor * data.len.uint64
  T(data: data,
    maxMemoryFactor: maxMemoryFactor,
    remainingMemory: remainingMemory)

func charge(
    decoder: var AbiDecoder,
    count: uint64, size = 1) {.raises: [SerializationError].} =
  if count > decoder.remainingMemory div size.uint64:
    raise newException(SerializationError,
      "decoded data exceeds maxMemoryFactor " & $decoder.maxMemoryFactor &
      " times the input size " & $decoder.data.len)
  decoder.remainingMemory -= count * size.uint64

template read(
    decoder: var AbiDecoder, size = abiSlotSize): openArray[byte] =
  ## We want to ensure that even if the data is smaller than the ABI slot size,
  ## it will occupy at least one slot size. That's why we have:
  ## size + abiSlotSize - 1
  ## Then we divide it by abiSlotSize to get the number of slots needed.
  ## And finally, we multiply it by abiSlotSize to get the total size in bytes.
  let len = (size + abiSlotSize - 1) div abiSlotSize * abiSlotSize
  if len > decoder.data.len - decoder.pos:
    raise newException(SerializationError, "reading past end of bytes")
  decoder.charge(len.uint64)

  decoder.pos += len
  decoder.data.toOpenArray(decoder.pos - len, decoder.pos - 1)

template checkLeftPadding(
    buf: openArray[byte], padding: int, expected: uint8) =
  for i in 0 ..< padding:
    if buf[i] != expected:
      raise newException(SerializationError, "invalid padding found")

template checkRightPadding(
    buf: openArray[byte], paddingStart: int, paddingEnd: int) =
  for i in paddingStart ..< paddingEnd:
    if buf[i] != 0x00'u8:
      raise newException(SerializationError, "invalid padding found")

proc checkReadable(
    decoder: var AbiDecoder,
    len: uint64, size: int) {.raises: [SerializationError].} =
  if len > uint64(int.high div max(size, 1)) or
      int(len) * size > decoder.data.len - decoder.pos:
    raise newException(SerializationError, "reading past end of bytes")

proc seekTo(
    decoder: var AbiDecoder,
    base: int, offset: uint64) {.raises: [SerializationError].} =
  if offset > uint64(decoder.data.len - base):
    raise newException(SerializationError, "reading past end of bytes")
  decoder.pos = base + int(offset)

proc decode(_: var AbiDecoder, _: type int): int {.error:
  "ABI: plain 'int' is forbidden. Use int8/16/32/64 or Int256."}

proc decode(_: var AbiDecoder, _: type uint): uint {.error:
  "ABI: plain 'uint' is forbidden. Use uint8/16/32/64 or UInt256."}

proc decode(
    decoder: var AbiDecoder,
    T: type UInt): T {.raises: [SerializationError].} =
  when T is StUint:
    when T.bits > 256:
      # https://docs.soliditylang.org/en/latest/abi-spec.html#types
      {.error: "uint<M> has to fit into a single slot".}

  func doDecode(buf: openArray[byte]): T =
    let padding = abiSlotSize - sizeof(T)
    checkLeftPadding(buf, padding, 0x00'u8)
    T.fromBytesBE(buf.toOpenArray(padding, abiSlotSize-1))

  decoder.read(sizeof(T)).doDecode()

proc decode(
    decoder: var AbiDecoder,
    T: type StInt): T {.raises: [SerializationError].} =
  when T.bits > 256:
    # https://docs.soliditylang.org/en/latest/abi-spec.html#types
    {.error: "int<M> has to fit into a single slot".}

  func doDecode(buf: openArray[byte]): T =
    let
      padding = abiSlotSize - sizeof(T)
      value = T.fromBytesBE(buf.toOpenArray(padding, abiSlotSize-1))
      b = if value.isNegative: 0xFF'u8 else: 0x00'u8
    checkLeftPadding(buf, padding, b)
    value

  decoder.read(sizeof(T)).doDecode()

proc decode(
    decoder: var AbiDecoder,
    T: type AbiSignedInt): T {.raises: [SerializationError].} =
  func doDecode(buf: openArray[byte]): T =
    let
      padding = abiSlotSize - sizeof(T)
      unsigned = T.toUnsigned.fromBytesBE(
        buf.toOpenArray(padding, abiSlotSize - 1))
      value = cast[T](unsigned)
      expectedPadding = if value < 0: 0xFF'u8 else: 0x00'u8
    checkLeftPadding(buf, padding, expectedPadding)
    value

  decoder.read(sizeof(T)).doDecode()

proc decode(
    decoder: var AbiDecoder,
    T: type bool): T {.raises: [SerializationError].} =
  case decoder.decode(uint8)
    of 0: false
    of 1: true
    else: raise newException(SerializationError, "invalid boolean value")

proc decode(
    decoder: var AbiDecoder,
    T: type range): T {.raises: [SerializationError].} =
  let value = decoder.decode(basetype(T))
  if value in T.low..T.high:
    T(value)
  else:
    raise newException(SerializationError, "value not in range")

proc decode(
    decoder: var AbiDecoder,
    T: type enum): T {.raises: [SerializationError].} =
  let value = decoder.decode(uint64)
  if value in T.low.uint64..T.high.uint64:
    T(value)
  else:
    raise newException(SerializationError, "invalid enum value")

proc decode(
    decoder: var AbiDecoder,
    T: type Address): T {.raises: [SerializationError].} =
  var bytes: array[sizeof(T), byte]
  let padding = abiSlotSize - sizeof(T)

  bytes[0 ..< sizeof(T)] =
    decoder.read(sizeof(T)).toOpenArray(padding, abiSlotSize-1)

  T(bytes)

proc decode[I](
    decoder: var AbiDecoder,
    T: type FixedBytes[I]): T {.raises: [SerializationError].} =
  when I notin 1 .. abiSlotSize:
    # https://docs.soliditylang.org/en/latest/abi-spec.html#types
    {.error: "bytes<M> has to fit into a single slot".}

  func doDecode(buf: openArray[byte]): T =
    var arr {.noinit.}: T
    distinctBase(arr)[0..<arr.len] = buf.toOpenArray(0, arr.len - 1)
    checkRightPadding(buf, arr.len, buf.len)
    arr

  decoder.read(I).doDecode()

proc decode[T: DynamicBytes](
    decoder: var AbiDecoder, t: type T): T {.raises: [SerializationError].} =
  let len = decoder.decode(uint64)
  if len notin T.minLen.uint64 .. T.maxLen.uint64:
    raise newException(SerializationError, "reading past end of bytes")

  if len == 0:
    return T(@[])

  func doDecode(buf: openArray[byte]): T =
    checkRightPadding(buf, len.int, buf.len)
    T(buf[0 ..< len.int])

  decoder.checkReadable(len, 1)
  decoder.read(len.int).doDecode()

proc decode(decoder: var AbiDecoder, T: type string): T {.raises: [SerializationError].} =
  string.fromBytes(distinctBase(decoder.decode(DynamicBytes[0])))

proc decode[T](decoder: var AbiDecoder, _: type seq[T]): seq[T]
    {.raises: [SerializationError].}
proc decode[I, T](decoder: var AbiDecoder, _: type array[I, T]): array[I, T]
    {.raises: [SerializationError].}
proc decode[T: tuple](decoder: var AbiDecoder, _: typedesc[T]): T {.raises: [SerializationError].}

proc decode[T: distinct](decoder: var AbiDecoder, _: type T): T {.raises: [SerializationError].} =
  T(decoder.decode(distinctBase(T, recursive = false)))


proc decodeCollection[T](decoder: var AbiDecoder, size: Opt[uint64]): seq[T] {.raises: [SerializationError].} =
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
  var res: seq[T]

  if isDynamic(T):
    # The size of the static array is passed as an argument to the decoder.
    # For the dynamic array, the size is should be None,
    # and the decoder will read the size from the input stream.
    var len = if size.isNone: decoder.decode(uint64) else: size.get()
    let base = decoder.pos
    decoder.checkReadable(len, abiSlotSize)

    var offsets = newSeq[uint64](len)
    for i in 0..<len:
      offsets[i] = decoder.decode(uint64)

    res = newSeq[T](len)
    for i in 0..<len:
      decoder.seekTo(base, offsets[i])
      res[i] = decoder.decode(T)

    return res
  else:
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
    let len = if size.isNone: decoder.decode(uint64) else: size.get()
    const encodedSize = staticSize(T)
    decoder.checkReadable(len, encodedSize)
    when encodedSize == 0:
      decoder.charge(len, static(max(sizeof(T), 1)))
    result = newSeq[T](len)
    for i in 0..<len:
      result[i] = decoder.decode(T)

    return result

proc decode[T](decoder: var AbiDecoder, _: type seq[T]): seq[T] {.raises: [SerializationError].} =
  decodeCollection[T](decoder, Opt.none(uint64))

proc decode[I,T](decoder: var AbiDecoder, _: type array[I,T]): array[I,T] {.raises: [SerializationError].} =
  var res: array[I, T]
  let data = decodeCollection[T](decoder, Opt.some(res.len.uint64))
  for i in 0..<res.len:
    res[i] = data[i]

  res

proc decode[T: tuple](decoder: var AbiDecoder, _: typedesc[T]): T {.raises: [SerializationError].} =
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
  var res: T
  let arity = type(res).tupleLen
  var offsets = newSeq[uint64](arity + 1)
  var i = 0
  let base {.used.} = decoder.pos

  # Decode static fields first and get the offsets for dynamic fields.
  for field in res.fields:
    when isDynamic(typeof(field)):
      offsets[i] = decoder.decode(uint64)
    else:
      field = decoder.decode(typeof(field))
    inc i

  i = 0
  # Decode dynamic fields using the offsets.
  for field in res.fields:
    when isDynamic(typeof(field)):
      decoder.seekTo(base, offsets[i])
      field = decoder.decode(typeof(field))

    inc i

  discard offsets

  res

proc decodeObject(decoder: var AbiDecoder, T: type): T {.raises: [SerializationError].} =
  ## When T is a object, ABI layout looks like the typle:
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
  var resultObj: T
  var offsets {.used.} = newSeq[uint64](totalSerializedFields(T))
  let base {.used.} = decoder.pos

  # Decode static fields first and get the offsets for dynamic fields.
  var i = 0
  resultObj.enumInstanceSerializedFields(_, fieldValue):
    when isDynamic(typeof(fieldValue)):
      offsets[i] = decoder.decode(uint64)
    else:
      fieldValue = decoder.decode(typeof(fieldValue))
    inc i

  # Decode dynamic fields using the offsets.
  i = 0
  resultObj.enumInstanceSerializedFields(_, fieldValue):
    when isDynamic(typeof(fieldValue)):
      decoder.seekTo(base, offsets[i])
      fieldValue = decoder.decode(typeof(fieldValue))
    inc i

  resultObj

proc decode*(
    decoder: var AbiDecoder, T: type): T {.raises: [SerializationError]} =
  ## This method should not be used directly.
  ## It is needed because `genFunction` create tuple
  ## with object instead of creating a flat tuple with
  ## object fields.
  when T is object:
    decoder.decodeObject(T)
  else:
    decoder.decode(T)

proc readValue*[T](
    r: var AbiReader, value: var T) {.raises: [SerializationError]} =
  var decoder = AbiDecoder.init(r.getStream, r.maxMemoryFactor)
  type StInts = StInt | StUint

  when T is object and T is not StInts:
    value = decodeObject(decoder, T)
  else:
    value = decoder.decode(T)

# Keep the old encode functions for compatibility
func decode*(input: openArray[byte], baseOffset, offset: int, to: var StUint): int {.deprecated: "use Abi.decode instead"} =
  when to.bits > 256:
    # https://docs.soliditylang.org/en/latest/abi-spec.html#types
    {.error: "uint<M> has to fit into a single slot".}
  const meaningfulLen = to.bits div 8
  let offset = offset + baseOffset + abiSlotSize - meaningfulLen
  to = type(to).fromBytesBE(input.toOpenArray(offset, offset + meaningfulLen - 1))
  abiSlotSize

func decode*[N](input: openArray[byte], baseOffset, offset: int, to: var StInt[N]): int {.deprecated: "use Abi.decode instead"} =
  when N > 256:
    # https://docs.soliditylang.org/en/latest/abi-spec.html#types
    {.error: "int<M> has to fit into a single slot".}
  const meaningfulLen = N div 8
  let offset = offset + baseOffset + abiSlotSize - meaningfulLen
  to = type(to).fromBytesBE(input.toOpenArray(offset, offset + meaningfulLen - 1))
  abiSlotSize

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
  when N notin 1 .. abiSlotSize:
    # https://docs.soliditylang.org/en/latest/abi-spec.html#types
    {.error: "bytes<M> has to fit into a single slot".}
  let offset = baseOffset + offset
  assign(array[N, byte](to), input.toOpenArray(offset, offset + N - 1))
  abiSlotSize

func decode*(input: openArray[byte], baseOffset, offset: int, to: var Address): int {.inline, deprecated: "use Abi.decode instead".} =
  decodeFixed(input, baseOffset, offset, array[20, byte](to))

func decode*(input: openArray[byte], baseOffset, offset: int, to: var DynamicBytes): int {.deprecated: "use Abi.decode instead"} =
  var dataOffsetBig, dataLenBig: UInt256
  result = decode(input, baseOffset, offset, dataOffsetBig)
  let dataOffset = dataOffsetBig.truncate(int)
  discard decode(input, baseOffset, dataOffset, dataLenBig)
  let dataLen = dataLenBig.truncate(int)
  let actualDataOffset = baseOffset + dataOffset + 32
  # TODO: Check data len, and raise?
  to = typeof(to)(input[actualDataOffset ..< actualDataOffset + dataLen])

func decode*(input: openArray[byte], baseOffset, offset: int, to: var string): int {.deprecated: "use Abi.decode instead"} =
  var dataOffsetBig, dataLenBig: UInt256
  result = decode(input, baseOffset, offset, dataOffsetBig)
  let dataOffset = dataOffsetBig.truncate(int)
  discard decode(input, baseOffset, dataOffset, dataLenBig)
  let dataLen = dataLenBig.truncate(int)
  let actualDataOffset = baseOffset + dataOffset + 32
  to = string.fromBytes(input.toOpenArray(actualDataOffset, actualDataOffset + dataLen - 1))

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
