import pkg/unittest2
import json_rpc/jsonmarshal
import ../web3/[conversions, ethtypes, engine_api_types]

proc should_pass[T](json_string: string): void =
  var to_pass: T
  try:
    fromJson(%json_string, "", to_pass)
  except CatchableError as err:
    echo "Failed to process type", $typeof(T)
    echo err.msg
    fail()

suite "Test all Ethereum execution APIs":
  test("eth_blockNumber/simple-test"):
    should_pass[Quantity]("""{
        "id": 1,
        "jsonrpc": "2.0",
        "method": "eth_blockNumber"
    }""")

  test("eth_getTransactionReceipt/get-legacy-receipt"):
    should_pass[ReceiptObject]("""{
        "id": 26,
        "jsonrpc": "2.0",
        "method": "eth_getTransactionReceipt",
        "params": [
            "0x0d9ba049a158972e7fc1066122ceb31e431483ebf84f90f845f02e326942d467"
        ]
    }""")

  test("eth_getTransactionByHash/get-legacy-tx"):
    should_pass[TransactionObject]("""{
        "id": 25,
        "jsonrpc": "2.0",
        "method": "eth_getTransactionByHash",
        "params": [
            "0x0d9ba049a158972e7fc1066122ceb31e431483ebf84f90f845f02e326942d467"
        ]
    }""")

  test("eth_getBlockByHash/get-block-by-hash"):
    should_pass[BlockObject]("""{
        "id": 8,
        "jsonrpc": "2.0",
        "method": "eth_getBlockByHash",
        "params": [
            "0x2ce0e9a8a0b33d45aeb70cf6878d2943deddcf6600e06b84546eaf0a0d2b9643",
            true
        ]
    }""")

  test("eth_getStorage/get-storage"):
    should_pass[seq[byte]]("""{
        "id": 10,
        "jsonrpc": "2.0",
        "method": "eth_getStorageAt",
        "params": [
            "0xaa00000000000000000000000000000000000000",
            "0x0100000000000000000000000000000000000000000000000000000000000000",
            "latest"
        ]
    }""")

  test("eth_getTransactionByBlockNumberAndIndex/get-block-n"):
    should_pass[TransactionObject]("""{
        "id": 22,
        "jsonrpc": "2.0",
        "method": "eth_getTransactionByBlockNumberAndIndex",
        "params": [
            "0x2",
            "0x0"
        ]
    }""")

  test("eth_getTransactionByBlockHashAndIndex/get-block-n"):
    should_pass[TransactionObject]("""{
        "id": 23,
        "jsonrpc": "2.0",
        "method": "eth_getTransactionByBlockHashAndIndex",
        "params": [
            "0x87a74234d5ad70c6ff8e89ffd305fa85048e6cbb4045d66b43a7bf03fe9b6171",
            "0x0"
        ]
    }""")

  test("eth_chainId/get-chain-id"):
    should_pass[Quantity]("""{
        "id": 6,
        "jsonrpc": "2.0",
        "method": "eth_chainId"
    }""")

  test("eth_getBalance/get-balance"):
    should_pass[UInt256]("""{
        "id": 7,
        "jsonrpc": "2.0",
        "method": "eth_getBalance",
        "params": [
            "0xaa00000000000000000000000000000000000000",
            "latest"
        ]
    }""")

  test("eth_getBlockByNumber/get-genesis"):
    should_pass[BlockObject]("""{
        "id": 2,
        "jsonrpc": "2.0",
        "method": "eth_getBlockByNumber",
        "params": [
            "0x0",
            true
        ]
    }""")

  test("eth_getBlockByNumber/get-block-n"):
    should_pass[BlockObject]("""{
        "id": 3,
        "jsonrpc": "2.0",
        "method": "eth_getBlockByNumber",
        "params": [
            "0x2",
            true
        ]
    }""")

  test("eth_call/call-simple-contract"):
    should_pass[string]("""{
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
    }""")

  test("eth_call/call-simple-transfer"):
    should_pass[string]("""{
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
    }""")


  test("eth_estimateGas/estimate-simple-contract"):
    should_pass[UInt256]("""{
        "id": 14,
        "jsonrpc": "2.0",
        "method": "eth_estimateGas",
        "params": [
            {
                "from": "0xaa00000000000000000000000000000000000000",
                "to": "0xaa00000000000000000000000000000000000000"
            }
        ]
    }""")

  test("eth_estimateGas/estimate-simple-transfer"):
    should_pass[UInt256]("""{
        "id": 13,
        "jsonrpc": "2.0",
        "method": "eth_estimateGas",
        "params": [
            {
                "from": "0xaa00000000000000000000000000000000000000",
                "to": "0x0100000000000000000000000000000000000000"
            }
        ]
    }""")

  test("eth_getBlockTransactionCountByNumber/get-genesis"):
    should_pass[Quantity]("""{
        "id": 18,
        "jsonrpc": "2.0",
        "method": "eth_getBlockTransactionCountByNumber",
        "params": [
            "0x0"
        ]
    }""")

  test("eth_getBlockTransactionCountByNumber/get-block-n"):
    should_pass[Quantity]("""{
        "id": 19,
        "jsonrpc": "2.0",
        "method": "eth_getBlockTransactionCountByNumber",
        "params": [
            "0x2"
        ]
    }""")

  test("eth_getBlockTransactionCountByHash/get-genesis"):
    should_pass[Quantity]("""{
        "id": 20,
        "jsonrpc": "2.0",
        "method": "eth_getBlockTransactionCountByHash",
        "params": [
            "0x33ed456e4ddc943a66d74940bcb732efac73c36c5252fe7883a05099acb9b612"
        ]
    }""")

  test("eth_getBlockTransactionCountByHash/get-block-n"):
    should_pass[Quantity]("""{
        "id": 21,
        "jsonrpc": "2.0",
        "method": "eth_getBlockTransactionCountByHash",
        "params": [
            "0x87a74234d5ad70c6ff8e89ffd305fa85048e6cbb4045d66b43a7bf03fe9b6171"
        ]
    }""")

  test("eth_getTransactionCount/get-account-nonce"):
    should_pass[Quantity]("""{
        "id": 24,
        "jsonrpc": "2.0",
        "method": "eth_getTransactionCount",
        "params": [
            "0xaa00000000000000000000000000000000000000",
            "latest"
        ]
    }""")

  test("eth_sendRawTransaction/send-legacy-transaction"):
    should_pass[TxHash]("""{
        "id": 27,
        "jsonrpc": "2.0",
        "method": "eth_sendRawTransaction",
        "params": [
            "0xf86303018261a894aa000000000000000000000000000000000000000a825544820a95a0487f7382a47399a74c487b52fd4c5ff6e981d9b219ca1e8fcb086f1e0733ab92a063203b182cd7e7f45213f46e429e1f5ab2a5660a4ed54b9d6ee76be8d84d5ca8"
        ]
    }""")

  test("eth_getProof/get-account-proof"):
    should_pass[ProofResponse]("""{
        "id": 4,
        "jsonrpc": "2.0",
        "method": "eth_getProof",
        "params": [
            "0xaa00000000000000000000000000000000000000",
            [],
            "0x3"
        ]
    }""")

  test("eth_getProof/get-account-proof-with-storage"):
    should_pass[ProofResponse]("""{
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
    }""")

  test("eth_getCode/get-code"):
    should_pass[seq[byte]]("""{
        "id": 9,
        "jsonrpc": "2.0",
        "method": "eth_getCode",
        "params": [
            "0xaa00000000000000000000000000000000000000",
            "latest"
        ]
    }""")

  # TODO: @tavurth
  # test("eth_syncing/check-syncing"):
  #   should_pass[JsonNode]("""{
  #       "id": 30,
  #       "jsonrpc": "2.0",
  #       "method": "eth_syncing"
  #   }""")

# suite("Currently missing APIs")
#   test("eth_feeHistory/fee-history"):
#     let json = """{
#         "id": 31,
#         "jsonrpc": "2.0",
#         "method": "eth_feeHistory",
#         "params": [
#             "0x1",
#             "0x2",
#             [
#                 95,
#                 99
#             ]
#         ]
#     }"""

#   test("eth_createAccessList/create-al-simple-contract"):
#     let json = """{
#         "id": 16,
#         "jsonrpc": "2.0",
#         "method": "eth_createAccessList",
#         "params": [
#             {
#                 "from": "0x658bdf435d810c91414ec09147daa6db62406379",
#                 "to": "0xaa00000000000000000000000000000000000000"
#             },
#             "latest"
#         ]
#     }"""

#   test("eth_createAccessList/create-al-simple-transfer"):
#     let json = """{
#         "id": 15,
#         "jsonrpc": "2.0",
#         "method": "eth_createAccessList",
#         "params": [
#             {
#                 "from": "0x658bdf435d810c91414ec09147daa6db62406379",
#                 "to": "0x0100000000000000000000000000000000000000"
#             },
#             "latest"
#         ]
#     }"""

#   test("eth_createAccessList/create-al-multiple-reads"):
#     let json = """{
#         "id": 17,
#         "jsonrpc": "2.0",
#         "method": "eth_createAccessList",
#         "params": [
#             {
#                 "from": "0x658bdf435d810c91414ec09147daa6db62406379",
#                 "to": "0xbb00000000000000000000000000000000000000"
#             },
#             "latest"
#         ]
#     }"""
