# nim-web3
# Copyright (c) 2019-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push gcsafe, raises: [].}

import
  std/strutils,
  stew/byteutils,
  faststreams/textio,
  ./cbormarshal,
  cbor_serialization/pkg/results,
  cbor_serialization,
  ./primitives,
  ./engine_api_types,
  ./eth_api_types,
  ./execution_types

import ./eth_types_cbor_serialization

export
  results,
  cbor_serialization,
  cbormarshal

export eth_types_cbor_serialization except Topic

#------------------------------------------------------------------------------
# JrpcConv configuration
#------------------------------------------------------------------------------

JrpcConv.defaultSerialization(string)
JrpcConv.defaultSerialization(ref)
JrpcConv.defaultSerialization(seq)
JrpcConv.defaultSerialization(bool)
JrpcConv.defaultSerialization(float64)
JrpcConv.defaultSerialization(array)
JrpcConv.defaultSerialization(uint64)

#JrpcConv.defaultSerialization(CborBytes)
JrpcConv.defaultSerialization(Result)

#------------------------------------------------------------------------------
# eth_api_types
#------------------------------------------------------------------------------

JrpcConv.defaultSerialization SyncObject
JrpcConv.defaultSerialization Withdrawal
JrpcConv.defaultSerialization AccessPair
JrpcConv.defaultSerialization AccessListResult
JrpcConv.defaultSerialization LogObject
JrpcConv.defaultSerialization StorageProof
JrpcConv.defaultSerialization ProofResponse
JrpcConv.defaultSerialization FilterOptions
JrpcConv.defaultSerialization TransactionArgs
JrpcConv.defaultSerialization FeeHistoryResult
JrpcConv.defaultSerialization Authorization

JrpcConv.defaultSerialization BlockHeader
JrpcConv.defaultSerialization BlockObject
JrpcConv.defaultSerialization TransactionObject
JrpcConv.defaultSerialization ReceiptObject
JrpcConv.defaultSerialization BlobScheduleObject
JrpcConv.defaultSerialization ConfigObject
JrpcConv.defaultSerialization EthConfigObject

#------------------------------------------------------------------------------
# engine_api_types
#------------------------------------------------------------------------------

JrpcConv.defaultSerialization WithdrawalV1
JrpcConv.defaultSerialization ExecutionPayloadV1
JrpcConv.defaultSerialization ExecutionPayloadV2
JrpcConv.defaultSerialization ExecutionPayloadV1OrV2
JrpcConv.defaultSerialization ExecutionPayloadV3
JrpcConv.defaultSerialization BlobsBundleV1
JrpcConv.defaultSerialization BlobsBundleV2
JrpcConv.defaultSerialization BlobAndProofV1
JrpcConv.defaultSerialization BlobAndProofV2
JrpcConv.defaultSerialization ExecutionPayloadBodyV1
JrpcConv.defaultSerialization PayloadAttributesV1
JrpcConv.defaultSerialization PayloadAttributesV2
JrpcConv.defaultSerialization PayloadAttributesV3
JrpcConv.defaultSerialization PayloadAttributesV1OrV2
JrpcConv.defaultSerialization PayloadStatusV1
JrpcConv.defaultSerialization ForkchoiceStateV1
JrpcConv.defaultSerialization ForkchoiceUpdatedResponse
JrpcConv.defaultSerialization GetPayloadV2Response
JrpcConv.defaultSerialization GetPayloadV2ResponseExact
JrpcConv.defaultSerialization GetPayloadV3Response
JrpcConv.defaultSerialization GetPayloadV4Response
JrpcConv.defaultSerialization GetPayloadV5Response
JrpcConv.defaultSerialization ClientVersionV1

#------------------------------------------------------------------------------
# execution_types
#------------------------------------------------------------------------------

JrpcConv.defaultSerialization ExecutionPayload
JrpcConv.defaultSerialization PayloadAttributes
JrpcConv.defaultSerialization GetPayloadResponse

#------------------------------------------------------------------------------
# Private helpers
#------------------------------------------------------------------------------

template invalidQuantityPrefix(s: string): bool =
  # https://ethereum.org/en/developers/docs/apis/json-rpc/#hex-value-encoding
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.3/src/engine/common.md#encoding
  # "When encoding quantities (integers, numbers): encode as hex, prefix with
  # "0x", the most compact representation (slight exception: zero should be
  # represented as "0x0")."
  #
  # strutils.parseHexStr treats 0x as optional otherwise. UInt256.parse treats
  # standalone "0x" as valid input.

  # TODO https://github.com/status-im/nimbus-eth2/pull/3850
  # requiring 0x prefis is okay, but can't yet enforce no-leading-zeros
  when false:
    (not s.startsWith "0x") or s == "0x" or (s != "0x0" and s.startsWith "0x0")
  else:
    (not s.startsWith "0x") or s == "0x"

template toHexImpl(hex, pos: untyped) =
  const
    hexChars  = "0123456789abcdef"
    maxDigits = sizeof(x) * 2

  var
    hex: array[maxDigits, char]
    pos = hex.len
    n = x

  template prepend(c: char) =
    dec pos
    hex[pos] = c

  for _ in 0 ..< maxDigits:
    prepend(hexChars[int(n and 0xF)])
    if n == 0: break
    n = n shr 4

  while hex[pos] == '0' and pos < hex.high:
    inc pos

func getEnumStringTable(enumType: typedesc): Table[string, enumType]
    {.compileTime.} =
  var res: Table[string, enumType]
  # Not intended for enums with ordinal holes or repeated stringification
  # strings.
  for value in enumType:
    res[$value] = value
  res

proc toHex(s: OutputStream, x: uint8|uint64) {.gcsafe, raises: [IOError].} =
  toHexImpl(hex, pos)
  write s, hex.toOpenArray(pos, static(hex.len - 1))

proc toHex2(x: uint8|uint64): string =
  toHexImpl(hex, pos)
  for i in pos ..< hex.len:
    result.add hex[i]

func encodeQuantity(x: uint64): string =
  toHexImpl(hex, pos)
  result = "0x"
  for i in pos..<hex.len:
    result.add hex[i]

template wrapValueError(body: untyped) =
  try:
    body
  except ValueError as exc:
    r.raiseUnexpectedValue(exc.msg)

func valid(hex: string): bool =
  var start = 0
  if hex.len >= 2:
    if hex[0] == '0' and hex[1] in {'x', 'X'}:
      start = 2
    else:
      return false
  else:
    return false

  for i in start..<hex.len:
    let x = hex[i]
    if x notin HexDigits: return false
  true

#when not declared(json_serialization.streamElement): # json_serialization < 0.3.0
#  template streamElement(w: var CborWriter, s, body: untyped) =
#    template s: untyped = w.stream
#    body

proc writeHexValue(w: var CborWriter, v: openArray[byte])
      {.gcsafe, raises: [IOError].} =
  # XXX stream cbor string; albeit this should really just w.writeValue(v)
  const hexChars = "0123456789abcdef"
  var s = "0x"
  for b in v:
    s.add hexChars[int b shr 4 and 0xF]
    s.add hexChars[int b and 0xF]
  w.writeValue(s)

#------------------------------------------------------------------------------
# Well, both rpc and chronicles share the same encoding of these types
#------------------------------------------------------------------------------

type CommonJsonFlavors = JrpcConv | DefaultFlavor

proc writeValue*[F: CommonJsonFlavors](w: var CborWriter[F], v: DynamicBytes)
      {.gcsafe, raises: [IOError].} =
  writeHexValue w, distinctBase(v)

proc writeValue*[N](w: var CborWriter[JrpcConv], v: FixedBytes[N])
      {.gcsafe, raises: [IOError].} =
  writeHexValue w, distinctBase(v)

proc writeValue*(w: var CborWriter[JrpcConv], v: Address)
      {.gcsafe, raises: [IOError].} =
  writeHexValue w, distinctBase(v)

proc writeValue*(w: var CborWriter[JrpcConv], v: Hash32)
      {.gcsafe, raises: [IOError].} =
  writeHexValue w, distinctBase(v)

proc writeValue*[F: CommonJsonFlavors](w: var CborWriter[F], v: TypedTransaction)
      {.gcsafe, raises: [IOError].} =
  writeHexValue w, distinctBase(v)

proc writeValue*[F: CommonJsonFlavors](w: var CborWriter[F], v: RlpEncodedBytes)
      {.gcsafe, raises: [IOError].} =
  writeHexValue w, distinctBase(v)

proc writeValue*[F: CommonJsonFlavors](
    w: var CborWriter[F], v: Quantity
) {.gcsafe, raises: [IOError].} =
  # XXX stream cbor string; albeit this should really just w.writeValue(v)
  w.writeValue(encodeQuantity(distinctBase(v)))
  #w.streamElement(s):
  #  s.write "\"0x"
  #  s.toHex(distinctBase v)
  #  s.write "\""

proc readValue*[F: CommonJsonFlavors](r: var CborReader[F], val: var DynamicBytes)
       {.gcsafe, raises: [IOError, CborReaderError].} =
  wrapValueError:
    val = fromHex(DynamicBytes, r.parseString())

proc readValue*[N](r: var CborReader[JrpcConv], val: var FixedBytes[N])
       {.gcsafe, raises: [IOError, CborReaderError].} =
  wrapValueError:
    val = fromHex(FixedBytes[N], r.parseString())

proc readValue*(r: var CborReader[JrpcConv], val: var Address)
       {.gcsafe, raises: [IOError, CborReaderError].} =
  wrapValueError:
    val = fromHex(Address, r.parseString())

proc readValue*(r: var CborReader[JrpcConv], val: var Hash32)
       {.gcsafe, raises: [IOError, CborReaderError].} =
  wrapValueError:
    val = fromHex(Hash32, r.parseString())

proc writeValue*(w: var CborWriter[JrpcConv], v: Number)
      {.gcsafe, raises: [IOError].} =
  w.writeValue distinctBase(v)

proc readValue*(r: var CborReader[JrpcConv], val: var Number)
       {.gcsafe, raises: [IOError, CborReaderError].} =
  wrapValueError:
    val = r.parseInt(uint64).Number
  
proc readValue*[F: CommonJsonFlavors](r: var CborReader[F], val: var TypedTransaction)
       {.gcsafe, raises: [IOError, CborReaderError].} =
  wrapValueError:
    let hexStr = r.parseString()
    if hexStr != "0x":
      # skip empty hex
      val = TypedTransaction hexToSeqByte(hexStr)

proc readValue*[F: CommonJsonFlavors](r: var CborReader[F], val: var RlpEncodedBytes)
       {.gcsafe, raises: [IOError, CborReaderError].} =
  wrapValueError:
    let hexStr = r.parseString()
    if hexStr != "0x":
      # skip empty hex
      val = RlpEncodedBytes hexToSeqByte(hexStr)

proc readValue*[F: CommonJsonFlavors](
    r: var CborReader[F], val: var Quantity
) {.gcsafe, raises: [IOError, CborReaderError].} =
  let hexStr = r.parseString()
  if hexStr.invalidQuantityPrefix:
    r.raiseUnexpectedValue("Quantity value has invalid leading 0")
  wrapValueError:
    val = typeof(val) strutils.fromHex[typeof(distinctBase(val))](hexStr)

proc readValue*[F: CommonJsonFlavors](r: var CborReader[F], val: var PayloadExecutionStatus)
       {.gcsafe, raises: [IOError, CborReaderError].} =
  const enumStrings = static: getEnumStringTable(PayloadExecutionStatus)

  let kind = r.parser.cborKind()
  if kind != CborValueKind.String:
    r.raiseUnexpectedValue("Expect string but got=" & $kind)

  try:
    val = enumStrings[r.parseString()]
  except KeyError:
    r.raiseUnexpectedValue("Failed to parse PayloadExecutionStatus")

proc writeValue*[F: CommonJsonFlavors](w: var CborWriter[F], v: PayloadExecutionStatus)
      {.gcsafe, raises: [IOError].} =
  w.writeValue($v)

proc writeValue*[F: CommonJsonFlavors](w: var CborWriter[F], val: UInt256)
      {.gcsafe, raises: [IOError].} =
  w.writeValue("0x" & val.toHex)

# allows UInt256 to be passed as a json string
proc readValue*[F: CommonJsonFlavors](r: var CborReader[F], val: var UInt256)
      {.gcsafe, raises: [IOError, CborReaderError].} =
  # expects base 16 string, starting with "0x"
  let kind = r.parser.cborKind()
  if kind != CborValueKind.String:
    r.raiseUnexpectedValue("Expected string for UInt256, got=" & $kind)
  let hexStr = r.parseString()
  if hexStr.len > 64 + 2: # including "0x"
    r.raiseUnexpectedValue("String value too long for UInt256: " & $hexStr.len)
  if hexStr.invalidQuantityPrefix:
    r.raiseUnexpectedValue("UInt256 value has invalid leading 0")
  wrapValueError:
    val = hexStr.parse(StUint[256], 16)

proc readValue*[F: CommonJsonFlavors](r: var CborReader[F], val: var seq[PrecompilePair])
      {.gcsafe, raises: [IOError, SerializationError].} =
  for k,v in readObject(r, string, Address):
    val.add PrecompilePair(name: k, address: v)

proc readValue*[F: CommonJsonFlavors](r: var CborReader[F], val: var seq[SystemContractPair])
      {.gcsafe, raises: [IOError, SerializationError].} =
  for k,v in readObject(r, string, Address):
    val.add SystemContractPair(name: k, address: v)

#------------------------------------------------------------------------------
# Exclusive to JrpcConv
#------------------------------------------------------------------------------

proc writeValue*(w: var CborWriter[JrpcConv], v: uint64 | uint8)
      {.gcsafe, raises: [IOError].} =
  w.writeValue("0x" & v.toHex2)
  #w.streamElement(s):
  #  s.write "\"0x"
  #  s.toHex(v)
  #  s.write "\""

proc readValue*(r: var CborReader[JrpcConv], val: var (uint8 | uint64))
       {.gcsafe, raises: [IOError, CborReaderError].} =
  let hexStr = r.parseString()
  if hexStr.invalidQuantityPrefix:
    r.raiseUnexpectedValue("Uint64 value has invalid leading 0")
  wrapValueError:
    val = strutils.fromHex[typeof(val)](hexStr)

proc writeValue*(w: var CborWriter[JrpcConv], v: seq[byte])
      {.gcsafe, raises: [IOError].} =
  writeHexValue w, v

proc readValue*(r: var CborReader[JrpcConv], val: var seq[byte])
       {.gcsafe, raises: [IOError, CborReaderError].} =
  wrapValueError:
    let hexStr = r.parseString()
    if hexStr != "0x":
      # skip empty hex
      val = hexToSeqByte(hexStr)

proc readValue*(r: var CborReader[JrpcConv], val: var RtBlockIdentifier)
       {.gcsafe, raises: [IOError, CborReaderError].} =
  let hexStr = r.parseString()
  wrapValueError:
    if valid(hexStr):
      val = RtBlockIdentifier(
        kind: bidNumber, number: Quantity fromHex[uint64](hexStr))
    else:
      val = RtBlockIdentifier(kind: bidAlias, alias: hexStr)

proc writeValue*(w: var CborWriter[JrpcConv], v: RtBlockIdentifier)
      {.gcsafe, raises: [IOError].} =
  case v.kind
  of bidNumber: w.writeValue(v.number)
  of bidAlias: w.writeValue(v.alias)

proc readValue*(r: var CborReader[JrpcConv], val: var TxOrHash)
       {.gcsafe, raises: [IOError, SerializationError].} =
  if r.parser.cborKind() == CborValueKind.String:
    val = TxOrHash(kind: tohHash, hash: r.readValue(Hash32))
  else:
    val = TxOrHash(kind: tohTx, tx: r.readValue(TransactionObject))

proc writeValue*(w: var CborWriter[JrpcConv], v: TxOrHash)
      {.gcsafe, raises: [IOError].} =
  case v.kind
  of tohHash: w.writeValue(v.hash)
  of tohTx: w.writeValue(v.tx)

proc readValue*[T](r: var CborReader[JrpcConv], val: var SingleOrList[T])
       {.gcsafe, raises: [IOError, SerializationError].} =
  let tok = r.parser.cborKind()
  case tok
  of CborValueKind.String:
    val = SingleOrList[T](kind: slkSingle)
    r.readValue(val.single)
  of CborValueKind.Array:
    val = SingleOrList[T](kind: slkList)
    r.readValue(val.list)
  of CborValueKind.Null:
    val = SingleOrList[T](kind: slkNull)
    discard r.readValue(CborSimpleValue)
  else:
    r.raiseUnexpectedValue("TopicOrList unexpected token kind =" & $tok)

proc writeValue*(w: var CborWriter[JrpcConv], v: SingleOrList)
      {.gcsafe, raises: [IOError].} =
  case v.kind
  of slkNull: w.writeValue(cborNull)
  of slkSingle: w.writeValue(v.single)
  of slkList: w.writeValue(v.list)

proc readValue*(r: var CborReader[JrpcConv], val: var SyncingStatus)
       {.gcsafe, raises: [IOError, SerializationError].} =
  let tok = r.parser.cborKind()
  case tok
  of CborValueKind.Bool:
    val = SyncingStatus(syncing: r.parseBool())
  of CborValueKind.Object:
    val = SyncingStatus(syncing: true)
    r.readValue(val.syncObject)
  else:
    r.raiseUnexpectedValue("SyncingStatus unexpected token kind =" & $tok)

proc writeValue*(w: var CborWriter[JrpcConv], v: SyncingStatus)
      {.gcsafe, raises: [IOError].} =
  if not v.syncing:
    w.writeValue(false)
  else:
    w.writeValue(v.syncObject)

# Somehow nim2 refuse to generate automatically
#proc readValue*(r: var CborReader[JrpcConv], val: var Opt[seq[ReceiptObject]])
#       {.gcsafe, raises: [IOError, SerializationError].} =
#  mixin readValue
#
#  if r.tokKind == JsonValueKind.Null:
#    reset val
#    r.parseNull()
#  else:
#    val.ok r.readValue(seq[ReceiptObject])

#proc writeValue*(w: var CborWriter[JrpcConv], v: Opt[seq[ReceiptObject]])
#      {.gcsafe, raises: [IOError].} =
#  mixin writeValue
#
#  if v.isOk:
#    w.writeValue v.get
#  else:
#    w.writeValue JsonString("null")

proc writeValue*(w: var CborWriter[JrpcConv], v: seq[PrecompilePair])
      {.gcsafe, raises: [IOError].} =
  w.beginObject()
  for x in v:
    w.writeMember(x.name, x.address)
  w.endObject()

proc writeValue*(w: var CborWriter[JrpcConv], v: seq[SystemContractPair])
      {.gcsafe, raises: [IOError].} =
  w.beginObject()
  for x in v:
    w.writeMember(x.name, x.address)
  w.endObject()

proc writeValue*(w: var CborWriter[JrpcConv], v: TransactionArgs)
      {.gcsafe, raises: [IOError].} =
  mixin writeValue
  var
    noInput = true
    noData = true

  w.beginObject()
  for k, val in fieldPairs(v):
    when k == "input":
      if v.input.isSome and noData:
        w.writeMember(k, val)
        noInput = false
    elif k == "data":
      if v.data.isSome and noInput:
        w.writeMember(k, val)
        noData = false
    else:
      w.writeMember(k, val)
  w.endObject()

func `$`*(v: Quantity): string {.inline.} =
  encodeQuantity(distinctBase(v))

func `$`*(v: TypedTransaction): string {.inline.} =
  "0x" & distinctBase(v).toHex

func `$`*(v: RlpEncodedBytes): string {.inline.} =
  "0x" & distinctBase(v).toHex

{.pop.}
