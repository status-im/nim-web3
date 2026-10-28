
import serialization
import faststreams

{.push raises: [].}

serializationFormat Abi,
                   mimeType = "application/ethereum‑abi"

const DefaultMaxMemoryFactor* = 4'u

type
  AbiReader* = object
    stream: InputStream
    maxMemoryFactor: uint64

  AbiWriter* = object
    stream: OutputStream

proc new*(
    T: type AbiReader, stream: InputStream,
    maxMemoryFactor = DefaultMaxMemoryFactor): T =
  T(stream: stream, maxMemoryFactor: maxMemoryFactor.uint64)

proc new*(T: type AbiWriter): T =
  T(stream: memoryOutput())

proc init*(T: type AbiWriter, s: OutputStream): T =
  T(stream: s)

proc init*(
    T: type AbiReader, s: InputStream,
    maxMemoryFactor = DefaultMaxMemoryFactor): AbiReader =
  ## Decoding fails once it would use more than `maxMemoryFactor` times
  ## the input size, e.g., through many offsets pointing at the same data.
  ## 0 disables the limit.
  AbiReader(stream: s, maxMemoryFactor: maxMemoryFactor.uint64)

proc getStream*(r: AbiWriter): OutputStream =
  r.stream

proc getStream*(r: AbiReader): InputStream =
  r.stream

func maxMemoryFactor*(r: AbiReader): uint64 =
  r.maxMemoryFactor

proc write*(w: AbiWriter, bytes: seq[byte]) {.raises: [IOError]} =
  w.stream.write bytes

Abi.setReader AbiReader
Abi.setWriter AbiWriter, PreferredOutput = seq[byte]
