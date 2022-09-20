suite "Test all Ethereum execution APIs":
  test("eth_blockNumber/simple-test"):
    let json = """{
        "id": 1,
        "jsonrpc": "2.0",
        "method": "eth_blockNumber"
    }"""

  test("eth_getTransactionReceipt/get-legacy-receipt"):
    let json = """{
        "id": 26,
        "jsonrpc": "2.0",
        "method": "eth_getTransactionReceipt",
        "params": [
            "0x0d9ba049a158972e7fc1066122ceb31e431483ebf84f90f845f02e326942d467"
        ]
    }"""

  test("eth_getTransactionByHash/get-legacy-tx"):
    let json = """{
        "id": 25,
        "jsonrpc": "2.0",
        "method": "eth_getTransactionByHash",
        "params": [
            "0x0d9ba049a158972e7fc1066122ceb31e431483ebf84f90f845f02e326942d467"
        ]
    }"""

  test("eth_getBlockByHash/get-block-by-hash"):
    let json = """{
        "id": 8,
        "jsonrpc": "2.0",
        "method": "eth_getBlockByHash",
        "params": [
            "0x2ce0e9a8a0b33d45aeb70cf6878d2943deddcf6600e06b84546eaf0a0d2b9643",
            true
        ]
    }"""

  test("eth_getStorage/get-storage"):
    let json = """{
        "id": 10,
        "jsonrpc": "2.0",
        "method": "eth_getStorageAt",
        "params": [
            "0xaa00000000000000000000000000000000000000",
            "0x0100000000000000000000000000000000000000000000000000000000000000",
            "latest"
        ]
    }"""

  test("eth_getTransactionByBlockNumberAndIndex/get-block-n"):
    let json = """{
        "id": 22,
        "jsonrpc": "2.0",
        "method": "eth_getTransactionByBlockNumberAndIndex",
        "params": [
            "0x2",
            "0x0"
        ]
    }"""

  test("eth_getTransactionByBlockHashAndIndex/get-block-n"):
    let json = """{
        "id": 23,
        "jsonrpc": "2.0",
        "method": "eth_getTransactionByBlockHashAndIndex",
        "params": [
            "0x87a74234d5ad70c6ff8e89ffd305fa85048e6cbb4045d66b43a7bf03fe9b6171",
            "0x0"
        ]
    }"""

  test("eth_syncing/check-syncing"):
    let json = """{
        "id": 30,
        "jsonrpc": "2.0",
        "method": "eth_syncing"
    }"""

  test("eth_chainId/get-chain-id"):
    let json = """{
        "id": 6,
        "jsonrpc": "2.0",
        "method": "eth_chainId"
    }"""

  test("eth_getBalance/get-balance"):
    let json = """{
        "id": 7,
        "jsonrpc": "2.0",
        "method": "eth_getBalance",
        "params": [
            "0xaa00000000000000000000000000000000000000",
            "latest"
        ]
    }"""

  test("eth_getBlockByNumber/get-genesis"):
    let json = """{
        "id": 2,
        "jsonrpc": "2.0",
        "method": "eth_getBlockByNumber",
        "params": [
            "0x0",
            true
        ]
    }"""

  test("eth_getBlockByNumber/get-block-n"):
    let json = """{
        "id": 3,
        "jsonrpc": "2.0",
        "method": "eth_getBlockByNumber",
        "params": [
            "0x2",
            true
        ]
    }"""

  test("eth_call/call-simple-contract"):
    let json = """{
        "id": 12,
        "jsonrpc": "2.0",
        "method": "eth_call",
        "params": [
            {
                "from": "0xaa00000000000000000000000000000000000000",
                "to": "0xaa00000000000000000000000000000000000000"
            },
            "latest"
        ]
    }"""

  test("eth_call/call-simple-transfer"):
    let json = """{
        "id": 11,
        "jsonrpc": "2.0",
        "method": "eth_call",
        "params": [
            {
                "from": "0xaa00000000000000000000000000000000000000",
                "gas": "0x186a0",
                "to": "0x0100000000000000000000000000000000000000"
            },
            "latest"
        ]
    }"""


  test("eth_estimateGas/estimate-simple-contract"):
    let json = """{
        "id": 14,
        "jsonrpc": "2.0",
        "method": "eth_estimateGas",
        "params": [
            {
                "from": "0xaa00000000000000000000000000000000000000",
                "to": "0xaa00000000000000000000000000000000000000"
            }
        ]
    }"""

  test("eth_estimateGas/estimate-simple-transfer"):
    let json = """{
        "id": 13,
        "jsonrpc": "2.0",
        "method": "eth_estimateGas",
        "params": [
            {
                "from": "0xaa00000000000000000000000000000000000000",
                "to": "0x0100000000000000000000000000000000000000"
            }
        ]
    }"""

  test("eth_getBlockTransactionCountByNumber/get-genesis"):
    let json = """{
        "id": 18,
        "jsonrpc": "2.0",
        "method": "eth_getBlockTransactionCountByNumber",
        "params": [
            "0x0"
        ]
    }"""

  test("eth_getBlockTransactionCountByNumber/get-block-n"):
    let json = """{
        "id": 19,
        "jsonrpc": "2.0",
        "method": "eth_getBlockTransactionCountByNumber",
        "params": [
            "0x2"
        ]
    }"""

  test("eth_getBlockTransactionCountByHash/get-genesis"):
    let json = """{
        "id": 20,
        "jsonrpc": "2.0",
        "method": "eth_getBlockTransactionCountByHash",
        "params": [
            "0x33ed456e4ddc943a66d74940bcb732efac73c36c5252fe7883a05099acb9b612"
        ]
    }"""

  test("eth_getBlockTransactionCountByHash/get-block-n"):
    let json = """{
        "id": 21,
        "jsonrpc": "2.0",
        "method": "eth_getBlockTransactionCountByHash",
        "params": [
            "0x87a74234d5ad70c6ff8e89ffd305fa85048e6cbb4045d66b43a7bf03fe9b6171"
        ]
    }"""

  test("eth_getTransactionCount/get-account-nonce"):
    let json = """{
        "id": 24,
        "jsonrpc": "2.0",
        "method": "eth_getTransactionCount",
        "params": [
            "0xaa00000000000000000000000000000000000000",
            "latest"
        ]
    }"""

  test("eth_sendRawTransaction/send-legacy-transaction"):
    let json = """{
        "id": 27,
        "jsonrpc": "2.0",
        "method": "eth_sendRawTransaction",
        "params": [
            "0xf86303018261a894aa000000000000000000000000000000000000000a825544820a95a0487f7382a47399a74c487b52fd4c5ff6e981d9b219ca1e8fcb086f1e0733ab92a063203b182cd7e7f45213f46e429e1f5ab2a5660a4ed54b9d6ee76be8d84d5ca8"
        ]
    }"""

  test("eth_getProof/get-account-proof"):
    let json = """{
        "id": 4,
        "jsonrpc": "2.0",
        "method": "eth_getProof",
        "params": [
            "0xaa00000000000000000000000000000000000000",
            [],
            "0x3"
        ]
    }"""

  test("eth_getProof/get-account-proof-with-storage"):
    let json = """{
        "id": 5,
        "jsonrpc": "2.0",
        "method": "eth_getProof",
        "params": [
            "0xaa00000000000000000000000000000000000000",
            [
                "0x01"
            ],
            "0x3"
        ]
    }"""

  test("eth_getCode/get-code"):
    let json = """{
        "id": 9,
        "jsonrpc": "2.0",
        "method": "eth_getCode",
        "params": [
            "0xaa00000000000000000000000000000000000000",
            "latest"
        ]
    }"""

