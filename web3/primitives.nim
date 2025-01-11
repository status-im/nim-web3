# nim-web3
# Copyright (c) 2023-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

{.push raises: [].}






import
  std/[hashes as std_hashes, typetraits],
  stint,
  stew/byteutils,
  eth/common/[addresses, base, hashes],
  results

export base except BlockNumber

export
  addresses,
  std_hashes,
  hashes,
  typetraits,
  results

const
  # https://github.com/ethereum/execution-apis/blob/c4089414bbbe975bbc4bf1ccf0a3d31f76feb3e1/src/engine/cancun.md#blobsbundlev1
  fieldElementsPerBlob = 4096

type
  # https://github.com/ethereum/execution-apis/blob/c4089414bbbe975bbc4bf1ccf0a3d31f76feb3e1/src/schemas/base-types.yaml

  DynamicBytes*[
    minLen: static[int] = 0,
    maxLen: static[int] = high(int)] = distinct seq[byte]

  Quantity* = distinct uint64
    # Quantity is use in lieu of an ordinary `uint64` to avoid the default
    # format that comes with json_serialization

  Blob* = FixedBytes[fieldElementsPerBlob * 32]

template `==`*[minLen, maxLen](a, b: DynamicBytes[minLen, maxLen]): bool =
  distinctBase(a) == distinctBase(b)

template ethQuantity(typ: type) {.dirty.} =
  func `+`*(a: typ, b: distinctBase(typ)): typ {.borrow.}
  func `-`*(a: typ, b: distinctBase(typ)): typ {.borrow.}

  func `<`*(a, b: typ): bool {.borrow.}
  func `<=`*(a, b: typ): bool {.borrow.}
  func `==`*(a, b: typ): bool {.borrow.}

ethQuantity Quantity

template toHex*(x: DynamicBytes): string =
  toHex(distinctBase x)

template to0xHex*[minLen, maxLen](x: DynamicBytes[minLen, maxLen]): string =
  to0xHex(distinctBase x)

template skip0xPrefix(hexStr: string): int =
  ## Returns the index of the first meaningful char in `hexStr` by skipping
  ## "0x" prefix
  if hexStr.len > 1 and hexStr[0] == '0' and hexStr[1] in {'x', 'X'}: 2
  else: 0

func fromHex*[minLen, maxLen](T: type DynamicBytes[minLen, maxLen], hexStr: string): T {.raises: [ValueError].} =
  let prefixLen = skip0xPrefix(hexStr)
  let hexDataLen = hexStr.len - prefixLen

  if hexDataLen < minLen * 2:
    raise newException(ValueError, "hex input too small")

  if hexDataLen > maxLen * 2:
    raise newException(ValueError, "hex input too large")

  T hexToSeqByte(hexStr)

func toArray*[N](data: DynamicBytes[N, N]): array[N, byte] =
  copyMem(addr result[0], unsafeAddr distinctBase(data)[0], N)

template data*(v: DynamicBytes): seq[byte] =
  distinctBase v

template bytes*(v: DynamicBytes): seq[byte] {.deprecated: "data".} =
  v.data

template bytes*(v: FixedBytes): auto {.deprecated: "data".} =
  v.data

template bytes*(v: Address): auto {.deprecated: "data".} =
  v.data

template bytes*(v: Hash32): auto {.deprecated: "data".} =
  v.data

template len*(data: DynamicBytes): int =
  len(distinctBase data)

template len*(data: FixedBytes): int =
  len(distinctBase data)

template len*(data: Address): int =
  len(distinctBase data)

template len*(data: Hash32): int =
  len(distinctBase data)

func `$`*[minLen, maxLen](data: DynamicBytes[minLen, maxLen]): string =
  data.to0xHex()

# Backwards compatibility

type
  Hash256* {.deprecated.} = Hash32
  BlockNumber* {.deprecated.} = Quantity
  BlockHash* {.deprecated.} = Hash32
  CodeHash* {.deprecated.} = Hash32
  StorageHash* {.deprecated.} = Hash32
  TxHash* {.deprecated.} = Hash32
