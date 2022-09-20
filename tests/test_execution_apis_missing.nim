suite("Missing APIs")
  test("eth_blockNumber/simple-test"):
    let json = """{
        "id": 1,
        "jsonrpc": "2.0",
        "method": "eth_blockNumber"
    }"""

  test("eth_createAccessList/create-al-simple-contract"):
    let json = """{
        "id": 16,
        "jsonrpc": "2.0",
        "method": "eth_createAccessList",
        "params": [
            {
                "from": "0x658bdf435d810c91414ec09147daa6db62406379",
                "to": "0xaa00000000000000000000000000000000000000"
            },
            "latest"
        ]
    }"""

  test("eth_createAccessList/create-al-simple-transfer"):
    let json = """{
        "id": 15,
        "jsonrpc": "2.0",
        "method": "eth_createAccessList",
        "params": [
            {
                "from": "0x658bdf435d810c91414ec09147daa6db62406379",
                "to": "0x0100000000000000000000000000000000000000"
            },
            "latest"
        ]
    }"""

  test("eth_createAccessList/create-al-multiple-reads"):
    let json = """{
        "id": 17,
        "jsonrpc": "2.0",
        "method": "eth_createAccessList",
        "params": [
            {
                "from": "0x658bdf435d810c91414ec09147daa6db62406379",
                "to": "0xbb00000000000000000000000000000000000000"
            },
            "latest"
        ]
    }"""

  test("debug_getRawBlock/get-genesis"):
    let json = """{
        "id": 4,
        "jsonrpc": "2.0",
        "method": "debug_getRawBlock",
        "params": [
            "0x0"
        ]
    }"""

  test("debug_getRawBlock/get-block-n"):
    let json = """{
        "id": 5,
        "jsonrpc": "2.0",
        "method": "debug_getRawBlock",
        "params": [
            "0x3"
        ]
    }"""

  test("debug_getRawBlock/get-invalid-number"):
    let json = """{
        "id": 6,
        "jsonrpc": "2.0",
        "method": "debug_getRawBlock",
        "params": [
            "2"
        ]
    }"""

  test("debug_getRawHeader/get-block-n"):
    let json = """{
        "id": 2,
        "jsonrpc": "2.0",
        "method": "debug_getRawHeader",
        "params": [
            "0x3"
        ]
    }"""

  test("debug_getRawHeader/get-invalid-number"):
    let json = """{
        "id": 3,
        "jsonrpc": "2.0",
        "method": "debug_getRawHeader",
        "params": [
            "2"
        ]
    }"""

  test("debug_getRawTransaction/get-tx"):
    let json = """{
        "id": 10,
        "jsonrpc": "2.0",
        "method": "debug_getRawTransaction",
        "params": [
            "0x74e41d593675913d6d5521f46523f1bd396dff1891bdb35f59be47c7e5e0b34b"
        ]
    }"""

  test("debug_getRawTransaction/get-invalid-hash"):
    let json = """{
        "id": 11,
        "jsonrpc": "2.0",
        "method": "debug_getRawTransaction",
        "params": [
            "1000000000000000000000000000000000000000000000000000000000000001"
        ]
    }"""

  test("debug_getRawReceipts/get-genesis"):
    let json = """{
        "id": 7,
        "jsonrpc": "2.0",
        "method": "debug_getRawReceipts",
        "params": [
            "0x0"
        ]
    }"""

  test("debug_getRawReceipts/get-block-n"):
    let json = """{
        "id": 8,
        "jsonrpc": "2.0",
        "method": "debug_getRawReceipts",
        "params": [
            "0x3"
        ]
    }"""

  test("debug_getRawReceipts/get-invalid-number"):
    let json = """{
        "id": 9,
        "jsonrpc": "2.0",
        "method": "debug_getRawReceipts",
        "params": [
            "2"
        ]
    }"""

  test("eth_feeHistory/fee-history"):
    let json = """{
        "id": 31,
        "jsonrpc": "2.0",
        "method": "eth_feeHistory",
        "params": [
            "0x1",
            "0x2",
            [
                95,
                99
            ]
        ]
    }"""
