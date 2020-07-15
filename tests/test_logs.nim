import ../web3
import chronos, nimcrypto, options, json, stint
import test_utils

import random

#[ Contract LoggerContract
pragma solidity >=0.4.25 <0.6.0;

contract LoggerContract {

   uint fNum;

   event MyEvent(address sender, uint value);


   function invoke(uint value) public {
       emit MyEvent(msg.sender, value);
   }
}
]#
contract(LoggerContract):
  proc MyEvent(sender: Address, number: Uint256) {.event.}
  proc invoke(value: Uint256)

const LoggerContractCode = "6080604052348015600f57600080fd5b5060bc8061001e6000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c80632b30d2b814602d575b600080fd5b604760048036036020811015604157600080fd5b50356049565b005b604080513381526020810183905281517fdf50c7bb3b25f812aedef81bc334454040e7b27e27de95a79451d663013b7e17929181900390910190a15056fea265627a7a723058202ed7f5086297d2a49fbe359f4e489a007b69eb5077f5c76328bffdb63f164b4b64736f6c63430005090032"

var contractAddress = Address.fromHex("0xEA255DeA28c84F698Fa195f87fC83D1d4125ef9C")

proc test() {.async.} =
  let web3 = await newWeb3("ws://localhost:8545/")
  let accounts = await web3.provider.eth_accounts()
  echo "accounts: ", accounts
  web3.defaultAccount = accounts[0]
  # let q = await web3.provider.eth_blockNumber()
  echo "block: ", uint64(await web3.provider.eth_blockNumber())


  block: # LoggerContract
    let receipt = await web3.deployContract(LoggerContractCode)
    contractAddress = receipt.contractAddress.get
    echo "Deployed LoggerContract contract: ", contractAddress

    let ns = web3.contractSender(LoggerContract, contractAddress)

    proc testInvoke() {.async.} =
      let r = rand(1 .. 1000000)
      echo "invoke(", r, "): ", await ns.invoke(r.u256).send()

    const invocationsBefore = 5
    const invocationsAfter = 5

    for i in 1 .. invocationsBefore:
      await testInvoke()

    # Now that we have invoked the function `invocationsBefore` let's wait for the transactions to
    # settle and see if we receive the logs after subscription. Note in ganache transactions are
    # processed immediately. With a real eth client we would need to wait for transactions to settle

    await sleepAsync(3.seconds)

    let notifFut = newFuture[void]()
    var notificationsReceived = 0

    let s = await ns.subscribe(MyEvent, %*{"fromBlock": "0x0"}) do (
        sender: Address, value: Uint256)
        {.raises: [Defect], gcsafe.}:
      try:
        echo "onEvent: ", sender, " value ", value
        inc notificationsReceived

        if notificationsReceived == invocationsBefore + invocationsAfter:
          notifFut.complete()
      except Exception as err:
        # chronos still raises exceptions which inherit directly from Exception
        doAssert false, err.msg
    do (err: CatchableError):
      echo "Error from MyEvent subscription: ", err.msg

    for i in 1 .. invocationsAfter:
      await testInvoke()

    await notifFut

    await s.unsubscribe()
  await web3.close()

waitFor test()
