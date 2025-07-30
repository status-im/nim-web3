
import serialization
import faststreams
import ./encoding
import ./decoding

serializationFormat Abi,
                   mimeType = "application/ethereum‑abi"

type
  AbiReader* = ref object
    stream: InputStream

  AbiWriter* = ref object
    stream: OutputStream

proc new*(T: type AbiReader, stream: InputStream): T =
  T(stream: stream)

proc new*(T: type AbiWriter): T =
  T(stream: memoryOutput())

proc init*(T: type AbiWriter, s: OutputStream): T =
  T(stream: s)

proc init*(T: type AbiReader, s: InputStream): AbiReader =
  AbiReader(stream: s)

proc readValue*[T](r: var AbiReader, _: typedesc[T]): T =
  result = AbiDecoder.decode(r.stream, T)

proc writeValue*[T](w: var AbiWriter, value: T) =
  w.stream.write AbiEncoder.encode(value)

Abi.setReader AbiReader
Abi.setWriter AbiWriter, PreferredOutput = seq[byte]