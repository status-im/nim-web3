
from ./primitives import DynamicBytes

{.push raises: [].}

const abiSlotSize* = 32

func isDynamicObject*(T: typedesc): bool

func isDynamic*(T: type): bool =
  when T is seq | openArray | string | DynamicBytes:
    return true
  elif T is array:
    type t = typeof(default(T)[0])
    return isDynamic(t)
  elif T is object:
    return isDynamicObject(T)
  else:
    return false

func isDynamicType(a: typedesc): bool =
  when a is seq | openArray | string | DynamicBytes:
    true
  elif a is object:
    return isDynamicObject(a)
  else:
    false

func isDynamicObject(T: typedesc): bool {.compileTime.} =
  for v in fields(default(T)):
    if isDynamicType(typeof(v)):
      return true
  return false

func isStatic*(T: type): bool {.compileTime.} =
  not isDynamic(T)