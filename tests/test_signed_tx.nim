import ../web3
import chronos, options, json, stint, eth/keys
import test_utils

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
  proc setNumber(number: Uint256)
  proc getNumber(): Uint256 {.view.}

const NumberStorageCode = "6060604052341561000f57600080fd5b60bb8061001d6000396000f30060606040526004361060485763ffffffff7c01000000000000000000000000000000000000000000000000000000006000350416633fb5c1cb8114604d578063f2c9ecd8146062575b600080fd5b3415605757600080fd5b60606004356084565b005b3415606c57600080fd5b60726089565b60405190815260200160405180910390f35b600055565b600054905600a165627a7a7230582023e722f35009f12d5698a4ab22fb9d55a6c0f479fc43875c65be46fbdd8db4310029"

proc test() {.async.} =
  let theRNG = newRng()

  let web3 = await newWeb3("ws://127.0.0.1:8545/")
  let accounts = await web3.provider.eth_accounts()
  web3.defaultAccount = accounts[0]

  let pk = PrivateKey.random(theRNG[])
  let acc = Address(toCanonicalAddress(pk.toPublicKey()))

  var tx: EthSend
  tx.source = accounts[0]
  tx.value = some(ethToWei(10.u256))
  tx.to = some(acc)

  # Send 10 eth to acc
  discard await web3.send(tx)
  var balance = await web3.provider.eth_getBalance(acc, "latest")
  assert(balance == ethToWei(10.u256))

  # Send 5 eth back
  web3.privateKey = some(pk)
  tx.value = some(ethToWei(5.u256))
  tx.to = some(accounts[0])
  tx.gas = some(Quantity(3000000))
  tx.gasPrice = some(0)

  discard await web3.send(tx)
  balance = await web3.provider.eth_getBalance(acc, "latest")
  assert(balance == ethToWei(5.u256))

  # Creating the contract with a signed tx
  let receipt = await web3.deployContract(NumberStorageCode, gasPrice = 1)
  let contractAddress = receipt.contractAddress.get
  balance = await web3.provider.eth_getBalance(acc, "latest")
  assert(balance < ethToWei(5.u256))

  let c = web3.contractSender(NumberStorage, contractAddress)
  # Calling a methof with a signed tx
  discard await c.setNumber(5.u256).send()

  let n = await c.getNumber().call()
  assert(n == 5.u256)
  await web3.close()

waitFor test()
