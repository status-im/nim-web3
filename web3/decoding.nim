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
    input: InputStream

  UInt = AbiUnsignedInt | StUint

template basetype(Range: type range): untyped =
  when Range isnot AbiUnsignedInt: {.error: "only uint ranges supported".}
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
  ## We want to make sure that even if the data is smaller than the ABI slot size,
  ## it will occupy at least one slot size. That's why we have:
  ## size + abiSlotSize - 1
  ## Then we divide it by abiSlotSize to get the number of slots needed.
  ## And finally, we multiply it by abiSlotSize to get the total size in bytes.
  var buf = newSeq[byte]((size + abiSlotSize - 1) div abiSlotSize * abiSlotSize)

  try:
    if not decoder.input.readInto(buf):
      raise newException(SerializationError, "reading past end of bytes")
  except IOError as e:
    raise newException(SerializationError, "Failed to read bytes: " & e.msg)

  return buf

template checkLeftPadding(buf: openArray[byte], padding: int, expected: uint8) =
  for i in 0 ..< padding:
    if buf[i] != expected:
      raise newException(SerializationError, "invalid padding found")

template checkRightPadding(buf: openArray[byte], paddingStart: int, paddingEnd: int) =
  for i in paddingStart ..< paddingEnd:
    if buf[i] != 0x00'u8:
      raise newException(SerializationError, "invalid padding found")

proc decode(_: var AbiDecoder, _: type int): int {.error:
  "ABI: plain 'int' is forbidden. Use int8/16/32/64 or Int256."}

proc decode(_: var AbiDecoder, _: type uint): uint {.error:
  "ABI: plain 'uint' is forbidden. Use uint8/16/32/64 or UInt256."}

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

proc decode(decoder: var AbiDecoder, T: type AbiSignedInt): T {.raises: [SerializationError].} =
  var buf = decoder.read(sizeof(T))

  let padding = abiSlotSize - sizeof(T)
  let unsigned = StUint[sizeof(T) * 8].fromBytesBE(buf[padding ..< abiSlotSize])
  let max = high(T).stuint(sizeof(T) * 8)

  if unsigned.truncate(T) > 0 and unsigned > max:
    raise newException(SerializationError, "overflow when decoding trying to decode " & $unsigned & " into " & $(sizeof(T) * 8) & " bits")

  let value = cast[T](unsigned)
  let expectedPadding = if value < 0: 0xFF'u8 else: 0x00'u8
  checkLeftPadding(buf, padding, expectedPadding)

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

  let buf = decoder.read(arr.len)
  arr[0..<arr.len] = buf[0..<arr.len]
  checkRightPadding(buf, arr.len, buf.len)

  return arr

proc decode(decoder: var AbiDecoder, T: type seq[byte]): T {.raises: [SerializationError].} =
  let len = decoder.decode(uint64)

  if len == 0:
    return T.default

  let buf = decoder.read(len.int)
  checkRightPadding(buf, len.int, buf.len)

  return buf[0 ..< len]

proc decode(decoder: var AbiDecoder, T: type string): T {.raises: [SerializationError].} =
  string.fromBytes(decoder.decode(seq[byte]))

proc decode[T: tuple](decoder: var AbiDecoder, _: typedesc[T]): T {.raises: [SerializationError].}

proc decode[T: distinct](decoder: var AbiDecoder, _: type T): T {.raises: [SerializationError].} =
  T(decoder.decode(distinctBase T))


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
  if isDynamic(T):
    # The size of the static array is passed as an argument to the decoder.
    # For the dynamic array, the size is should be None,
    # and the decoder will read the size from the input stream.
    var len = if size.isNone: decoder.decode(uint64) else: size.get()

    var offsets = newSeq[uint64](len)
    for i in 0..<len:
      offsets[i] = decoder.decode(uint64)

    result = newSeq[T](len)
    for i in 0..<len:
      let pos = decoder.input.pos()
      if offsets[i].int > pos:
        decoder.input.advance(offsets[i].int - pos)
      result[i] = decoder.decode(T)

    return result
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
  let arity = type(res).arity
  var offsets = newSeq[uint64](arity + 1)
  var i = 0

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
      let pos = decoder.input.pos()
      if offsets[i].int > pos:
        decoder.input.advance(offsets[i].int - pos)
      field = decoder.decode(typeof(field))

    inc i

  discard offsets

  return res

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
  var offsets = newSeq[uint64](totalSerializedFields(T))

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
      let pos = decoder.input.pos()
      if offsets[i].int > pos:
        decoder.input.advance(offsets[i].int - pos)
      fieldValue = decoder.decode(typeof(fieldValue))
    inc i

  resultObj

proc decode*(decoder: var AbiDecoder, T: type): T {.raises: [SerializationError]} =
  ## This method should not be used directly.
  ## It is needed because `genFunction` create tuple
  ## with object instead of creating a flat tuple with
  ## object fields.
  when T is object:
    let value = decoder.decodeObject(T)
    return value
  else:
    let value = decoder.decode(T)
    decoder.finish()
    return value

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
    resultObj = decodeObject(decoder, T)
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
