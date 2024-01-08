# nim-web3
# Copyright (c) 2018-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[options, json],
  pkg/unittest2,
  chronos, stint,
  ../web3,
  ./helpers/utils,
  ./helpers/primitives_utils,
  ./helpers/depositcontract

contract(DepositContract):
  proc deposit(pubkey: DynamicBytes[0, 48], withdrawalCredentials: DynamicBytes[0, 32], signature: DynamicBytes[0, 96], deposit_data_root: FixedBytes[32])
  proc get_deposit_root(): FixedBytes[32]
  proc DepositEvent(pubkey: DynamicBytes[0, 48], withdrawalCredentials: DynamicBytes[0, 32], amount: DynamicBytes[0, 8], signature: DynamicBytes[0, 96], merkleTreeIndex: DynamicBytes[0, 8]) {.event.}

suite "Deposit contract":

  test "deposits":
    proc test() {.async.} =
      let web3 = await newWeb3("ws://127.0.0.1:8545/")
      let accounts = await web3.provider.eth_accounts()
      let gasPrice = int(await web3.provider.eth_gasPrice())
      web3.defaultAccount = accounts[0]

      let receipt = await web3.deployContract(DepositContractCode, gasPrice=gasPrice)
      let contractAddress = receipt.contractAddress.get
      echo "Deployed Deposit contract: ", contractAddress

      var ns = web3.contractSender(DepositContract, contractAddress)

      let notifFut = newFuture[void]()
      var notificationsReceived = 0

      var pk = DynamicBytes[0, 48].fromHex("0xa20469ec49fdfdcaaa68c470642feb9d7d0e612026c6243928772a7277bde77d081e63cc9034cee9eb5abee66ea12861")
      var cr = DynamicBytes[0, 32].fromHex("0x0012c7b99594801d513ae92396379e5ffcf60e23127cbcabb166db28586f01aa")
      var sig = DynamicBytes[0, 96].fromHex("0x81c7536816ff1e4ca6a52b5e853c19e9def14c01b07f0e1ac9b1e8a198bf78c98e98e74465d13e2978ae720dcab0a7da10fa56221477773ad7c3f82317c3e0f12a76f47332b9b5350b655ae196db33221f64183d1da3784f608001489ff523d5")
      var dataRoot = FixedBytes[32].fromHex("0x2ed19a8a1a22a2ff61fbd3862d4ff9f9bd45836efe313e6ecad6dd907f1b6078")

      var fut = newFuture[void]()

      let options = FilterOptions(fromBlock: some(blockId(0)))
      let s = await ns.subscribe(DepositEvent, options) do (
          pubkey: DynamicBytes[0, 48], withdrawalCredentials: DynamicBytes[0, 32], amount: DynamicBytes[0, 8], signature: DynamicBytes[0, 96], merkleTreeIndex: DynamicBytes[0, 8])
          {.raises: [], gcsafe.}:
        try:
          echo "onDeposit"
          echo "pubkey: ", pubkey
          echo "withdrawalCredentials: ", withdrawalCredentials
          echo "amount: ", amount
          echo "signature: ", signature
          echo "merkleTreeIndex: ", merkleTreeIndex
          assert(pubkey == pk)
          fut.complete()
        except Exception as err:
          # chronos still raises exceptions which inherit directly from Exception
          doAssert false, err.msg
      do (err: CatchableError):
        echo "Error from DepositEvent subscription: ", err.msg

      discard await ns.deposit(pk, cr, sig, dataRoot).send(value = 32.u256.ethToWei, gasPrice=gasPrice)

      await fut
      echo "hash_tree_root: ", await ns.get_deposit_root().call()
      await web3.close()

    try:
      waitFor test()
    except CatchableError as err:
      echo "Failed to process deposit contract", err.msg
      fail()
