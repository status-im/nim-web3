import
  std/[typetraits, json],
  stint,
  unittest2,
  nimcrypto,
  stew/endians2,
  json_serialization,
  ../web3/engine_api_types,
  ../web3/execution_types,
  ../web3/[conversions, eth_api_types]

proc rand[N: static int](_: type FixedBytes[N]): FixedBytes[N] =
  discard randomBytes(distinctBase result)

proc rand(_: type Hash32): Hash32 =
  discard randomBytes(distinctBase result)

proc rand[M,N](_: type DynamicBytes[M,N]): DynamicBytes[M,N] =
  discard randomBytes(distinctBase result)

proc rand(_: type Address): Address =
  discard randomBytes(distinctBase result)

proc rand(_: type uint64): uint64 =
  var res: array[8, byte]
  discard randomBytes(res)
  uint64.fromBytesBE(res)

proc rand[T: Quantity](_: type T): T =
  var res: array[sizeof(T), byte]
  discard randomBytes(res)
  T(distinctBase(T).fromBytesBE(res))

proc rand[T: Number](_: type T): T =
  var res: array[sizeof(T), byte]
  discard randomBytes(res)
  T(distinctBase(T).fromBytesBE(res))

proc rand[T: ChainId](_: type T): T =
  var res: array[8, byte]
  discard randomBytes(res)
  T(uint64.fromBytesBE(res))

proc rand(_: type RlpEncodedBytes): RlpEncodedBytes =
  discard randomBytes(distinctBase result)

proc rand(_: type TypedTransaction): TypedTransaction =
  discard randomBytes(distinctBase result)

func rand(_: type string): string =
  "random bytes"

proc rand(_: type bool): bool =
  var x: array[1, byte]
  discard randomBytes(x)
  x[0].int mod 2 == 0

proc rand(_: type byte): byte =
  var x: array[1, byte]
  discard randomBytes(x)
  x[0]

proc rand(_: type UInt256): UInt256 =
  var x: array[32, byte]
  discard randomBytes(x)
  UInt256.fromBytesBE(x)

proc rand(_: type RtBlockIdentifier): RtBlockIdentifier =
  RtBlockIdentifier(kind: bidNumber, number: rand(Quantity))

proc rand(_: type PayloadExecutionStatus): PayloadExecutionStatus =
  var x: array[1, byte]
  discard randomBytes(x)
  if x[0].int <= high(PayloadExecutionStatus).int and
     x[0].int >= low(PayloadExecutionStatus).int:
     result = PayloadExecutionStatus(x[0].int)

proc rand(_: type TxOrHash): TxOrHash =
  TxOrHash(kind: tohHash, hash: rand(Hash32))

proc rand[X: object](T: type X): T

proc rand[T](_: type seq[T]): seq[T] =
  result = newSeq[T](3)
  for i in 0..<3:
    result[i] = rand(T)

proc rand[T](_: type openArray[T]): array[CELLS_PER_EXT_BLOB, T] =
  var a: array[CELLS_PER_EXT_BLOB, T]
  for i in 0..<a.len:
    a[i] = rand(T)
  a

proc rand(_: type seq[seq[byte]]): seq[seq[byte]] =
  var z = newSeq[byte](10)
  discard randomBytes(z)
  @[z, z, z]

proc rand[T](_: type SingleOrList[T]): SingleOrList[T] =
  SingleOrList[T](kind: slkSingle, single: rand(T))

proc rand[X](T: type Opt[X]): T =
  var x: array[1, byte]
  discard randomBytes(x)
  if x[0] > 127:
    Opt.some(rand(X))
  else:
    Opt.none(X)

proc rand[X: object](T: type X): T =
  result = T()
  for field in fields(result):
    field = rand(typeof(field))

proc rand[X: ref](T: type X): T =
  result = T()
  for field in fields(result[]):
    field = rand(typeof(field))

template checkRandomObject(T: type) =
  let obj = rand(T)
  let bytes = EthJson.encode(obj)
  let decoded = EthJson.decode(bytes, T)
  let bytes2 = EthJson.encode(decoded)
  check bytes == bytes2

suite "JSON-RPC Quantity":
  test "Random object encoding":
    checkRandomObject(SyncObject)
    checkRandomObject(Withdrawal)
    checkRandomObject(AccessPair)
    checkRandomObject(AccessListResult)
    checkRandomObject(LogObject)
    checkRandomObject(StorageProof)
    checkRandomObject(ProofResponse)
    checkRandomObject(FilterOptions)
    checkRandomObject(TransactionArgs)
    checkRandomObject(Authorization)

    checkRandomObject(BlockHeader)
    checkRandomObject(BlockObject)
    checkRandomObject(TransactionObject)
    checkRandomObject(ReceiptObject)

    checkRandomObject(WithdrawalV1)
    checkRandomObject(ExecutionPayloadV1)
    checkRandomObject(ExecutionPayloadV2)
    checkRandomObject(ExecutionPayloadV1OrV2)
    checkRandomObject(ExecutionPayloadV3)
    checkRandomObject(ExecutionPayloadV4)
    checkRandomObject(BlobsBundleV1)
    checkRandomObject(BlobsBundleV2)
    checkRandomObject(BlobAndProofV1)
    checkRandomObject(BlobAndProofV2)
    checkRandomObject(ExecutionPayloadBodyV1)
    checkRandomObject(ExecutionPayloadBodyV2)
    checkRandomObject(PayloadAttributesV1)
    checkRandomObject(PayloadAttributesV2)
    checkRandomObject(PayloadAttributesV3)
    checkRandomObject(PayloadAttributesV4)
    checkRandomObject(PayloadAttributesV1OrV2)
    checkRandomObject(PayloadStatusV1)
