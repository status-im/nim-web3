import pkg/unittest2
import ../web3
import chronos, nimcrypto, options, json, stint
import test_utils
import ./depositcontract

contract(DepositContract):
  proc deposit(pubkey: Bytes48, withdrawalCredentials: Bytes32, signature: Bytes96, deposit_data_root: FixedBytes[32])
  proc get_deposit_root(): FixedBytes[32]
  proc DepositEvent(pubkey: Bytes48, withdrawalCredentials: Bytes32, amount: Bytes8, signature: Bytes96, merkleTreeIndex: Bytes8) {.event.}

suite "Deposit contract":

  test "deposits":
    proc test() {.async.} =
      let web3 = await newWeb3("ws://127.0.0.1:8545/")
      let accounts = await web3.provider.eth_accounts()
      web3.defaultAccount = accounts[0]

      let receipt = await web3.deployContract(DepositContractCode)
      let contractAddress = receipt.contractAddress.get
      echo "Deployed Deposit contract: ", contractAddress

      var ns = web3.contractSender(DepositContract, contractAddress)

      let notifFut = newFuture[void]()
      var notificationsReceived = 0

      var pk = Bytes48.fromHex("0x97f1d3a73197d7942695638c4fa9ac0fc3688c4f9774b905a14e3a3f171bac586c55e83ff97a1aeffb3af00adb22c6bb")
      var cr = Bytes32.fromHex("0xaa000000000000000000000000000000000000000000000000000000000000bb")
      var sig = Bytes96.fromHex("0xad606d747d9d8590583107e23b41d6191215495df34a34d767e81c3c7f1f2d7041f421f3486186044a02c3dd65a05b44061455c2ca7d6525db68d5fa146e34de8234d3acd8de7e00b971acd4458b740fa6368d437db2c8dae6b2011db9be2f07")
      var dataRoot = FixedBytes[32].fromHex("0x60D0C2DAF1C10803DB5781D876CDBC42EADD52E6E49C2A1A7C1E5952B279E463")

      var fut = newFuture[void]()

      let s = await ns.subscribe(DepositEvent, %*{"fromBlock": "0x0"}) do (
          pubkey: Bytes48, withdrawalCredentials: Bytes32, amount: Bytes8, signature: Bytes96, merkleTreeIndex: Bytes8)
          {.raises: [Defect], gcsafe.}:
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

      discard await ns.deposit(pk, cr, sig, dataRoot).send(value = 32.u256.ethToWei)

      await fut
      echo "hash_tree_root: ", await ns.get_deposit_root().call()
      await web3.close()

    waitFor test()
