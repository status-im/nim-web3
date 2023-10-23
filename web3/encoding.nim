import
  std/macros,
  stint, ./ethtypes

func encode*[bits: static[int]](x: StUint[bits]): seq[byte] =
  @(x.toByteArrayBE())

func encode*[bits: static[int]](x: StInt[bits]): seq[byte] =
  @(x.toByteArrayBE())

func decode*(input: openarray[byte], baseOffset, offset: int, to: var StUint): int =
  const meaningfulLen = to.bits div 8
  let offset = offset + baseOffset
  to = type(to).fromBytesBE(input[offset ..< offset + meaningfulLen])
  meaningfulLen

func decode*[N](input: openarray[byte], baseOffset, offset: int, to: var StInt[N]): int =
  const meaningfulLen = N div 8
  let offset = offset + baseOffset
  to = type(to).fromBytesBE(input[offset ..< offset + meaningfulLen])
  meaningfulLen

func fixedEncode1(a: openArray[byte]): seq[byte] =
  var padding = a.len mod 32
  if padding != 0: padding = 32 - padding
  result.setLen(padding) # Zero fill padding
  result.add(a)

func encode*[N](b: FixedBytes[N]): seq[byte] = fixedEncode1(array[N, byte](b))
func encode*(b: Address): seq[byte] = fixedEncode1(array[20, byte](b))
func encode*[N](b: array[N, byte]): seq[byte] {.inline.} = fixedEncode1(b)

func decodeFixed(input: openarray[byte], baseOffset, offset: int, to: var openArray[byte]): int =
  let meaningfulLen = to.len
  var padding = to.len mod 32
  if padding != 0:
    padding = 32 - padding
  let offset = baseOffset + offset + padding
  if to.len != 0:
    copyMem(addr to, addr input[offset], meaningfulLen)
  meaningfulLen + padding

func decode*[N](input: openarray[byte], baseOffset, offset: int, to: var FixedBytes[N]): int {.inline.} =
  decodeFixed(input, baseOffset, offset, array[N, byte](to))

func decode*(input: openarray[byte], baseOffset, offset: int, to: var Address): int {.inline.} =
  decodeFixed(input, baseOffset, offset, array[20, byte](to))

func encodeDynamic(v: openArray[byte]): seq[byte] =
  result = encode(v.len.u256)
  result.add(v)
  for i in 0 ..< (v.len mod 32):
    result.add(0)

func encode*(x: DynamicBytes): seq[byte] {.inline.} =
  encodeDynamic(distinctBase x)

func encode*(x: seq[byte]): seq[byte] {.inline.} =
  encodeDynamic(x)

func decode*(input: openarray[byte], baseOffset, offset: int, to: var DynamicBytes): int {.inline.} =
  var dataOffsetBig, dataLenBig: UInt256
  result = decode(input, baseOffset, offset, dataOffsetBig)
  let dataOffset = dataOffsetBig.truncate(int)
  discard decode(input, baseOffset, dataOffset, dataLenBig)
  let dataLen = dataLenBig.truncate(int)
  # TODO: Check data len, and raise?
  let actualDataOffset = baseOffset + dataOffset + 32
  to = typeof(to)(@input[actualDataOffset ..< actualDataOffset + dataLen])

func decode*(input: openarray[byte], baseOffset, offset: int, to: var seq[byte]): int {.inline.} =
  var d: DynamicBytes[0, int.high]
  result = decode(input, baseOffset, offset, d)
  to = move(seq[byte](d))

func decode*(input: openarray[byte], baseOffset, offset: int, obj: var object): int

func decode*[T](input: openarray[byte], baseOffset, offset: int, to: var seq[T]): int {.inline.} =
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

proc isDynamicObject(T: typedesc): bool

template isDynamicType(a: typedesc): bool =
  when a is seq | openarray | string | DynamicBytes:
    true
  elif a is object:
    const r = isDynamicObject(a)
    r
  else:
    false

proc isDynamicObject(T: typedesc): bool =
  var a: T
  for v in fields(a):
    if isDynamicType(typeof(v)): return true
  false

func encode*(x: bool): seq[byte] = encode(x.int.u256)

func decode*(input: openarray[byte], baseOffset, offset: int, to: var bool): int =
  var i: Int256
  result = decode(input, baseOffset, offset, i)
  to = not i.isZero()

func decode*(input: openarray[byte], baseOffset, offset: int, obj: var object): int =
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

func encode*(x: tuple): seq[byte]

func encode*[T](x: openarray[T]): seq[byte] =
  result = encode(x.len.u256)
  when isDynamicType(T):
    result.setLen((1 + x.len) * 32)
    for i in 0 ..< x.len:
      let offset = result.len
      result &= encode(x[i])
      result[i .. i + 31] = encode(offset.u256)
  else:
    for i in 0 ..< x.len:
      result &= encode(x[i])

proc getTupleImpl(t: NimNode): NimNode =
  getTypeImpl(t)[1].getTypeImpl()

macro typeListLen*(t: typedesc[tuple]): int =
  newLit(t.getTupleImpl().len)

func encode*(x: tuple): seq[byte] =
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
