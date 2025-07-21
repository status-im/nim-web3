# nim-web3
# Copyright (c) 2018-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/random,
  pkg/unittest2,
  ../web3,
  chronos, stint,
  results,
  ./helpers/utils

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
  proc MyEvent(sender: Address, number: UInt256) {.event.}
  proc invoke(value: UInt256)

const LoggerContractCode = "6080604052348015600f57600080fd5b5060fb8061001e6000396000f3fe6080604052348015600f57600080fd5b506004361060285760003560e01c80632b30d2b814602d575b600080fd5b605660048036036020811015604157600080fd5b81019080803590602001909291905050506058565b005b7fdf50c7bb3b25f812aedef81bc334454040e7b27e27de95a79451d663013b7e173382604051808373ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff1681526020018281526020019250505060405180910390a15056fea265627a7a72315820cb9980a67d78ee2e84fedf080db8463ce4a944fccf8b5512448163aaff0aea8964736f6c63430005110032"

var contractAddress = Address.fromHex("0xEA255DeA28c84F698Fa195f87fC83D1d4125ef9C")

suite "Logs":

  test "subscribe":
    proc test() {.async: (raises: [CancelledError, Exception]).} =
      let web3 = await newWeb3("ws://127.0.0.1:8545/")
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

        proc testInvoke() {.async: (raises: [CancelledError, Exception]).} =
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

        let options = FilterOptions(fromBlock: Opt.some(blockId(0.BlockNumber)))
        let s = await ns.subscribe(MyEvent, options) do (
            sender: Address, value: UInt256)
            {.raises: [], gcsafe.}:
          try:
            echo "onEvent: ", sender, " value ", value.toHex
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
