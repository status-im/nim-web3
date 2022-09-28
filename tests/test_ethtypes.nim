import 
  unittest,
  ../web3/ethtypes

suite "Hex decoding":
  test "Should strip the prefix":
    let
      raw = "0x123456"
      stripped = strip0xPrefix(raw)
    check stripped == "123456"
  
  test "Should not strip the prefix if meaningful characters start with 0b":
    let
      raw = "0x0b123456"
      stripped = strip0xPrefix(raw)
    check stripped == "0x0b123456"

