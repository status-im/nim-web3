
from std/typetraits import distinctBase
from serialization/object_serialization import enumInstanceSerializedFields
from stint import StInt, StUint
from ./primitives import DynamicBytes

{.push raises: [].}

const abiSlotSize* = 32

type
  AbiSignedInt* = int8|int16|int32|int64
  AbiUnsignedInt* = uint8|uint16|uint32|uint64

func isDynamicObject*(T: typedesc): bool

func isDynamic*(T: type): bool =
  when T is seq | openArray | string | DynamicBytes:
    return true
  elif T is array:
    when typeof(default(T)[0]) is byte:
      return T.len > abiSlotSize
    else:
      type t = typeof(default(T)[0])
      return isDynamic(t)
  elif T is tuple:
    for v in fields(default(T)):
      if isDynamic(typeof(v)):
        return true
    return false
  elif T is object:
    return isDynamicObject(T)
  else:
    return false

func isDynamicType*(a: typedesc): bool =
  when a is seq | openArray | string | DynamicBytes:
    true
  elif a is object:
    return isDynamicObject(a)
  else:
    false

func isDynamicObject*(T: typedesc): bool {.compileTime.} =
  for v in fields(default(T)):
    if isDynamicType(typeof(v)):
      return true
  return false

func isStatic*(T: type): bool {.compileTime.} =
  not isDynamic(T)

func staticSize*(T: type): int {.compileTime.} =
  when T is array:
    when typeof(default(T)[0]) is byte:
      return (T.len + abiSlotSize - 1) div abiSlotSize * abiSlotSize
    else:
      type t = typeof(default(T)[0])
      return T.len * staticSize(t)
  elif T is tuple:
    var size = 0
    for v in fields(default(T)):
      size += staticSize(typeof(v))
    return size
  elif T is object and T isnot StInt | StUint:
    var size = 0
    default(T).enumInstanceSerializedFields(_, v):
      size += staticSize(typeof(v))
    return size
  elif T is distinct:
    return staticSize(distinctBase(T))
  else:
    return abiSlotSize

func headSize*(T: type): int {.compileTime.} =
  when isDynamic(T):
    return abiSlotSize
  else:
    return staticSize(T)
