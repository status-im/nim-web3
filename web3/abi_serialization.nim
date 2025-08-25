
import serialization
import faststreams

{.push raises: [].}

serializationFormat Abi,
                   mimeType = "application/ethereum‑abi"

type
  AbiReader* = object
    stream: InputStream

  AbiWriter* = object
    stream: OutputStream

proc new*(T: type AbiReader, stream: InputStream): T =
  T(stream: stream)

proc new*(T: type AbiWriter): T =
  T(stream: memoryOutput())

proc init*(T: type AbiWriter, s: OutputStream): T =
  T(stream: s)

proc init*(T: type AbiReader, s: InputStream): AbiReader =
  AbiReader(stream: s)

proc getStream*(r: AbiWriter): OutputStream =
  r.stream

proc getStream*(r: AbiReader): InputStream =
  r.stream

proc write*(w: AbiWriter, bytes: seq[byte]) {.raises: [IOError]} =
  w.stream.write bytes

Abi.setReader AbiReader
Abi.setWriter AbiWriter, PreferredOutput = seq[byte]