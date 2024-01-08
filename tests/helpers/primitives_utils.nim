import
  stint,
  ../../web3/primitives

func ethToWei*(eth: UInt256): UInt256 =
  eth * 1000000000000000000.u256

type
  BlobData* = DynamicBytes[0, 512]

func conv*(T: type, x: int): T =
  type BaseType = distinctBase T
  var res: BaseType
  when BaseType is seq:
    res.setLen(1)
  res[^1] = x.byte
  T(res)

func address*(x: int): Address =
  conv(typeof result, x)

func txhash*(x: int): TxHash =
  conv(typeof result, x)

func blob*(x: int): BlobData =
  conv(typeof result, x)

func h256*(x: int): Hash256 =
  conv(typeof result, x)
