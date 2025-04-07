# nim-web3
# Copyright (c) 2018-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[typetraits, json],
  stint,
  unittest2,
  nimcrypto,
  stew/endians2,
  json_rpc/jsonmarshal, json_serialization,
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
  var res: array[8, byte]
  discard randomBytes(res)
  T(uint64.fromBytesBE(res))

proc rand[T: ChainId](_: type T): T =
  var res: array[8, byte]
  discard randomBytes(res)
  T(uint64.fromBytesBE(res))

proc rand(_: type RlpEncodedBytes): RlpEncodedBytes =
  discard randomBytes(distinctBase result)

proc rand(_: type TypedTransaction): TypedTransaction =
  discard randomBytes(distinctBase result)

proc rand(_: type string): string =
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
  let bytes = JrpcConv.encode(obj)
  let decoded = JrpcConv.decode(bytes, T)
  let bytes2 = JrpcConv.encode(decoded)
  check bytes == bytes2

suite "JSON-RPC Quantity":
  test "Valid":
    template checkType(typeName: typedesc): untyped =
      for (validStr, validValue) in [
          ("0x0", typeName 0),
          ("0x123", typeName 291),
          ("0x1234", typeName 4660)]:
        let
          validJson = JrpcConv.encode(validStr)
          res = JrpcConv.decode(validJson, typeName)
          resUInt256 = JrpcConv.decode(validJson, UInt256)
          resUInt256Ref = JrpcConv.decode(validJson, ref UInt256)

        check:
          JrpcConv.decode(validJson, typeName) == validValue
          JrpcConv.encode(validValue) == validJson
          res == validValue
          resUInt256 == validValue.distinctBase.u256
          resUInt256Ref[] == validValue.distinctBase.u256

    checkType(Quantity)
    checkType(Quantity)

  test "Invalid Quantity/Quantity/UInt256/ref UInt256":
    # TODO once https://github.com/status-im/nimbus-eth2/pull/3850 addressed,
    # re-add "0x0400" test case as invalid.
    for invalidStr in [
        "", "1234", "01234", "x1234", "0x", "ff"]:
      template checkInvalids(typeName: untyped) =
        var res: `typeName`
        try:
          let jsonBytes = JrpcConv.encode(invalidStr)
          res = JrpcConv.decode(jsonBytes, `typeName`)
          echo `typeName`, " ", invalidStr
          check: false
        except SerializationError:
          check: true
        except CatchableError:
          check: false

      checkInvalids(Quantity)
      checkInvalids(Quantity)
      checkInvalids(UInt256)
      checkInvalids(ref UInt256)

  test "Block decoding":
    const blockJson = """
     {"difficulty":"0x1","extraData":"0x696e667572612d696f00000000000000000000000000000000000000000000004ede22d16eaf5bbab47534ee64a1ec1728ed63b1243672ee9623532fffd747b368cddb4674f849e467884f0e6c6563440ea5fd812cc33fcd19fb9c323b0c92c300","gasLimit":"0x7a1200","gasUsed":"0x3aca3e","hash":"0x5ac670562dbf877a45039d65ec3c2e3402a40eda9b1dba931c2376ab7d0927c2","logsBloom":"0x40000000004000120000000100030000882000040000001800010000020000000000000000001400080040004080400402024800000004000088f0320000a0000016000100110060800000080000020000000020000000000050000009010000080000040220280000080240048008000001381a1100000000000010000440000000004200000018001102280400003040040020001a000026000488000101000120000a0002000081220000100000000200000000040440a02400010000000002000002400100840000080000000080000008c0c080000008000000220860082002000000001000000041040002000000008000010004000400010400040001","miner":"0x0000000000000000000000000000000000000000","mixHash":"0x0000000000000000000000000000000000000000000000000000000000000000","nonce":"0x0000000000000000","number":"0x42a3da","parentHash":"0xe0190ed0683835483c35e0c0a98bf0958ed2ca7313428c9026db51604007e299","receiptsRoot":"0x12fff235455db65dcdc525d2491b9e0526e02d70a1515fba155b1de9f648abf3","sha3Uncles":"0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347","size":"0x2a5d","stateRoot":"0xccb37180b5fca41e43395d524a0ee83a1efc69f2fb61f90a51f3dc8f40f2144e","timestamp":"0x603cab8c","totalDifficulty":"0x624910","transactions":["0xa3c07dc59bfdb1bfc2d50920fed2ef2c1c4e0a09fe2325dbc14e07702f965a78","0x7b33b36e905c8e83a519216444aff4952bfbce5c49247ecc70f227a56068247e","0x11fa3f25957caa1918ecb1f2c1eaeef46c1af983e1b7eee65cefe2a752f7e9da","0x7028ef43993c84e751bbcb126cbaa52d7b732efe4daf95e6e0fbff06e43f0277","0xe287b4939a51aff8a78b836c56db18ca1559ba77303b1e0cee9075ff737f4a57","0xb79cb96a3ff5bb9aca4ce2024a57023cfda163d6135f3ff6a0d9f0b9fac44efb","0xad0d4bfb6b4276616c7d88fe2576903d6c17f6bee1d10db15de203a88bda2898","0x73127fadab4c4ceed35be81e3e97549d2005bfdbc49083ce81f135662edd6869","0xff522f3e2a2d451acf2df2341d8ed9e982dbf7160b327f34b8b5ca25b377a74f","0x2d100b5abba751743920cf56614195c0e3685d93bfdbe5325c35a933f5195e2c","0x9611c7cac2e14fed4051d34f74eed1bace9da8e79446d4e03f479c318de24087","0x43f29106dac821e5069b3c0b27a61d01116a8e69096388d57b70a9e5354e0457","0xb71fe345141491f54cb53e4af44d581cbd631c0b7bd12019077c1dc354b1c5ab"],"transactionsRoot":"0x08fd011674202c6df63822f877e88d7ca0fe41e5deb8bc2b8830f1a29ce864f0","uncles":[]}
    """
    let
      b1 = JrpcConv.decode(blockJson, BlockObject)
      jsonBytes = JrpcConv.encode(b1)
      b2 = JrpcConv.decode(jsonBytes, BlockObject)
      b1Bytes = JrpcConv.encode(b1)
      b2Bytes = JrpcConv.encode(b2)

    check b1Bytes == b2Bytes

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
    checkRandomObject(BlobsBundleV1)
    checkRandomObject(BlobsBundleV2)
    checkRandomObject(BlobAndProofV1)
    checkRandomObject(BlobAndProofV2)
    checkRandomObject(ExecutionPayloadBodyV1)
    checkRandomObject(PayloadAttributesV1)
    checkRandomObject(PayloadAttributesV2)
    checkRandomObject(PayloadAttributesV3)
    checkRandomObject(PayloadAttributesV1OrV2)
    checkRandomObject(PayloadStatusV1)
    checkRandomObject(ForkchoiceStateV1)
    checkRandomObject(ForkchoiceUpdatedResponse)
    checkRandomObject(GetPayloadV2Response)
    checkRandomObject(GetPayloadV2ResponseExact)
    checkRandomObject(GetPayloadV3Response)
    checkRandomObject(ExecutionPayload)
    checkRandomObject(PayloadAttributes)
    checkRandomObject(GetPayloadResponse)

  test "check blockId":
    let a = RtBlockIdentifier(kind: bidNumber, number: 77.Quantity)
    let x = JrpcConv.encode(a)
    let c = JrpcConv.decode(x, RtBlockIdentifier)
    check c.kind == bidNumber
    check c.number == 77.Quantity

    let d = JrpcConv.decode("\"10\"", RtBlockIdentifier)
    check d.kind == bidAlias
    check d.alias == "10"

    expect JsonReaderError:
      let d = JrpcConv.decode("10", RtBlockIdentifier)
      discard d

  test "check address or list":
    let a = AddressOrList(kind: slkNull)
    let x = JrpcConv.encode(a)
    let c = JrpcConv.decode(x, AddressOrList)
    check c.kind == slkNull

  test "quantity parser and writer":
    template checkType(typeName: typedesc): untyped =
      block:
        let a = JrpcConv.decode("\"0x016345785d8a0000\"", typeName)
        check a.uint64 == 100_000_000_000_000_000'u64
        let b = JrpcConv.encode(a)
        check b == "\"0x16345785d8a0000\""

        let x = JrpcConv.decode("\"0xFFFF_FFFF_FFFF_FFFF\"", typeName)
        check x.uint64 == 0xFFFF_FFFF_FFFF_FFFF_FFFF'u64
        let y = JrpcConv.encode(x)
        check y == "\"0xffffffffffffffff\""

    checkType(Quantity)

  test "AccessListResult":
    let z = AccessListResult()
    let w = JrpcConv.encode(z)
    check w == """{"accessList":[],"gasUsed":"0x0"}"""

  test "AccessListResult with error":
    let z = AccessListResult(
      error: Opt.some("error")
    )
    let w = JrpcConv.encode(z)
    check w == """{"accessList":[],"error":"error","gasUsed":"0x0"}"""

  test "Authorization":
    let z = Authorization()
    let w = JrpcConv.encode(z)
    check w == """{"chainId":"0x0","address":"0x0000000000000000000000000000000000000000","nonce":"0x0","v":"0x0","r":"0x0","s":"0x0"}"""
    let x = JrpcConv.decode(w, Authorization)
    check x == z
