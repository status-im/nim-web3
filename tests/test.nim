import pkg/unittest2
import ../web3
import chronos, options, json, stint, parseutils
import test_utils


contract(EncodingTest):
  proc setBool(val: Bool)
  proc getBool(): Bool {.view.}

const EncodingTestCode =  "608060405260008060006101000a81548160ff02191690831515021790555034801561002a57600080fd5b506101048061003a6000396000f3006080604052600436106049576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff16806312a7b91414604e5780631e26fd3314607a575b600080fd5b348015605957600080fd5b50606060a6565b604051808215151515815260200191505060405180910390f35b348015608557600080fd5b5060a460048036038101908080351515906020019092919050505060bc565b005b60008060009054906101000a900460ff16905090565b806000806101000a81548160ff021916908315150217905550505600a165627a7a72305820be0033d3993a43508dbcb21e47d345021ad5f89e26e035767fdae7ba9ef2ae310029"

#[ Contract EncodingTest
pragma solidity ^0.4.18;

contract EncodingTest {
    bool boolVal = false;

    function setBool(bool _boolVal) public {
        boolVal = _boolVal;
    }

    function getBool() public constant returns (bool) {
        return boolVal;
    }
}
]#

#[ Contract NumberStorage
pragma solidity ^0.4.18;

contract NumberStorage {
   uint num;

   function setNumber(uint _num) public {
       num = _num;
   }

   function getNumber() public constant returns (uint) {
       return num;
   }
}
]#
contract(NumberStorage):
  proc setNumber(number: UInt256)
  proc getNumber(): UInt256 {.view.}

const NumberStorageCode = "6060604052341561000f57600080fd5b60bb8061001d6000396000f30060606040526004361060485763ffffffff7c01000000000000000000000000000000000000000000000000000000006000350416633fb5c1cb8114604d578063f2c9ecd8146062575b600080fd5b3415605757600080fd5b60606004356084565b005b3415606c57600080fd5b60726089565b60405190815260200160405180910390f35b600055565b600054905600a165627a7a7230582023e722f35009f12d5698a4ab22fb9d55a6c0f479fc43875c65be46fbdd8db4310029"

#[ Contract MetaCoin
pragma solidity >=0.4.25 <0.6.0;

contract MetaCoin {
    mapping (address => uint) balances;

    event Transfer(address indexed _from, address indexed _to, uint256 _value);

    constructor() public {
        balances[tx.origin] = 10000;
    }

    function sendCoin(address receiver, uint amount) public returns(bool sufficient) {
        if (balances[msg.sender] < amount) return false;
        balances[msg.sender] -= amount;
        balances[receiver] += amount;
        emit Transfer(msg.sender, receiver, amount);
        return true;
    }

    function getBalance(address addr) public view returns(uint) {
        return balances[addr];
    }
}
]#
contract(MetaCoin):
  proc sendCoin(receiver: Address, amount: UInt256): Bool
  proc getBalance(address: Address): UInt256 {.view.}
  proc Transfer(fromAddr, toAddr: indexed[Address], value: UInt256) {.event.}
  proc BlaBla(fromAddr: indexed[Address]) {.event.}

const MetaCoinCode = "608060405234801561001057600080fd5b5032600090815260208190526040902061271090556101c2806100346000396000f30060806040526004361061004b5763ffffffff7c010000000000000000000000000000000000000000000000000000000060003504166390b98a118114610050578063f8b2cb4f14610095575b600080fd5b34801561005c57600080fd5b5061008173ffffffffffffffffffffffffffffffffffffffff600435166024356100d5565b604080519115158252519081900360200190f35b3480156100a157600080fd5b506100c373ffffffffffffffffffffffffffffffffffffffff6004351661016e565b60408051918252519081900360200190f35b336000908152602081905260408120548211156100f457506000610168565b336000818152602081815260408083208054879003905573ffffffffffffffffffffffffffffffffffffffff871680845292819020805487019055805186815290519293927fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef929181900390910190a35060015b92915050565b73ffffffffffffffffffffffffffffffffffffffff16600090815260208190526040902054905600a165627a7a72305820000313ec0ebbff4ffefbe79d615d0ab019d8566100c40eb95a4eee617a87d1090029"


suite "Contracts":
  setup:
    var web3: Web3
    var accounts: seq[Address]

    proc asyncsetup {.async.} =
      web3 = await newWeb3("ws://127.0.0.1:8545/")
      accounts = await web3.provider.eth_accounts()
      echo "accounts: ", accounts
      web3.defaultAccount = accounts[0]
    waitFor asyncsetup()

  teardown:
    proc asyncteardown {.async.} =
      await web3.close()
    waitFor asyncteardown()

  test "encoding test":
    proc asynctest {.async.} =
      let
        receipt = await web3.deployContract(EncodingTestCode)
        cc = receipt.contractAddress.get
      echo "Deployed EncodingTest contract: ", cc

      let ns = web3.contractSender(EncodingTest, cc)

      var b = await ns.getBool().call()
      assert(b == Bool.parse(false))

      echo "setBool: ", await ns.setBool(Bool.parse(true)).send()

      b = await ns.getBool().call()
      assert(b == Bool.parse(true))
    waitFor asynctest()

  test "number storage":
    proc asynctest {.async.} =
      let
        receipt = await web3.deployContract(NumberStorageCode)
        cc = receipt.contractAddress.get
      echo "Deployed NumberStorage contract: ", cc

      let ns = web3.contractSender(NumberStorage, cc)

      echo "setnumber: ", await ns.setNumber(5.u256).send()

      let n = await ns.getNumber().call()
      assert(n == 5.u256)

    waitFor asynctest()

  test "metacoin":
    proc asynctest {.async.} =
      let
        receipt = await web3.deployContract(MetaCoinCode)
        cc = receipt.contractAddress.get

      var deployedAtBlock: uint64
      discard parseHex(receipt.blockNumber, deployedAtBlock)
      echo "Deployed MetaCoin contract: ", cc, " at block ", deployedAtBlock

      let ns = web3.contractSender(MetaCoin, cc)

      let notifFut = newFuture[void]()
      var notificationsReceived = 0

      let s = await ns.subscribe(Transfer) do (
          fromAddr, toAddr: Address, value: UInt256)
          {.raises: [Defect], gcsafe.}:
        try:
          echo "onTransfer: ", fromAddr, " transferred ", value, " to ", toAddr
          inc notificationsReceived
          assert(fromAddr == web3.defaultAccount)
          assert((notificationsReceived == 1 and value == 50.u256) or
                  (notificationsReceived == 2 and value == 100.u256))
          if notificationsReceived == 2:
            notifFut.complete()
        except Exception as err:
          # chronos still raises exceptions which inherit directly from Exception
          doAssert false, err.msg

      echo "getbalance (now): ", await ns.getBalance(web3.defaultAccount).call()
      echo "getbalance (after creation): ", await ns.getBalance(web3.defaultAccount).call(blockNumber = deployedAtBlock)

      # Let's try to get the balance at a point in time where the contract was not deployed yet:
      try:
        echo "getbalance (first block): ", await ns.getBalance(web3.defaultAccount).call(blockNumber = 1'u64)
      except CatchableError as err:
        echo "getbalance (first block): ", err.msg

      echo "sendCoin: ", await ns.sendCoin(accounts[1], 50.u256).send()

      let newBalance1 = await ns.getBalance(web3.defaultAccount).call()
      assert(newBalance1 == 9950.u256)

      let newBalance2 = await ns.getBalance(accounts[1]).call()
      assert(newBalance2 == 50.u256)

      echo "sendCoin: ", await ns.sendCoin(accounts[1], 100.u256).send()

      echo "transfers: ", await ns.getJsonLogs(
        Transfer,
        fromBlock = some(blockId(deployedAtBlock)),
        toBlock = some(blockId(1000'u64)))

      await notifFut
      await s.unsubscribe()

    waitFor asynctest()
