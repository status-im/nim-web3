suite("Debug APIs")
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
