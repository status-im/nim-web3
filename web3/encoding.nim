import
  std/[typetraits, strutils, macros, math]

import
  stint, stew/byteutils, ./ethtypes

export ethtypes

type
  EncodeResult* = tuple[dynamic: bool, data: string]

func encode*[bits: static[int]](x: Stuint[bits]): EncodeResult =
  ## Encodes a `Stuint` to a textual representation for use in the JsonRPC
  ## `sendTransaction` call.
  (dynamic: false, data: '0'.repeat((256 - bits) div 4) & x.dumpHex)

func encode*[bits: static[int]](x: Stint[bits]): EncodeResult =
  ## Encodes a `Stint` to a textual representation for use in the JsonRPC
  ## `sendTransaction` call.
  (dynamic: false,
  data:
    if x.isNegative:
      'f'.repeat((256 - bits) div 4) & x.dumpHex
    else:
      '0'.repeat((256 - bits) div 4) & x.dumpHex
  )

func decode*(input: string, offset: int, to: var Stuint): int =
  let meaningfulLen = to.bits div 8 * 2
  to = type(to).fromHex(input[offset .. offset + meaningfulLen - 1])
  meaningfulLen

func decode*[N](input: string, offset: int, to: var Stint[N]): int =
  let meaningfulLen = N div 8 * 2
  fromHex(input[offset .. offset + meaningfulLen], to)
  meaningfulLen

func fixedEncode(a: openarray[byte]): EncodeResult =
  var padding = a.len mod 32
  if padding != 0: padding = 32 - padding
  result = (dynamic: false, data: "00".repeat(padding) & byteutils.toHex(a))

func encode*[N](b: FixedBytes[N]): EncodeResult = fixedEncode(array[N, byte](b))
func encode*(b: Address): EncodeResult = fixedEncode(array[20, byte](b))

func decodeFixed(input: string, offset: int, to: var openarray[byte]): int =
  let meaningfulLen = to.len * 2
  var padding = to.len mod 32
  if padding != 0: padding = (32 - padding) * 2
  let offset = offset + padding
  hexToByteArray(input[offset .. offset + meaningfulLen - 1], to)
  meaningfulLen + padding

func decode*[N](input: string, offset: int, to: var FixedBytes[N]): int {.inline.} =
  decodeFixed(input, offset, array[N, byte](to))

func decode*(input: string, offset: int, to: var Address): int {.inline.} =
  decodeFixed(input, offset, array[20, byte](to))

func encodeDynamic(v: openarray[byte]): EncodeResult =
  result.dynamic = true
  result.data = v.len.toHex(64).toLower
  for y in v:
    result.data &= y.toHex.toLower
  result.data &= "00".repeat(v.len mod 32)

func encode*(x: DynamicBytes): EncodeResult {.inline.} =
  encodeDynamic(distinctBase x)

func decode*(input: string, offset: int, to: var DynamicBytes): int {.inline.} =
  var dataOffset, dataLen: UInt256
  result = decode(input, offset, dataOffset)
  discard decode(input, dataOffset.truncate(int) * 2, dataLen)
  # TODO: Check data len, and raise?
  let actualDataOffset = (dataOffset.truncate(int) + 32) * 2
  to = typeof(to)(hexToSeqByte(input[actualDataOffset ..< actualDataOffset + dataLen.truncate(int) * 2]))

func encode*(x: Bool): EncodeResult = encode(Int256(x))
func decode*(input: string, offset: int, to: var Bool): int =
  let meaningfulLen = Int256.bits div 8 * 2
  to = Bool Int256.fromHex(input[offset .. offset + meaningfulLen - 1])
  meaningfulLen

func decode*(input: string, offset: int, obj: var object): int =
  var offset = offset
  for field in fields(obj):
    offset += decode(input, offset, field)

type
  Encodable = concept x
    encode(x) is EncodeResult

func encode*(x: seq[Encodable]): EncodeResult =
  result.dynamic = true
  result.data = x.len.toHex(64).toLower
  var
    offset = 32*x.len
    data = ""
  for i in x:
    let encoded = encode(i)
    if encoded.dynamic:
      result.data &= offset.toHex(64).toLower
      data &= encoded.data
    else:
      result.data &= encoded.data
    offset += encoded.data.len
  result.data &= data

func decode*[T](input: string, to: seq[T]): seq[T] =
  var count = input[0..64].decode(Stuint)
  result = newSeq[T](count)
  for i in 0..count:
    result[i] = input[i*64 .. (i+1)*64].decode(T)

func encode*(x: openArray[Encodable]): EncodeResult =
  result.dynamic = false
  result.data = ""
  var
    offset = 32*x.len
    data = ""
  for i in x:
    let encoded = encode(i)
    if encoded.dynamic:
      result.data &= offset.toHex(64).toLower
      data &= encoded.data
    else:
      result.data &= encoded.data
    offset += encoded.data.len

func decode*[T; I: static int](input: string, to: array[0..I, T]): array[0..I, T] =
  for i in 0..I:
    result[i] = input[i*64 .. (i+1)*64].decode(T)
