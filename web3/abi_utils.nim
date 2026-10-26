
from std/typetraits import distinctBase
from stew/objects import declval
from serialization/object_serialization import enumInstanceSerializedFields
from stint import StInt, StUint
from ./primitives import FixedBytes

{.push raises: [].}

const abiSlotSize* = 32

type
  AbiSignedInt* = int8|int16|int32|int64
  AbiUnsignedInt* = uint8|uint16|uint32|uint64

func isDynamicObject*(T: typedesc): bool {.compileTime.}

func isDynamic*(T: type): bool =
  # https://docs.soliditylang.org/en/latest/abi-spec.html#formal-specification-of-the-encoding
  when T is FixedBytes:
    when T.N notin 1 .. abiSlotSize:
      # https://docs.soliditylang.org/en/latest/abi-spec.html#types
      {.error: "bytes<M> has to fit into a single slot".}
    false
  elif T is seq | openArray | string:
    true
  elif T is array:
    type E = type(declval(T)[low(T)])
    E.isDynamic
  elif T is tuple:
    for v in fields(default(T)):
      if typeof(v).isDynamic:
        return true
    false
  elif T is StInt | StUint:
    when T.bits > 256:
      # https://docs.soliditylang.org/en/latest/abi-spec.html#types
      {.error: "uint<M> and int<M> have to fit into a single slot".}
    false
  elif T is object:
    T.isDynamicObject
  elif T is distinct:
    distinctBase(T, recursive = false).isDynamic
  else:
    false

func isDynamicObject*(T: typedesc): bool {.compileTime.} =
  default(T).enumInstanceSerializedFields(_, v):
    if typeof(v).isDynamic:
      return true
  false

func isStatic*(T: type): bool =
  not isDynamic(T)

func staticSize*(T: type): int {.compileTime.} =
  when T is FixedBytes:
    when T.N notin 1 .. abiSlotSize:
      # https://docs.soliditylang.org/en/latest/abi-spec.html#types
      {.error: "bytes<M> has to fit into a single slot".}
    abiSlotSize
  elif T is array:
    type E = type(declval(T)[low(T)])
    T.len * E.staticSize
  elif T is tuple:
    var size = 0
    for v in default(T).fields():
      size += typeof(v).staticSize
    size
  elif T is StInt | StUint:
    when T.bits > 256:
      # https://docs.soliditylang.org/en/latest/abi-spec.html#types
      {.error: "uint<M> and int<M> have to fit into a single slot".}
    abiSlotSize
  elif T is object:
    var size = 0
    default(T).enumInstanceSerializedFields(_, v):
      size += typeof(v).staticSize
    size
  elif T is distinct:
    distinctBase(T, recursive = false).staticSize
  else:
    abiSlotSize

func headSize*(T: type): int {.compileTime.} =
  when isDynamic(T):
    abiSlotSize
  else:
    staticSize(T)
