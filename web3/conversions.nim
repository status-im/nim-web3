# Copyright (c) 2019-2022 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at https://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at https://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import
  std/[json, options, strutils, strformat, tables, typetraits],
  stint, stew/byteutils, json_serialization, faststreams/textio,
  ethtypes, ethhexstrings,
  ./engine_api_types

from json_rpc/rpcserver import expect

template invalidQuantityPrefix(s: string): bool =
  # https://ethereum.org/en/developers/docs/apis/json-rpc/#hex-value-encoding
  # https://github.com/ethereum/execution-apis/blob/v1.0.0-beta.1/src/engine/specification.md#structures
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

func `%`*(n: Int256|UInt256): JsonNode = %("0x" & n.toHex)

# allows UInt256 to be passed as a json string
func fromJson*(n: JsonNode, argName: string, result: var UInt256) =
  # expects base 16 string, starting with "0x"
  n.kind.expect(JString, argName)
  let hexStr = n.getStr()
  if hexStr.len > 64 + 2: # including "0x"
    raise newException(ValueError, "Parameter \"" & argName & "\" value too long for UInt256: " & $hexStr.len)
  if hexStr.invalidQuantityPrefix:
    raise newException(ValueError, "Parameter \"" & argName & "\" value has invalid leading 0")
  result = hexStr.parse(StUint[256], 16) # TODO: Handle errors

# allows ref UInt256 to be passed as a json string
func fromJson*(n: JsonNode, argName: string, result: var ref UInt256) =
  # expects base 16 string, starting with "0x"
  n.kind.expect(JString, argName)
  let hexStr = n.getStr()
  if hexStr.len > 64 + 2: # including "0x"
    raise newException(ValueError, "Parameter \"" & argName & "\" value too long for UInt256: " & $hexStr.len)
  if hexStr.invalidQuantityPrefix:
    raise newException(ValueError, "Parameter \"" & argName & "\" value has invalid leading 0")
  new result
  result[] = hexStr.parse(StUint[256], 16) # TODO: Handle errors

func bytesFromJson(n: JsonNode, argName: string, result: var openArray[byte]) =
  n.kind.expect(JString, argName)
  let hexStr = n.getStr()
  if hexStr.len != result.len * 2 + 2: # including "0x"
    raise newException(ValueError, "Parameter \"" & argName & "\" value wrong length: " & $hexStr.len)
  hexToByteArray(hexStr, result)

func fromJson*[N](n: JsonNode, argName: string, result: var FixedBytes[N])
    {.inline.} =
  # expects base 16 string, starting with "0x"
  bytesFromJson(n, argName, array[N, byte](result))

func fromJson*(n: JsonNode, argName: string, result: var DynamicBytes)
    {.inline.} =
  n.kind.expect(JString, argName)
  result = fromHex(type result, n.getStr())

func fromJson*(n: JsonNode, argName: string, result: var Address) {.inline.} =
  # expects base 16 string, starting with "0x"
  bytesFromJson(n, argName, array[20, byte](result))

func fromJson*(n: JsonNode, argName: string, result: var TypedTransaction)
    {.inline.} =
  let hexStrLen = n.getStr().len
  if hexStrLen < 2:
    # "0x" prefix
    raise newException(ValueError, "Parameter \"" & argName & "\" value too short:" & $hexStrLen)
  if hexStrLen mod 2 != 0:
    # Spare nibble
    raise newException(ValueError, "Parameter \"" & argName & "\" value not byte-aligned:" & $hexStrLen)

  distinctBase(result).setLen((hexStrLen - 2) div 2)
  bytesFromJson(n, argName, distinctBase(result))

func fromJson*(n: JsonNode, argName: string, result: var RlpEncodedBytes)
    {.inline.} =
  let hexStrLen = n.getStr().len
  if hexStrLen < 2:
    # "0x" prefix
    raise newException(ValueError, "Parameter \"" & argName & "\" value too short:" & $hexStrLen)
  if hexStrLen mod 2 != 0:
    # Spare nibble
    raise newException(ValueError, "Parameter \"" & argName & "\" value not byte-aligned:" & $hexStrLen)

  distinctBase(result).setLen((hexStrLen - 2) div 2)
  bytesFromJson(n, argName, distinctBase(result))

func fromJson*(n: JsonNode, argName: string, result: var Quantity) {.inline.} =
  n.kind.expect(JString, argName)
  let hexStr = n.getStr
  if hexStr.invalidQuantityPrefix:
    raise newException(ValueError, "Parameter \"" & argName & "\" value has invalid leading 0")
  result = Quantity(parseHexInt(hexStr))

func getEnumStringTable(enumType: typedesc): Table[string, enumType]
    {.compileTime.} =
  var res: Table[string, enumType]
  # Not intended for enums with ordinal holes or repeated stringification
  # strings.
  for value in enumType:
    res[$value] = value
  res

func fromJson*(
    n: JsonNode, argName: string, result: var PayloadExecutionStatus)
    {.inline.} =
  n.kind.expect(JString, argName)
  const enumStrings = static: getEnumStringTable(type(result))
  try:
    result = enumStrings[n.getStr]
  except KeyError:
    raise newException(
      ValueError, "Parameter \"" & argName & "\" value invalid: " & n.getStr)

func `%`*(v: Quantity): JsonNode =
  %encodeQuantity(v.uint64)

func `%`*[N](v: FixedBytes[N]): JsonNode =
  %("0x" & array[N, byte](v).toHex)

func `%`*(v: DynamicBytes): JsonNode =
  %("0x" & toHex(v))

func `%`*(v: Address): JsonNode =
  %("0x" & array[20, byte](v).toHex)

func `%`*(v: TypedTransaction): JsonNode =
  %("0x" & distinctBase(v).toHex)

func `%`*(v: RlpEncodedBytes): JsonNode =
  %("0x" & distinctBase(v).toHex)

proc writeHexValue(w: JsonWriter, v: openArray[byte]) =
  w.stream.write "\"0x"
  w.stream.writeHex v
  w.stream.write "\""

proc writeValue*(w: var JsonWriter, v: DynamicBytes) =
  writeHexValue w, distinctBase(v)

proc writeValue*[N](w: var JsonWriter, v: FixedBytes[N]) =
  writeHexValue w, distinctBase(v)

proc writeValue*(w: var JsonWriter, v: Address) =
  writeHexValue w, distinctBase(v)

proc writeValue*(w: var JsonWriter, v: TypedTransaction) =
  writeHexValue w, distinctBase(v)

proc writeValue*(w: var JsonWriter, v: RlpEncodedBytes) =
  writeHexValue w, distinctBase(v)

proc readValue*(r: var JsonReader, T: type DynamicBytes): T =
  fromHex(T, r.readValue(string))

proc readValue*[N](r: var JsonReader, T: type FixedBytes[N]): T =
  fromHex(T, r.readValue(string))

proc readValue*(r: var JsonReader, T: type Address): T =
  fromHex(T, r.readValue(string))

proc readValue*(r: var JsonReader, T: type TypedTransaction): T =
  T fromHex(seq[byte], r.readValue(string))

proc readValue*(r: var JsonReader, T: type RlpEncodedBytes): T =
  T fromHex(seq[byte], r.readValue(string))

func `$`*(v: Quantity): string {.inline.} =
  encodeQuantity(v.uint64)

func `$`*[N](v: FixedBytes[N]): string {.inline.} =
  "0x" & array[N, byte](v).toHex

func `$`*(v: Address): string {.inline.} =
  "0x" & array[20, byte](v).toHex

func `$`*(v: TypedTransaction): string {.inline.} =
  "0x" & distinctBase(v).toHex

func `$`*(v: RlpEncodedBytes): string {.inline.} =
  "0x" & distinctBase(v).toHex

func `$`*(v: DynamicBytes): string {.inline.} =
  "0x" & toHex(v)

func `%`*(x: EthSend): JsonNode =
  result = newJObject()
  result["from"] = %x.source
  if x.to.isSome:
    result["to"] = %x.to.unsafeGet
  if x.gas.isSome:
    result["gas"] = %x.gas.unsafeGet
  if x.gasPrice.isSome:
    result["gasPrice"] = %Quantity(x.gasPrice.unsafeGet)
  if x.value.isSome:
    result["value"] = %x.value.unsafeGet
  if x.data.len > 0:
    result["data"] = %x.data
  if x.nonce.isSome:
    result["nonce"] = %x.nonce.unsafeGet

func `%`*(x: EthCall): JsonNode =
  result = newJObject()
  result["to"] = %x.to
  if x.source.isSome:
    result["source"] = %x.source.unsafeGet
  if x.gas.isSome:
    result["gas"] = %x.gas.unsafeGet
  if x.gasPrice.isSome:
    result["gasPrice"] = %x.gasPrice.unsafeGet
  if x.value.isSome:
    result["value"] = %x.value.unsafeGet
  if x.data.isSome:
    result["data"] = %x.data.unsafeGet

func `%`*(x: byte): JsonNode =
  %x.int

func `%`*(x: FilterOptions): JsonNode =
  result = newJObject()
  if x.fromBlock.isSome:
    result["fromBlock"] = %x.fromBlock.unsafeGet
  if x.toBlock.isSome:
    result["toBlock"] = %x.toBlock.unsafeGet
  if x.address.isSome:
    result["address"] = %x.address.unsafeGet
  if x.topics.isSome:
    result["topics"] = %x.topics.unsafeGet

func `%`*(x: RtBlockIdentifier): JsonNode =
  case x.kind
  of bidNumber: %(&"0x{x.number:X}")
  of bidAlias: %x.alias
