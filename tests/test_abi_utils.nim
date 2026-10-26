import
  unittest2,
  serialization,
  ../web3/[abi_utils, primitives]

type Struct[T] = object
  field: T

type SkippedStruct = object
  field: uint8
  skipped {.dontSerialize.}: DynBytes

type DistinctBytes = distinct DynBytes

type DistinctTuple = distinct (uint8, DynBytes)

suite "ABI utils":
  staticTest "can determine whether types are dynamic or static":
    check:
      isStatic(uint8)
      isDynamic(seq[uint8])
      isDynamic(DynBytes)
      isStatic(array[2, array[2, uint8]])
      isStatic(array[2, FixedBytes[2]])
      isDynamic(array[2, seq[uint8]])
      isDynamic(array[2, DynBytes])
      isStatic((uint8, bool))
      isDynamic((uint8, DynBytes))
      isStatic((uint8, (bool, uint8)))
      isDynamic((uint8, (bool, DynBytes)))
      not compiles(isStatic(FixedBytes[0]))
      not compiles(isStatic(FixedBytes[33]))
      not compiles(isDynamic(FixedBytes[0]))
      not compiles(isDynamic(FixedBytes[33]))

  staticTest "can determine encoded sizes":
    check:
      staticSize(uint8) == abiSlotSize
      staticSize(array[33, uint8]) == 33 * abiSlotSize
      staticSize(FixedBytes[32]) == abiSlotSize
      staticSize(Address) == abiSlotSize
      staticSize(Hash32) == abiSlotSize
      staticSize(array[2, array[2, uint16]]) == 4 * abiSlotSize
      staticSize((uint8, array[2, uint16])) == 3 * abiSlotSize
      staticSize(Struct[(uint8, bool)]) == 2 * abiSlotSize
      staticSize(SkippedStruct) == abiSlotSize
      headSize((uint8, array[2, uint16])) == 3 * abiSlotSize
      headSize(array[2, DynBytes]) == abiSlotSize
      headSize(DistinctBytes) == abiSlotSize
