import
    std/unittest,
    serialization,
    ../web3/decoding,
    ../web3/eth_api_types,
    ../web3/abi_serialization,
    ./helpers/primitives_utils

suite "ABI serialization":
  test "encode and decode tuple":
    let fromAddr = address(3)
    let toAddr = address(4)
    let amount: uint64 = 42

    let payload = ( fromAddr,  toAddr,  amount)

    let encoded = Abi.encode(payload)
    check encoded.len > 0

    let decoded = Abi.decode(encoded, typeof(payload))
    check decoded == payload