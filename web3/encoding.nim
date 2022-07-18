import
  std/[typetraits, strutils, macros, math]

import
  stint, stew/byteutils, ./ethtypes

type
  EncodeResult* = tuple[dynamic: bool, data: string]

func encode*[bits: static[int]](x: StUint[bits]): EncodeResult =
  ## Encodes a `StUint` to a textual representation for use in the JsonRPC
  ## `sendTransaction` call.
  (dynamic: false, data: '0'.repeat((256 - bits) div 4) & x.dumpHex)

func encode*[bits: static[int]](x: StInt[bits]): EncodeResult =
  ## Encodes a `StInt` to a textual representation for use in the JsonRPC
  ## `sendTransaction` call.
  (dynamic: false,
  data:
    if x.isNegative:
      'f'.repeat((256 - bits) div 4) & x.dumpHex
    else:
      '0'.repeat((256 - bits) div 4) & x.dumpHex
  )

func decode*(input: string, offset: int, to: var StUint): int =
  let meaningfulLen = to.bits div 8 * 2
  to = type(to).fromHex(input[offset .. offset + meaningfulLen - 1])
  meaningfulLen

func decode*[N](input: string, offset: int, to: var StInt[N]): int =
  let meaningfulLen = N div 8 * 2
  fromHex(input[offset .. offset + meaningfulLen], to)
  meaningfulLen

func fixedEncode(a: openArray[byte]): EncodeResult =
  var padding = a.len mod 32
  if padding != 0: padding = 32 - padding
  result = (dynamic: false, data: "00".repeat(padding) & byteutils.toHex(a))

func encode*[N](b: FixedBytes[N]): EncodeResult = fixedEncode(array[N, byte](b))
func encode*(b: Address): EncodeResult = fixedEncode(array[20, byte](b))

func decodeFixed(input: string, offset: int, to: var openArray[byte]): int =
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

func encodeDynamic(v: openArray[byte]): EncodeResult =
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

macro makeTypeEnum(): untyped =
  ## This macro creates all the various types of Solidity contracts and maps
  ## them to the type used for their encoding. It also creates an enum to
  ## identify these types in the contract signatures, along with encoder
  ## functions used in the generated procedures.
  result = newStmtList()
  var lastpow2: int
  for i in countdown(256, 8, 8):
    let
      identUint = newIdentNode("Uint" & $i)
      identInt = newIdentNode("Int" & $i)
    if ceil(log2(i.float)) == floor(log2(i.float)):
      lastpow2 = i
    if i notin {256, 125}: # Int/UInt256/128 are already defined in stint. No need to repeat.
      result.add quote do:
        type
          `identUint`* = StUint[`lastpow2`]
          `identInt`* = StInt[`lastpow2`]
  let
    identUint = ident("Uint")
    identInt = ident("Int")
    identBool = ident("Bool")
  result.add quote do:
    type
      `identUint`* = UInt256
      `identInt`* = Int256
      `identBool`* = distinct Int256

  for m in countup(8, 256, 8):
    let
      identInt = ident("Int" & $m)
      identUint = ident("Uint" & $m)
      identFixed = ident "Fixed" & $m
      identUfixed = ident "Ufixed" & $m
      identT = ident "T"
    result.add quote do:
      # Fixed stuff is not actually implemented yet, these procedures don't
      # do what they are supposed to.
      type
        `identFixed`*[N: static[int]] = distinct `identInt`
        `identUfixed`*[N: static[int]] = distinct `identUint`

      # func to*(x: `identInt`, `identT`: typedesc[`identFixed`]): `identT` =
      #   T(x)

      # func to*(x: `identUint`, `identT`: typedesc[`identUfixed`]): `identT` =
      #   T(x)

      # func encode*[N: static[int]](x: `identFixed`[N]): EncodeResult =
      #   encode(`identInt`(x) * (10 ^ N).to(`identInt`))

      # func encode*[N: static[int]](x: `identUfixed`[N]): EncodeResult =
      #   encode(`identUint`(x) * (10 ^ N).to(`identUint`))

      # func decode*[N: static[int]](input: string, to: `identFixed`[N]): `identFixed`[N] =
      #   decode(input, `identInt`) div / (10 ^ N).to(`identInt`)

      # func decode*[N: static[int]](input: string, to: `identUfixed`[N]): `identFixed`[N] =
      #   decode(input, `identUint`) div / (10 ^ N).to(`identUint`)

  let
    identFixed = ident("Fixed")
    identUfixed = ident("Ufixed")
  result.add quote do:
    type
      `identFixed`* = distinct Int128
      `identUfixed`* = distinct UInt128
  for i in 1..256:
    let
      identBytes = ident("Bytes" & $i)
      identResult = ident "result"
    result.add quote do:
      type
        `identBytes`* = FixedBytes[`i`]

  #result.add newEnum(ident "FieldKind", fields, public = true, pure = true)

makeTypeEnum()

func parse*(T: type Bool, val: bool): T =
  let i = if val: 1 else: 0
  T i.i256

func `==`*(a: Bool, b: Bool): bool =
  Int256(a) == Int256(b)

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
  var count = input[0..64].decode(StUint)
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
