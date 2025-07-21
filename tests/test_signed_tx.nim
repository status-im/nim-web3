# nim-web3
# Copyright (c) 2018-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  pkg/unittest2,
  chronos, stint,
  results,
  eth/common/keys,
  stew/byteutils,
  json_rpc/client,
  ../web3,
  ../web3/transaction_signing,
  ./helpers/utils,
  ./helpers/primitives_utils

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

type Address = web3.Address

contract(NumberStorage):
  proc setNumber(number: UInt256)
  proc getNumber(): UInt256 {.view.}

const NumberStorageCode = "6060604052341561000f57600080fd5b60bb8061001d6000396000f30060606040526004361060485763ffffffff7c01000000000000000000000000000000000000000000000000000000006000350416633fb5c1cb8114604d578063f2c9ecd8146062575b600080fd5b3415605757600080fd5b60606004356084565b005b3415606c57600080fd5b60726089565b60405190815260200160405180910390f35b600055565b600054905600a165627a7a7230582023e722f35009f12d5698a4ab22fb9d55a6c0f479fc43875c65be46fbdd8db4310029"

suite "Signed transactions":
  test "encodeTransaction(Transaction, PrivateKey, ChainId) EIP-155 test vector":
    let
      privateKey = PrivateKey.fromHex("0x4646464646464646464646464646464646464646464646464646464646464646").tryGet()
      publicKey = privateKey.toPublicKey()
      address = publicKey.toCanonicalAddress()
    var tx: TransactionArgs
    tx.nonce = Opt.some(Quantity(9))
    tx.`from` = Opt.some(Address(address))
    tx.value = Opt.some(1000000000000000000.u256)
    tx.to = Opt.some(address"0x3535353535353535353535353535353535353535")
    tx.gas = Opt.some(Quantity(21000'u64))
    tx.gasPrice = Opt.some(Quantity(20000000000'i64))

    let txBytes = encodeTransaction(tx, privateKey, 1.u256)
    let txHex = "0x" & txBytes.toHex
    check txHex == "0xf86c098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83"

  test "encodeTransaction(Transaction, PrivateKey, TxType) EIP-155 test vector":
    let
      privateKey = PrivateKey.fromHex("0x4646464646464646464646464646464646464646464646464646464646464646").tryGet()
      publicKey = privateKey.toPublicKey()
      address = publicKey.toCanonicalAddress()
    var tx: TransactionArgs
    tx.nonce = Opt.some(Quantity(9))
    tx.`from` = Opt.some(Address(address))
    tx.value = Opt.some(1000000000000000000.u256)
    tx.to = Opt.some(address"0x3535353535353535353535353535353535353535")
    tx.gas = Opt.some(Quantity(21000'u64))
    tx.gasPrice = Opt.some(Quantity(20000000000'i64))
    tx.chainId = Opt.some(1.u256)

    let txBytes = encodeTransaction(tx, privateKey)
    let txHex = "0x" & txBytes.toHex
    check txHex == "0xf86c098504a817c800825208943535353535353535353535353535353535353535880de0b6b3a76400008025a028ef61340bd939bc2195fe537567866003e1a15d3c71ff63e1590620aa636276a067cbe9d8997f761aecb703304b3800ccf555c9f3dc64214b297fb1966a3b6d83"

  # testcase is taken from ethers.js: https://github.com/ethers-io/ethers.js/tree/f5336c19b1adcb5e992745b8a0561eaf8f1f1138/testcases
  test "encodeTransaction(Transaction, PrivateKey, TxType) EIP-2930":
    let
      privateKey = PrivateKey.fromHex("0x2bf558dce44ca98616ee629199215ae5401c97040664637c48e3b74e66bcb3ae").tryGet()
      publicKey = privateKey.toPublicKey()
      address = publicKey.toCanonicalAddress()
    var tx: TransactionArgs
    tx.nonce = Opt.some(Quantity(648))
    tx.`from` = Opt.some(Address(address))
    tx.value = Opt.some(51284.u256)
    tx.to = Opt.some(address"0x6Eb893e3466931517a04a17D153a6330c3f2f1dD")
    tx.gas = Opt.some(Quantity(157'u64))
    tx.gasPrice = Opt.some(Quantity(9086'u64))
    tx.chainId = Opt.some(2214903583.u256)
    tx.data = Opt.some(hexToSeqByte("0x889e365e59664fb881554ba1175519b5195b1d20390beb806d8f2cda7893e6f79848195dba4c905db6d7257ffb5eefea35f18ae33c"))
    tx.accessList = Opt.some(newSeq[AccessPair]())

    let txBytes = encodeTransaction(tx, privateKey)
    let txHex = "0x" & txBytes.toHex
    check txHex == "0x01f89f848404bf1f82028882237e819d946eb893e3466931517a04a17d153a6330c3f2f1dd82c854b5889e365e59664fb881554ba1175519b5195b1d20390beb806d8f2cda7893e6f79848195dba4c905db6d7257ffb5eefea35f18ae33cc080a0775f29642af1045b40e5beae8e6bce2dc9e222023b7a50372be6824dbb7434fba05dacfff85752a0b9fd860bc751c17235a670d318a8b9494d664c1b87e33ac8dd"

  # testcase is taken from ethers.js: https://github.com/ethers-io/ethers.js/tree/f5336c19b1adcb5e992745b8a0561eaf8f1f1138/testcases
  test "encodeTransaction(Transaction, PrivateKey, TxType) EIP-1559":
    let
      privateKey = PrivateKey.fromHex("0x2bf558dce44ca98616ee629199215ae5401c97040664637c48e3b74e66bcb3ae").tryGet()
      publicKey = privateKey.toPublicKey()
      address = publicKey.toCanonicalAddress()
    var tx: TransactionArgs
    tx.nonce = Opt.some(Quantity(648))
    tx.`from` = Opt.some(Address(address))
    tx.value = Opt.some(51284.u256)
    tx.to = Opt.some(address"0x6Eb893e3466931517a04a17D153a6330c3f2f1dD")
    tx.gas = Opt.some(Quantity(157'u64))
    tx.maxFeePerGas = Opt.some(Quantity(879596102'u64))
    tx.maxPriorityFeePerGas = Opt.some(Quantity(2915939'u64))
    tx.chainId = Opt.some(2214903583.u256)
    tx.data = Opt.some(hexToSeqByte("0x889e365e59664fb881554ba1175519b5195b1d20390beb806d8f2cda7893e6f79848195dba4c905db6d7257ffb5eefea35f18ae33c"))
    tx.accessList = Opt.some(newSeq[AccessPair]())

    let txBytes = encodeTransaction(tx, privateKey)
    let txHex = "0x" & txBytes.toHex
    check txHex == "0x02f8a5848404bf1f820288832c7e6384346d9246819d946eb893e3466931517a04a17d153a6330c3f2f1dd82c854b5889e365e59664fb881554ba1175519b5195b1d20390beb806d8f2cda7893e6f79848195dba4c905db6d7257ffb5eefea35f18ae33cc080a0f1003f96c6c6620dd46db36d2ae9f12d363947eb0db088c678b6ad1cf494aa6fa06085b5abbf448de5d622dc820da590cfdb6bb77b41c6650962b998a941f8d701"

  test "contract creation and method invocation":
    proc test() {.async: (raises: [CancelledError, Exception]).} =
      let theRNG = HmacDrbgContext.new()

      let web3 = await newWeb3("ws://127.0.0.1:8545/")
      let accounts = await web3.provider.eth_accounts()
      let gasPrice = await web3.provider.eth_gasPrice()
      web3.defaultAccount = accounts[0]

      let pk = PrivateKey.random(theRNG[])
      let acc = Address(toCanonicalAddress(pk.toPublicKey()))

      var tx: TransactionArgs
      tx.`from` = Opt.some(accounts[0])
      tx.value = Opt.some(ethToWei(10.u256))
      tx.to = Opt.some(acc)
      tx.gasPrice = Opt.some(gasPrice)

      # Send 10 eth to acc
      discard await web3.send(tx)
      var balance = await web3.provider.eth_getBalance(acc, "latest")
      assert(balance == ethToWei(10.u256))

      # Send 5 eth back
      web3.privateKey = Opt.some(pk)
      tx.value = Opt.some(ethToWei(5.u256))
      tx.to = Opt.some(accounts[0])
      tx.gas = Opt.some(Quantity(3000000))

      discard await web3.send(tx)
      balance = await web3.provider.eth_getBalance(acc, "latest")
      assert(balance in ethToWei(4.u256)..ethToWei(5.u256)) # 5 minus gas costs

      # Creating the contract with a signed tx
      let receipt = await web3.deployContract(NumberStorageCode, gasPrice = gasPrice.int)
      let contractAddress = receipt.contractAddress.get
      balance = await web3.provider.eth_getBalance(acc, "latest")
      assert(balance < ethToWei(5.u256))

      let c = web3.contractSender(NumberStorage, contractAddress)
      # Calling a methof with a signed tx
      discard await c.setNumber(5.u256).send(gasPrice = gasPrice.int)

      let n = await c.getNumber().call()
      assert(n == 5.u256)
      await web3.close()

    try:
      waitFor test()
    except CatchableError as err:
      echo "Failed to send signed tx", err.msg
      fail()
