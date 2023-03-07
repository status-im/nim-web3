import
  std/typetraits,
  unittest, std/json, json_rpc/jsonmarshal, json_serialization,
  stint,
  ../web3/[conversions, ethtypes]

proc `==`(x, y: Quantity): bool {.borrow, noSideEffect.}

suite "JSON-RPC Quantity":
  test "Valid":
    for (validQuantityStr, validQuantity) in [
        ("0x0", Quantity 0),
        ("0x123", Quantity 291),
        ("0x1234", Quantity 4660)]:
      let validQuantityJson = $(%validQuantityStr)
      var resQuantity: Quantity
      var resUInt256: UInt256
      var resUInt256Ref: ref UInt256
      fromJson(%validQuantityStr, "", resQuantity)
      fromJson(%validQuantityStr, "", resUInt256)
      fromJson(%validQuantityStr, "", resUInt256Ref)
      check:
        Json.decode(validQuantityJson, Quantity) == validQuantity
        Json.encode(validQuantity) == validQuantityJson
        resQuantity == validQuantity
        resUInt256 == validQuantity.distinctBase.u256
        resUInt256Ref[] == validQuantity.distinctBase.u256

  test "Invalid Quantity/UInt256/ref UInt256":
    # TODO once https://github.com/status-im/nimbus-eth2/pull/3850 addressed,
    # re-add "0x0400" test case as invalid.
    for invalidStr in [
        "", "1234", "01234", "x1234", "0x", "ff"]:
      template checkInvalids(typeName: untyped) =
        var resQuantity: `typeName`
        try:
          fromJson(%invalidStr, "", resQuantity)
          echo `typeName`, invalidStr
          check: false
        except ValueError:
          check: true
        except CatchableError:
          check: false

      checkInvalids(Quantity)
      checkInvalids(UInt256)
      checkInvalids(ref UInt256)

  test "Block decoding":
    const blockJson = """
     {"difficulty":"0x1","extraData":"0x696e667572612d696f00000000000000000000000000000000000000000000004ede22d16eaf5bbab47534ee64a1ec1728ed63b1243672ee9623532fffd747b368cddb4674f849e467884f0e6c6563440ea5fd812cc33fcd19fb9c323b0c92c300","gasLimit":"0x7a1200","gasUsed":"0x3aca3e","hash":"0x5ac670562dbf877a45039d65ec3c2e3402a40eda9b1dba931c2376ab7d0927c2","logsBloom":"0x40000000004000120000000100030000882000040000001800010000020000000000000000001400080040004080400402024800000004000088f0320000a0000016000100110060800000080000020000000020000000000050000009010000080000040220280000080240048008000001381a1100000000000010000440000000004200000018001102280400003040040020001a000026000488000101000120000a0002000081220000100000000200000000040440a02400010000000002000002400100840000080000000080000008c0c080000008000000220860082002000000001000000041040002000000008000010004000400010400040001","miner":"0x0000000000000000000000000000000000000000","mixHash":"0x0000000000000000000000000000000000000000000000000000000000000000","nonce":"0x0000000000000000","number":"0x42a3da","parentHash":"0xe0190ed0683835483c35e0c0a98bf0958ed2ca7313428c9026db51604007e299","receiptsRoot":"0x12fff235455db65dcdc525d2491b9e0526e02d70a1515fba155b1de9f648abf3","sha3Uncles":"0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347","size":"0x2a5d","stateRoot":"0xccb37180b5fca41e43395d524a0ee83a1efc69f2fb61f90a51f3dc8f40f2144e","timestamp":"0x603cab8c","totalDifficulty":"0x624910","transactions":["0xa3c07dc59bfdb1bfc2d50920fed2ef2c1c4e0a09fe2325dbc14e07702f965a78","0x7b33b36e905c8e83a519216444aff4952bfbce5c49247ecc70f227a56068247e","0x11fa3f25957caa1918ecb1f2c1eaeef46c1af983e1b7eee65cefe2a752f7e9da","0x7028ef43993c84e751bbcb126cbaa52d7b732efe4daf95e6e0fbff06e43f0277","0xe287b4939a51aff8a78b836c56db18ca1559ba77303b1e0cee9075ff737f4a57","0xb79cb96a3ff5bb9aca4ce2024a57023cfda163d6135f3ff6a0d9f0b9fac44efb","0xad0d4bfb6b4276616c7d88fe2576903d6c17f6bee1d10db15de203a88bda2898","0x73127fadab4c4ceed35be81e3e97549d2005bfdbc49083ce81f135662edd6869","0xff522f3e2a2d451acf2df2341d8ed9e982dbf7160b327f34b8b5ca25b377a74f","0x2d100b5abba751743920cf56614195c0e3685d93bfdbe5325c35a933f5195e2c","0x9611c7cac2e14fed4051d34f74eed1bace9da8e79446d4e03f479c318de24087","0x43f29106dac821e5069b3c0b27a61d01116a8e69096388d57b70a9e5354e0457","0xb71fe345141491f54cb53e4af44d581cbd631c0b7bd12019077c1dc354b1c5ab"],"transactionsRoot":"0x08fd011674202c6df63822f877e88d7ca0fe41e5deb8bc2b8830f1a29ce864f0","uncles":[]}
    """
    var b1, b2: BlockObject
    fromJson(parseJson(blockJson), "", b1)
    fromJson(parseJson($(%b1)), "", b2)
    check $(%b1) == $(%b2)
