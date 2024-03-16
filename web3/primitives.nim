# nim-web3
# Copyright (c) 2023-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[options, hashes, typetraits],
  stint, stew/[byteutils, results]

export
  hashes, options, typetraits

type
  FixedBytes*[N: static[int]] = distinct array[N, byte]

  DynamicBytes*[
    minLen: static[int] = 0,
    maxLen: static[int] = high(int)] = distinct seq[byte]

  Address* = distinct array[20, byte]
  TxHash* = FixedBytes[32]
  Hash256* = FixedBytes[32]
  BlockHash* = FixedBytes[32]
  Quantity* = distinct uint64
  BlockNumber* = distinct Quantity

  CodeHash* = FixedBytes[32]
  StorageHash* = FixedBytes[32]
  VersionedHash* = FixedBytes[32]

{.push raises: [].}

template `==`*[N](a, b: FixedBytes[N]): bool =
  distinctBase(a) == distinctBase(b)

template `==`*(a, b: Quantity): bool =
  distinctBase(a) == distinctBase(b)

template `==`*(a, b: BlockNumber): bool =
  distinctBase(a) == distinctBase(b)

template `==`*[minLen, maxLen](a, b: DynamicBytes[minLen, maxLen]): bool =
  distinctBase(a) == distinctBase(b)

func `==`*(a, b: Address): bool {.inline.} =
  distinctBase(a) == distinctBase(b)

func hash*[N](bytes: FixedBytes[N]): Hash =
  hash(distinctBase bytes)

func hash*(bytes: Address): Hash =
  hash(distinctBase bytes)

template toHex*[N](x: FixedBytes[N]): string =
  toHex(distinctBase x)

template toHex*[minLen, maxLen](x: DynamicBytes[minLen, maxLen]): string =
  toHex(distinctBase x)

template toHex*(x: Address): string =
  toHex(distinctBase x)

template fromHex*(T: type Address, hexStr: string): T =
  T fromHex(distinctBase(T), hexStr)

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

template fromHex*[N](T: type FixedBytes[N], hexStr: string): T =
  T fromHex(distinctBase(T), hexStr)

func toArray*[N](data: DynamicBytes[N, N]): array[N, byte] =
  copyMem(addr result[0], unsafeAddr distinctBase(data)[0], N)

template bytes*(data: DynamicBytes): seq[byte] =
  distinctBase data

template bytes*(data: FixedBytes): auto =
  distinctBase data

template bytes*(data: Address): auto =
  distinctBase data

template len*(data: DynamicBytes): int =
  len(distinctBase data)

template len*(data: FixedBytes): int =
  len(distinctBase data)

template len*(data: Address): int =
  len(distinctBase data)

func `$`*[minLen, maxLen](data: DynamicBytes[minLen, maxLen]): string =
  "0x" & byteutils.toHex(distinctBase(data))

func `$`*[N](data: FixedBytes[N]): string =
  "0x" & byteutils.toHex(distinctBase(data))

func `$`*(data: Address): string =
  "0x" & byteutils.toHex(distinctBase(data))
