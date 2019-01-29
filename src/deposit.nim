import web3
import asyncdispatch2, nimcrypto, json_rpc/rpcclient
import ethtypes, ethprocs, stintjson, ethhexstrings
import stint except UInt256


contract(TestContract):
  proc Deposit(previous_deposit_root: Bytes32, data: Bytes, merkle_tree_index: bytes) {.event.}
  proc ChainStart(deposit_root: bytes32, time: bytes) {.event.}
  proc deposit(deposit_input: bytes) {.payable.}
  proc get_deposit_root(): bytes32 {.view.}
  #proc get_branch(leaf: uint256): bytes32[32] {.pure.}

#var
#  x2 = TestContract(address:
#    "254dffcd3277C0b1660F6d42EFbB754edaBAbC2B".toAddress,
#    client: newRpcHttpClient()
#  )
#  sender2 = x2.initSender("127.0.0.1", 8545,
#    "90f8bf6a479f320ead074411a4b0e7944ea8c9c1".toAddress)

var
  x = TestContract(address:
    "4e7f73f0bbee44db86fbf8b957cf7c8bf330c2fe".toAddress,
    client: newRpcHttpClient()
  )
  sender = x.initSender("127.0.0.1", 8545,
    "45b6fc37a833d2f20dc25917f0a632f351be474b".toAddress)
  receiver = x.initReceiver("127.0.0.1", 8545)
  eventListener = receiver.initEventListener()

#x.callbacks.Transfer.add proc (fromAddr, toAddr: Address, value: Uint256) =
#  echo $value, " coins were transferred from ", fromAddr.toHex, " to ", toAddr.toHex
#
#echo waitFor sender.getBalance(
#  fromHex(Stuint[256], "ffcf8fdee72ac11b5c542428b35eef5769c409f0")
#)
#
#echo toHex(waitFor sender.sendCoin(
#  fromHex(Stuint[256], "ffcf8fdee72ac11b5c542428b35eef5769c409f0"),
#  256.to(Stuint[256])
#))
#
#echo waitFor sender.getBalance(
#  fromHex(Stuint[256], "ffcf8fdee72ac11b5c542428b35eef5769c409f0")
#)
#
#waitFor eventListener.listen()
#
#echo toHex(waitFor sender.sendCoin(
#  fromHex(Stuint[256], "ffcf8fdee72ac11b5c542428b35eef5769c409f0"),
#  10.to(Stuint[256])
#))

waitFor eventListener.listen()
