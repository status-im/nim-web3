import
  std/unittest,
  serialization,
  ../web3/[abi_utils, primitives]

type Struct[T] = object
  field: T

type SkippedStruct = object
  field: uint8
  skipped {.dontSerialize.}: seq[byte]

type DistinctBytes = distinct seq[byte]

type DistinctTuple = distinct (uint8, seq[byte])

suite "ABI utils":
  test "can determine whether types are dynamic or static":
    check static isStatic(uint8)
    check static isDynamic(seq[byte])
    check static isStatic(array[2, array[2, byte]])
    check static isDynamic(array[2, seq[byte]])
    check static isStatic((uint8, bool))
    check static isDynamic((uint8, seq[byte]))
    check static isStatic((uint8, (bool, uint8)))
    check static isDynamic((uint8, (bool, seq[byte])))

  test "can determine encoded sizes":
    check static staticSize(uint8) == abiSlotSize
    check static staticSize(array[33, byte]) == 2 * abiSlotSize
    check static staticSize(FixedBytes[33]) == 2 * abiSlotSize
    check static staticSize(array[2, array[2, uint16]]) == 4 * abiSlotSize
    check static staticSize((uint8, array[2, uint16])) == 3 * abiSlotSize
    check static staticSize(Struct[(uint8, bool)]) == 2 * abiSlotSize
    check static staticSize(SkippedStruct) == abiSlotSize
    check static headSize((uint8, array[2, uint16])) == 3 * abiSlotSize
    check static headSize(array[2, seq[byte]]) == abiSlotSize
    check static headSize(DistinctBytes) == abiSlotSize
