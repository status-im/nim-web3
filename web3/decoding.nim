import
    std/typetraits,
    stint,
    faststreams/inputs,
    stew/[byteutils, endians2],
    ./eth_api_types,
    ./abi_utils

type
  AbiDecoder2* = object
    input: InputStream
    len: int
  AbiDecoder* = object
    bytes: seq[byte]
    stack: seq[Tuple]
    last: int
  Tuple = object
    start: int
    index: int
  Padding = enum
    padLeft,
    padRight
  UInt = SomeUnsignedInt | StUint
  Int = SomeSignedInt | StInt
  AbiDecodingError* = object of CatchableError

func read*(decoder: var AbiDecoder, T: type): T {.raises: [AbiDecodingError].}

func init(_: type Tuple, offset: int): Tuple =
  Tuple(start: offset, index: offset)

func init(_: type AbiDecoder, bytes: seq[byte], offset=0): AbiDecoder =
  AbiDecoder(bytes: bytes, stack: @[Tuple.init(offset)])

func currentTuple(decoder: var AbiDecoder): var Tuple =
  decoder.stack[^1]

func index(decoder: var AbiDecoder): var int =
  decoder.currentTuple.index

func `index=`(decoder: var AbiDecoder, value: int) =
  decoder.currentTuple.index = value

func startTuple*(decoder: var AbiDecoder) =
  decoder.stack.add(Tuple.init(decoder.index))

func finishTuple*(decoder: var AbiDecoder) =
  doAssert decoder.stack.len > 1, "unable to finish a tuple that hasn't started"
  let tupl = decoder.stack.pop()
  decoder.index = tupl.index

func updateLast(decoder: var AbiDecoder, index: int) =
  if index > decoder.last:
    decoder.last = index

func advance(decoder: var AbiDecoder, amount: int): void {.raises: [AbiDecodingError].} =
  decoder.index += amount
  decoder.updateLast(decoder.index)
  if decoder.index > decoder.bytes.len:
    raise newException(AbiDecodingError, "reading past end of bytes")

func skipPadding(decoder: var AbiDecoder, amount: int): void {.raises: [AbiDecodingError].} =
  let index = decoder.index
  decoder.advance(amount)
  for i in index..<index+amount:
    if decoder.bytes[i] notin [0x00'u8, 0xFF'u8]:
      raise newException(AbiDecodingError, "invalid padding found")

func read(decoder: var AbiDecoder, amount: int, padding=padLeft): seq[byte] {.raises: [AbiDecodingError].} =
  let padlen = (32 - amount mod 32) mod 32
  if padding == padLeft:
    decoder.skipPadding(padlen)
  let index = decoder.index
  decoder.advance(amount)
  result = decoder.bytes[index..<index+amount]
  if padding == padRight:
    decoder.skipPadding(padlen)

template unsigned*(T: type SomeSignedInt): type SomeUnsignedInt =
  when T is int8: uint8
  elif T is int16: uint16
  elif T is int32: uint32
  elif T is int64: uint64
  else: {.error "unsupported signed integer type".}

template unsigned*(T: type StInt): type StUint =
  StUint[T.bits]

template basetype(Range: type range): untyped =
  when Range isnot SomeUnsignedInt: {.error: "only uint ranges supported".}
  elif sizeof(Range) == sizeof(uint8): uint8
  elif sizeof(Range) == sizeof(uint16): uint16
  elif sizeof(Range) == sizeof(uint32): uint32
  elif sizeof(Range) == sizeof(uint64): uint64
  else:
    {.error "unsupported range type".}

proc finish(decoder: var AbiDecoder2) =
  if decoder.input.readable:
    raise newException(AbiDecodingError, "unread trailing bytes found")

proc read(decoder: var AbiDecoder2, size = abiSlotSize): seq[byte] =
  var buf = newSeq[byte]((size + 31) div 32 * 32)

  if not decoder.input.readInto(buf):
    raise newException(AbiDecodingError, "reading past end of bytes")

  return buf

template checkLeftPadding(buf: openArray[byte], padding: int, expected: uint8) =
  for i in 0 ..< padding:
    if buf[i] != expected:
      raise newException(AbiDecodingError, "invalid padding found")

template checkRightPadding(buf: openArray[byte], paddingStart: int, paddingEnd: int) =
  for i in paddingStart ..< paddingEnd:
    if buf[i] != 0x00'u8:
      raise newException(AbiDecodingError, "invalid padding found")

proc decode(decoder: var AbiDecoder2, T: type UInt): T =
  var buf = decoder.read(sizeof(T))

  let padding = abiSlotSize - sizeof(T)
  checkLeftPadding(buf, padding, 0x00'u8)

  return T.fromBytesBE(buf[padding ..< abiSlotSize])

proc decode(decoder: var AbiDecoder2, T: type StInt): T =
  var buf = decoder.read(sizeof(T))

  let padding = abiSlotSize - sizeof(T)
  let value = T.fromBytesBE(buf[padding ..< abiSlotSize])

  let b = if value.isNegative: 0xFF'u8 else: 0x00'u8
  checkLeftPadding(buf, padding, b)

  return value

proc decode(decoder: var AbiDecoder2, T: type SomeSignedInt): T =
  var buf = decoder.read(sizeof(T))

  let padding = abiSlotSize - sizeof(T)
  let unsigned = T.toUnsigned.fromBytesBE(buf[padding ..< abiSlotSize])
  let value = cast[T](unsigned)

  let b = if value < 0: 0xFF'u8 else: 0x00'u8
  checkLeftPadding(buf, padding, b)

  return value

proc decode(decoder: var AbiDecoder2, T: type bool): T =
  case decoder.decode(uint8)
    of 0: false
    of 1: true
    else: raise newException(AbiDecodingError, "invalid boolean value")

proc decode(decoder: var AbiDecoder2, T: type range): T  =
  let value = decoder.decode(basetype(T))
  if value in T.low..T.high:
    T(value)
  else:
    raise newException(AbiDecodingError, "value not in range")

proc decode(decoder: var AbiDecoder2, T: type enum): T =
  let value = decoder.decode(uint64)
  if value in T.low.uint64..T.high.uint64:
    T(value)
  else:
    raise newException(AbiDecodingError, "invalid enum value")

proc decode(decoder: var AbiDecoder2, T: type Address): T=
  var bytes: array[sizeof(T), byte]
  let padding = abiSlotSize - sizeof(T)
  bytes[0..<sizeof(T)] =(decoder.read(sizeof(T)))[padding ..< abiSlotSize]
  T(bytes)

proc decode[I](decoder: var AbiDecoder2, T: type array[I, byte]): T =
  var arr: T
  let bytes = (arr.len + 31) div 32 * 32
  let buf = decoder.read(bytes)
  arr[0..<arr.len] = buf[0..<arr.len]

  checkRightPadding(buf, arr.len, bytes)

  return arr

proc decode(decoder: var AbiDecoder2, T: type seq[byte]): T =
  let len = decoder.decode(uint64)
  let bytes = ((len + 31) div 32 * 32).int
  let buf = decoder.read(bytes)

  checkRightPadding(buf, len.int, bytes)

  return buf[0 ..< len]

proc decode(decoder: var AbiDecoder2, T: type string): T =
  string.fromBytes(decoder.decode(seq[byte]))

proc decode[T: distinct](decoder: var AbiDecoder2, _: type T): T =
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
proc decodeCollection[T](decoder: var AbiDecoder2, size: Opt[uint64]): seq[T] =
  if isDynamic(T):
    # Since we cannot seek the position in the input stream,
    # we need to read the whole buffer first.
    var buf: seq[byte] = newSeq[byte](decoder.len)
    if not decoder.input.readInto(buf):
      raise newException(AbiDecodingError, "reading past end of bytes")

    var offset = 0.uint64
    var len = 0.uint64
    if size.isNone:
      # Get the length of the dynamic array from the first slot.
      # Add assign one slot to the offset,
      # so that the first element starts at the second slot.
      len = AbiDecoder2.decode(buf[0 ..< abiSlotSize], uint64)
      offset = 1
    else:
      len = size.get()

    var offsets = newSeq[uint64](len)
    for i in 0..<len:
      let start = abiSlotSize * (i + offset)
      let value = AbiDecoder2.decode(buf[start ..< start + abiSlotSize], uint64)
      offsets[i] = value + (abiSlotSize * offset).uint64

    result = newSeq[T](len)
    for i in 0..<len:
      let start = offsets[i].int
      # Here we need to take only the data that is between the offsets.
      let stop = if i+1 < result.len.uint64: offsets[i+1].int else: buf.len
      let data = buf[start ..< stop]
      var decoder = AbiDecoder2(input: memoryInput(data), len: data.len)
      result[i] = decoder.decode(T)

    return result
  else:
    let len = if size.isNone: decoder.decode(uint64) else: size.get()
    result = newSeq[T](len)
    for i in 0..<len:
      result[i] = decoder.decode(T)

    return result

proc decode[T](decoder: var AbiDecoder2, _: type seq[T]): seq[T] =
  return decodeCollection[T](decoder, Opt.none(uint64))

proc decode[I,T](decoder: var AbiDecoder2, _: type array[I,T]): array[I,T] =
  var result: array[I, T]
  let data = decodeCollection[T](decoder, Opt.some(result.len.uint64))
  for i in 0..<result.len:
    result[i] = data[i]

  return result

proc decode*(_: type AbiDecoder2, bytes: seq[byte], T: type): T =
  var decoder = AbiDecoder2(input: memoryInput(bytes), len: bytes.len)
  let value = decoder.decode(T)
  decoder.finish()
  return value

func unsigned*(value: SomeSignedInt): SomeUnsignedInt =
  cast[typeof(value).unsigned](value)

func unsigned*[bits](value: StInt[bits]): StUint[bits] =
  cast[typeof(value).unsigned](value)

func decode(decoder: var AbiDecoder, T: type UInt): T =
  T.fromBytesBE(decoder.read(sizeof(T)))

func decode(decoder: var AbiDecoder, T: type Int): T =
  let unsigned = decoder.read(T.unsigned)
  cast[T](unsigned)

template basetype(Range: type range): untyped =
  when Range isnot SomeUnsignedInt: {.error: "only uint ranges supported".}
  elif sizeof(Range) == sizeof(uint8): uint8
  elif sizeof(Range) == sizeof(uint16): uint16
  elif sizeof(Range) == sizeof(uint32): uint32
  elif sizeof(Range) == sizeof(uint64): uint64
  else: {.error "unsupported range type".}

func decode(decoder: var AbiDecoder, T: type range): T {.raises: [AbiDecodingError].} =
  let bytes = decoder.read(sizeof(T))
  let value = basetype(T).fromBytesBE(bytes)
  if value in T.low..T.high:
    T(value)
  else:
    raise newException(AbiDecodingError, "value not in range")

func decode(decoder: var AbiDecoder, T: type bool): T {.raises: [AbiDecodingError].} =
  case decoder.read(uint8)
    of 0: false
    of 1: true
    else: raise newException(AbiDecodingError, "invalid boolean value")

func decode(decoder: var AbiDecoder, T: type enum): T {.raises: [AbiDecodingError].} =
  let value = decoder.read(uint64)
  if value in T.low.uint64..T.high.uint64:
    T(value)
  else:
    raise newException(AbiDecodingError, "invalid enum value")

func decode(decoder: var AbiDecoder, T: type Address): T {.raises: [AbiDecodingError].} =
  var bytes: array[20, byte]
  bytes[0..<20] =(decoder.read(20))[0..<20]
  T(bytes)

func decode[I](decoder: var AbiDecoder, T: type array[I, byte]): T {.raises: [AbiDecodingError].} =
  var arr: T
  arr[0..<arr.len] = decoder.read(arr.len, padRight)
  arr

func decode(decoder: var AbiDecoder, T: type seq[byte]): T {.raises: [AbiDecodingError].} =
  let len = decoder.read(uint64)
  decoder.read(len.int, padRight)

func decode[T: tuple](decoder: var AbiDecoder, _: typedesc[T]): T {.raises: [AbiDecodingError].} =
  var tupl: T
  decoder.startTuple()
  for element in tupl.fields:
    element = decoder.read(typeof(element))
  decoder.finishTuple()
  tupl

func decode[T](decoder: var AbiDecoder, _: type seq[T]): seq[T] {.raises: [AbiDecodingError].} =
  var sequence: seq[T]
  let len = decoder.read(uint64)
  decoder.startTuple()
  for _ in 0..<len:
    sequence.add(decoder.read(T))
  decoder.finishTuple()
  sequence

func decode[I,T](decoder: var AbiDecoder, _: type array[I,T]): array[I,T] {.raises: [AbiDecodingError].} =
  var arr: array[I, T]
  decoder.startTuple()
  for i in 0..<arr.len:
    arr[i] = decoder.read(T)
  decoder.finishTuple()
  arr

func decode(decoder: var AbiDecoder, T: type string): T {.raises: [AbiDecodingError].} =
  string.fromBytes(decoder.read(seq[byte]))

func decode[T: distinct](decoder: var AbiDecoder, _: type T): T {.raises: [AbiDecodingError].} =
  T(decoder.read(distinctBase T))

func readOffset(decoder: var AbiDecoder): int {.raises: [AbiDecodingError].} =
  let offset = decoder.read(uint64)
  decoder.currentTuple.start + offset.int

func readTail*(decoder: var AbiDecoder, T: type): T {.raises: [AbiDecodingError].} =
  let offset = decoder.readOffset()
  var tailDecoder = AbiDecoder.init(decoder.bytes, offset.int)
  result = tailDecoder.read(T)
  decoder.updateLast(tailDecoder.last)

func read*(decoder: var AbiDecoder, T: type): T {.raises: [AbiDecodingError].} =
  const dynamic = isDynamic(typeof(result))
  if dynamic and decoder.stack.len > 1:
    decoder.readTail(T)
  else:
    decoder.decode(T)

func finish(decoder: var AbiDecoder): void {.raises: [AbiDecodingError].} =
  doAssert decoder.stack.len == 1, "not all tuples were finished"
  doAssert decoder.last mod 32 == 0, "encoding invariant broken"
  if decoder.last != decoder.bytes.len:
    raise newException(AbiDecodingError, "unread trailing bytes found")

func decode*(_: type AbiDecoder, bytes: seq[byte], T: type): T {.raises: [AbiDecodingError].} =
  var decoder = AbiDecoder.init(bytes)
  var value = decoder.decode(T)
  decoder.finish()
  value

func decodeRecord*(_: type AbiDecoder, bytes: seq[byte], T: type): T {.raises: [AbiDecodingError].} =
  var decoder = AbiDecoder.init(bytes)
  var res: T
  decoder.startTuple()
  for value in res.fields:
    value = decoder.read(typeof(value))
  decoder.finishTuple()
  decoder.finish()
  res