import
  json, options, stint, strutils, strformat, typetraits,
  stew/byteutils, json_serialization, faststreams/textio,
  ethtypes, ethhexstrings

from json_rpc/rpcserver import expect

proc `%`*(n: Int256|UInt256): JsonNode = %("0x" & n.toHex)

# allows UInt256 to be passed as a json string
proc fromJson*(n: JsonNode, argName: string, result: var UInt256) =
  # expects base 16 string, starting with "0x"
  n.kind.expect(JString, argName)
  let hexStr = n.getStr()
  if hexStr.len > 64 + 2: # including "0x"
    raise newException(ValueError, "Parameter \"" & argName & "\" value too long for UInt256: " & $hexStr.len)
  result = hexStr.parse(StUint[256], 16) # TODO: Handle errors

# allows ref UInt256 to be passed as a json string
proc fromJson*(n: JsonNode, argName: string, result: var ref UInt256) =
  # expects base 16 string, starting with "0x"
  n.kind.expect(JString, argName)
  let hexStr = n.getStr()
  if hexStr.len > 64 + 2: # including "0x"
    raise newException(ValueError, "Parameter \"" & argName & "\" value too long for UInt256: " & $hexStr.len)
  new result
  result[] = hexStr.parse(StUint[256], 16) # TODO: Handle errors

proc bytesFromJson(n: JsonNode, argName: string, result: var openarray[byte]) =
  n.kind.expect(JString, argName)
  let hexStr = n.getStr()
  if hexStr.len != result.len * 2 + 2: # including "0x"
    raise newException(ValueError, "Parameter \"" & argName & "\" value wrong length: " & $hexStr.len)
  hexToByteArray(hexStr, result)

proc fromJson*[N](n: JsonNode, argName: string, result: var FixedBytes[N]) {.inline.} =
  # expects base 16 string, starting with "0x"
  bytesFromJson(n, argName, array[N, byte](result))

proc fromJson*(n: JsonNode, argName: string, result: var Address) {.inline.} =
  # expects base 16 string, starting with "0x"
  bytesFromJson(n, argName, array[20, byte](result))

proc fromJson*(n: JsonNode, argName: string, result: var Quantity) {.inline.} =
  if n.kind == JInt:
    result = Quantity(n.getBiggestInt)
  else:
    n.kind.expect(JString, argName)
    result = Quantity(parseHexInt(n.getStr))

proc `%`*(v: Quantity): JsonNode =
  result = %encodeQuantity(v.uint64)

proc `%`*[N](v: FixedBytes[N]): JsonNode =
  result = %("0x" & array[N, byte](v).toHex)

proc `%`*(v: Address): JsonNode =
  result = %("0x" & array[20, byte](v).toHex)

proc writeHexValue(w: JsonWriter, v: openarray[byte]) =
  w.stream.write "\"0x"
  w.stream.writeHex v
  w.stream.write "\""

proc writeValue*[N](w: var JsonWriter, v: DynamicBytes[N]) =
  writeHexValue w, distinctBase(v)

proc writeValue*[N](w: var JsonWriter, v: FixedBytes[N]) =
  writeHexValue w, distinctBase(v)

proc writeValue*(w: var JsonWriter, v: Address) =
  writeHexValue w, distinctBase(v)

proc readValue*[N](r: var JsonReader, T: type DynamicBytes[N]): T =
  fromHex(T, r.readValue(string))

proc readValue*[N](r: var JsonReader, T: type FixedBytes[N]): T =
  fromHex(T, r.readValue(string))

proc readValue*(r: var JsonReader, T: type Address): T =
  fromHex(T, r.readValue(string))

proc `%`*[N](v: DynamicBytes[N]): JsonNode =
  result = %("0x" & array[N, byte](v).toHex)
  assert(result.getStr.len == N * 2 + 2)

proc `$`*[N](v: FixedBytes[N]): string {.inline.} =
  "0x" & array[N, byte](v).toHex

proc `$`*(v: Address): string {.inline.} =
  "0x" & array[20, byte](v).toHex

proc `$`*[N](v: DynamicBytes[N]): string {.inline.} =
  "0x" & array[N, byte](v).toHex

proc `%`*(x: EthSend): JsonNode =
  result = newJobject()
  result["from"] = %x.source
  if x.to.isSome:
    result["to"] = %x.to.unsafeGet
  if x.gas.isSome:
    result["gas"] = %x.gas.unsafeGet
  if x.gasPrice.isSome:
    result["gasPrice"] = %x.gasPrice.unsafeGet
  if x.value.isSome:
    result["value"] = %x.value.unsafeGet
  result["data"] = %x.data
  if x.nonce.isSome:
    result["nonce"] = %x.nonce.unsafeGet

proc `%`*(x: EthCall): JsonNode =
  result = newJobject()
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

proc `%`*(x: byte): JsonNode =
  %x.int

proc `%`*(x: FilterOptions): JsonNode =
  result = newJobject()
  if x.fromBlock.isSome:
    result["fromBlock"] = %x.fromBlock.unsafeGet
  if x.toBlock.isSome:
    result["toBlock"] = %x.toBlock.unsafeGet
  if x.address.isSome:
    result["address"] = %x.address.unsafeGet
  if x.topics.isSome:
    result["topics"] = %x.topics.unsafeGet

proc `%`*(x: RtBlockIdentifier): JsonNode =
  case x.kind
  of bidNumber: %(&"0x{x.number:X}")
  of bidAlias: %x.alias

