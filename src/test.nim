import web3
import asyncdispatch2, nimcrypto, json_rpc/rpcclient
import ethtypes, ethprocs, stintjson, ethhexstrings
import stint except UInt256


contract(TestContract):
  proc sendCoin(receiver: Address, amount: Uint): Bool
  proc getBalance(address: Address): Uint {.view.}
  proc Transfer(fromAddr: indexed[Address], toAddr: indexed[Address], value: Uint256) {.event.}
  #proc Transfers(fromAddr: indexed[Address], toAddr: indexed[Address], value: Uint256[]) {.event.}
  proc sendCoins(receiver: Address, amount: Uint[]): Bool

#var
#  x2 = TestContract(address:
#    "254dffcd3277C0b1660F6d42EFbB754edaBAbC2B".toAddress,
#    client: newRpcHttpClient()
#  )
#  sender2 = x2.initSender("127.0.0.1", 8545,
#    "90f8bf6a479f320ead074411a4b0e7944ea8c9c1".toAddress)

var
  x = TestContract(address:
    "254dffcd3277C0b1660F6d42EFbB754edaBAbC2B".toAddress,
    client: newRpcHttpClient()
  )
  sender = x.initSender("127.0.0.1", 8545,
    "90f8bf6a479f320ead074411a4b0e7944ea8c9c1".toAddress)
  receiver = x.initReceiver("127.0.0.1", 8545)
  eventListener = receiver.initEventListener()

x.callbacks.Transfer.add proc (fromAddr, toAddr: Address, value: Uint256) =
  echo $value, " coins were transferred from ", fromAddr.toHex, " to ", toAddr.toHex

echo waitFor sender.getBalance(
  fromHex(Stuint[256], "ffcf8fdee72ac11b5c542428b35eef5769c409f0")
)

echo toHex(waitFor sender.sendCoin(
  fromHex(Stuint[256], "ffcf8fdee72ac11b5c542428b35eef5769c409f0"),
  256.to(Stuint[256])
))

echo waitFor sender.getBalance(
  fromHex(Stuint[256], "ffcf8fdee72ac11b5c542428b35eef5769c409f0")
)

waitFor eventListener.listen()

echo toHex(waitFor sender.sendCoin(
  fromHex(Stuint[256], "ffcf8fdee72ac11b5c542428b35eef5769c409f0"),
  10.to(Stuint[256])
))

waitFor eventListener.listen()
