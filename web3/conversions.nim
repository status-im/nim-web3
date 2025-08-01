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
  json_rpc/jsonmarshal,
  json_serialization/pkg/results,
  json_serialization,
  ./primitives,
  ./engine_api_types,
  ./eth_api_types,
  ./execution_types

import eth/common/eth_types_json_serialization

export
  results,
  json_serialization,
  jsonmarshal

export eth_types_json_serialization except Topic

#------------------------------------------------------------------------------
# JrpcConv configuration
#------------------------------------------------------------------------------

JrpcConv.automaticSerialization(string, true)
JrpcConv.automaticSerialization(JsonString, true)
JrpcConv.automaticSerialization(ref, true)
JrpcConv.automaticSerialization(seq, true)
JrpcConv.automaticSerialization(bool, true)
JrpcConv.automaticSerialization(float64, true)
JrpcConv.automaticSerialization(array, true)

#------------------------------------------------------------------------------
# eth_api_types
#------------------------------------------------------------------------------

SyncObject.useDefaultSerializationIn JrpcConv
Withdrawal.useDefaultSerializationIn JrpcConv
AccessPair.useDefaultSerializationIn JrpcConv
AccessListResult.useDefaultSerializationIn JrpcConv
LogObject.useDefaultSerializationIn JrpcConv
StorageProof.useDefaultSerializationIn JrpcConv
ProofResponse.useDefaultSerializationIn JrpcConv
FilterOptions.useDefaultSerializationIn JrpcConv
TransactionArgs.useDefaultReaderIn JrpcConv
FeeHistoryResult.useDefaultSerializationIn JrpcConv
Authorization.useDefaultSerializationIn JrpcConv

BlockHeader.useDefaultSerializationIn JrpcConv
BlockObject.useDefaultSerializationIn JrpcConv
TransactionObject.useDefaultSerializationIn JrpcConv
ReceiptObject.useDefaultSerializationIn JrpcConv

#------------------------------------------------------------------------------
# engine_api_types
#------------------------------------------------------------------------------

WithdrawalV1.useDefaultSerializationIn JrpcConv
ExecutionPayloadV1.useDefaultSerializationIn JrpcConv
ExecutionPayloadV2.useDefaultSerializationIn JrpcConv
ExecutionPayloadV1OrV2.useDefaultSerializationIn JrpcConv
ExecutionPayloadV3.useDefaultSerializationIn JrpcConv
BlobsBundleV1.useDefaultSerializationIn JrpcConv
BlobsBundleV2.useDefaultSerializationIn JrpcConv
BlobAndProofV1.useDefaultSerializationIn JrpcConv
BlobAndProofV2.useDefaultSerializationIn JrpcConv
ExecutionPayloadBodyV1.useDefaultSerializationIn JrpcConv
PayloadAttributesV1.useDefaultSerializationIn JrpcConv
PayloadAttributesV2.useDefaultSerializationIn JrpcConv
PayloadAttributesV3.useDefaultSerializationIn JrpcConv
PayloadAttributesV1OrV2.useDefaultSerializationIn JrpcConv
PayloadStatusV1.useDefaultSerializationIn JrpcConv
ForkchoiceStateV1.useDefaultSerializationIn JrpcConv
ForkchoiceUpdatedResponse.useDefaultSerializationIn JrpcConv
GetPayloadV2Response.useDefaultSerializationIn JrpcConv
GetPayloadV2ResponseExact.useDefaultSerializationIn JrpcConv
GetPayloadV3Response.useDefaultSerializationIn JrpcConv
GetPayloadV4Response.useDefaultSerializationIn JrpcConv
GetPayloadV5Response.useDefaultSerializationIn JrpcConv
ClientVersionV1.useDefaultSerializationIn JrpcConv

#------------------------------------------------------------------------------
# execution_types
#------------------------------------------------------------------------------

ExecutionPayload.useDefaultSerializationIn JrpcConv
PayloadAttributes.useDefaultSerializationIn JrpcConv
GetPayloadResponse.useDefaultSerializationIn JrpcConv

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

when not declared(json_serialization.streamElement): # json_serialization < 0.3.0
  template streamElement(w: var JsonWriter, s, body: untyped) =
    template s: untyped = w.stream
    body

proc writeHexValue(w: var JsonWriter, v: openArray[byte])
      {.gcsafe, raises: [IOError].} =
  w.streamElement(s):
    s.write "\"0x"
    s.writeHex v
    s.write "\""

#------------------------------------------------------------------------------
# Well, both rpc and chronicles share the same encoding of these types
#------------------------------------------------------------------------------

type CommonJsonFlavors = JrpcConv | DefaultFlavor

proc writeValue*[F: CommonJsonFlavors](w: var JsonWriter[F], v: DynamicBytes)
      {.gcsafe, raises: [IOError].} =
  writeHexValue w, distinctBase(v)

proc writeValue*[N](w: var JsonWriter[JrpcConv], v: FixedBytes[N])
      {.gcsafe, raises: [IOError].} =
  writeHexValue w, distinctBase(v)

proc writeValue*(w: var JsonWriter[JrpcConv], v: Address)
      {.gcsafe, raises: [IOError].} =
  writeHexValue w, distinctBase(v)

proc writeValue*(w: var JsonWriter[JrpcConv], v: Hash32)
      {.gcsafe, raises: [IOError].} =
  writeHexValue w, distinctBase(v)

proc writeValue*[F: CommonJsonFlavors](w: var JsonWriter[F], v: TypedTransaction)
      {.gcsafe, raises: [IOError].} =
  writeHexValue w, distinctBase(v)

proc writeValue*[F: CommonJsonFlavors](w: var JsonWriter[F], v: RlpEncodedBytes)
      {.gcsafe, raises: [IOError].} =
  writeHexValue w, distinctBase(v)

proc writeValue*[F: CommonJsonFlavors](
    w: var JsonWriter[F], v: Quantity
) {.gcsafe, raises: [IOError].} =
  w.streamElement(s):
    s.write "\"0x"
    s.toHex(distinctBase v)
    s.write "\""

proc readValue*[F: CommonJsonFlavors](r: var JsonReader[F], val: var DynamicBytes)
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  wrapValueError:
    val = fromHex(DynamicBytes, r.parseString())

proc readValue*[N](r: var JsonReader[JrpcConv], val: var FixedBytes[N])
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  wrapValueError:
    val = fromHex(FixedBytes[N], r.parseString())

proc readValue*(r: var JsonReader[JrpcConv], val: var Address)
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  wrapValueError:
    val = fromHex(Address, r.parseString())

proc readValue*(r: var JsonReader[JrpcConv], val: var Hash32)
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  wrapValueError:
    val = fromHex(Hash32, r.parseString())

proc readValue*[F: CommonJsonFlavors](r: var JsonReader[F], val: var TypedTransaction)
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  wrapValueError:
    let hexStr = r.parseString()
    if hexStr != "0x":
      # skip empty hex
      val = TypedTransaction hexToSeqByte(hexStr)

proc readValue*[F: CommonJsonFlavors](r: var JsonReader[F], val: var RlpEncodedBytes)
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  wrapValueError:
    let hexStr = r.parseString()
    if hexStr != "0x":
      # skip empty hex
      val = RlpEncodedBytes hexToSeqByte(hexStr)

proc readValue*[F: CommonJsonFlavors](
    r: var JsonReader[F], val: var Quantity
) {.gcsafe, raises: [IOError, JsonReaderError].} =
  let hexStr = r.parseString()
  if hexStr.invalidQuantityPrefix:
    r.raiseUnexpectedValue("Quantity value has invalid leading 0")
  wrapValueError:
    val = typeof(val) strutils.fromHex[typeof(distinctBase(val))](hexStr)

proc readValue*[F: CommonJsonFlavors](r: var JsonReader[F], val: var PayloadExecutionStatus)
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  const enumStrings = static: getEnumStringTable(PayloadExecutionStatus)

  let tok = r.tokKind()
  if tok != JsonValueKind.String:
    r.raiseUnexpectedValue("Expect string but got=" & $tok)

  try:
    val = enumStrings[r.parseString()]
  except KeyError:
    r.raiseUnexpectedValue("Failed to parse PayloadExecutionStatus")

proc writeValue*[F: CommonJsonFlavors](w: var JsonWriter[F], v: PayloadExecutionStatus)
      {.gcsafe, raises: [IOError].} =
  w.writeValue($v)

proc writeValue*[F: CommonJsonFlavors](w: var JsonWriter[F], val: UInt256)
      {.gcsafe, raises: [IOError].} =
  w.writeValue("0x" & val.toHex)

# allows UInt256 to be passed as a json string
proc readValue*[F: CommonJsonFlavors](r: var JsonReader[F], val: var UInt256)
      {.gcsafe, raises: [IOError, JsonReaderError].} =
  # expects base 16 string, starting with "0x"
  let tok = r.tokKind
  if tok != JsonValueKind.String:
    r.raiseUnexpectedValue("Expected string for UInt256, got=" & $tok)
  let hexStr = r.parseString()
  if hexStr.len > 64 + 2: # including "0x"
    r.raiseUnexpectedValue("String value too long for UInt256: " & $hexStr.len)
  if hexStr.invalidQuantityPrefix:
    r.raiseUnexpectedValue("UInt256 value has invalid leading 0")
  wrapValueError:
    val = hexStr.parse(StUint[256], 16)

#------------------------------------------------------------------------------
# Exclusive to JrpcConv
#------------------------------------------------------------------------------

proc writeValue*(w: var JsonWriter[JrpcConv], v: uint64 | uint8)
      {.gcsafe, raises: [IOError].} =
  w.streamElement(s):
    s.write "\"0x"
    s.toHex(v)
    s.write "\""

proc readValue*(r: var JsonReader[JrpcConv], val: var (uint8 | uint64))
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  let hexStr = r.parseString()
  if hexStr.invalidQuantityPrefix:
    r.raiseUnexpectedValue("Uint64 value has invalid leading 0")
  wrapValueError:
    val = strutils.fromHex[typeof(val)](hexStr)

proc writeValue*(w: var JsonWriter[JrpcConv], v: seq[byte])
      {.gcsafe, raises: [IOError].} =
  writeHexValue w, v

proc readValue*(r: var JsonReader[JrpcConv], val: var seq[byte])
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  wrapValueError:
    let hexStr = r.parseString()
    if hexStr != "0x":
      # skip empty hex
      val = hexToSeqByte(hexStr)

proc readValue*(r: var JsonReader[JrpcConv], val: var RtBlockIdentifier)
       {.gcsafe, raises: [IOError, JsonReaderError].} =
  let hexStr = r.parseString()
  wrapValueError:
    if valid(hexStr):
      val = RtBlockIdentifier(
        kind: bidNumber, number: Quantity fromHex[uint64](hexStr))
    else:
      val = RtBlockIdentifier(kind: bidAlias, alias: hexStr)

proc writeValue*(w: var JsonWriter[JrpcConv], v: RtBlockIdentifier)
      {.gcsafe, raises: [IOError].} =
  case v.kind
  of bidNumber: w.writeValue(v.number)
  of bidAlias: w.writeValue(v.alias)

proc readValue*(r: var JsonReader[JrpcConv], val: var TxOrHash)
       {.gcsafe, raises: [IOError, SerializationError].} =
  if r.tokKind == JsonValueKind.String:
    val = TxOrHash(kind: tohHash, hash: r.readValue(Hash32))
  else:
    val = TxOrHash(kind: tohTx, tx: r.readValue(TransactionObject))

proc writeValue*(w: var JsonWriter[JrpcConv], v: TxOrHash)
      {.gcsafe, raises: [IOError].} =
  case v.kind
  of tohHash: w.writeValue(v.hash)
  of tohTx: w.writeValue(v.tx)

proc readValue*[T](r: var JsonReader[JrpcConv], val: var SingleOrList[T])
       {.gcsafe, raises: [IOError, SerializationError].} =
  let tok = r.tokKind()
  case tok
  of JsonValueKind.String:
    val = SingleOrList[T](kind: slkSingle)
    r.readValue(val.single)
  of JsonValueKind.Array:
    val = SingleOrList[T](kind: slkList)
    r.readValue(val.list)
  of JsonValueKind.Null:
    val = SingleOrList[T](kind: slkNull)
    r.parseNull()
  else:
    r.raiseUnexpectedValue("TopicOrList unexpected token kind =" & $tok)

proc writeValue*(w: var JsonWriter[JrpcConv], v: SingleOrList)
      {.gcsafe, raises: [IOError].} =
  case v.kind
  of slkNull: w.writeValue(JsonString("null"))
  of slkSingle: w.writeValue(v.single)
  of slkList: w.writeValue(v.list)

proc readValue*(r: var JsonReader[JrpcConv], val: var SyncingStatus)
       {.gcsafe, raises: [IOError, SerializationError].} =
  let tok = r.tokKind()
  case tok
  of JsonValueKind.Bool:
    val = SyncingStatus(syncing: r.parseBool())
  of JsonValueKind.Object:
    val = SyncingStatus(syncing: true)
    r.readValue(val.syncObject)
  else:
    r.raiseUnexpectedValue("SyncingStatus unexpected token kind =" & $tok)

proc writeValue*(w: var JsonWriter[JrpcConv], v: SyncingStatus)
      {.gcsafe, raises: [IOError].} =
  if not v.syncing:
    w.writeValue(false)
  else:
    w.writeValue(v.syncObject)

# Somehow nim2 refuse to generate automatically
proc readValue*(r: var JsonReader[JrpcConv], val: var Opt[seq[ReceiptObject]])
       {.gcsafe, raises: [IOError, SerializationError].} =
  mixin readValue

  if r.tokKind == JsonValueKind.Null:
    reset val
    r.parseNull()
  else:
    val.ok r.readValue(seq[ReceiptObject])

proc writeValue*(w: var JsonWriter[JrpcConv], v: Opt[seq[ReceiptObject]])
      {.gcsafe, raises: [IOError].} =
  mixin writeValue

  if v.isOk:
    w.writeValue v.get
  else:
    w.writeValue JsonString("null")

proc writeValue*(w: var JsonWriter[JrpcConv], v: TransactionArgs)
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
