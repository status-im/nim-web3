# nim-web3
# Copyright (c) 2018-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/json,
  pkg/unittest2,
  chronos, stint,
  results,
  ../web3,
  ./helpers/utils

type
  Data1 = object
    a: UInt256
    data: seq[byte]

contract(EncodingTest):
  proc setBool(val: bool)
  proc getBool(): bool {.view.}
  proc setString(a: string)
  proc getString(): string {.view.}
  proc setData1(a: UInt256, d: seq[byte])
  proc getData1(): Data1 {.view.}
  proc getManyData1(): seq[Data1] {.view.}

const EncodingTestCode =  "0x6000805460ff1916815560a0604052608090815260019061002090826100d2565b5034801561002d57600080fd5b50610191565b634e487b7160e01b600052604160045260246000fd5b600181811c9082168061005d57607f821691505b60208210810361007d57634e487b7160e01b600052602260045260246000fd5b50919050565b601f8211156100cd57600081815260208120601f850160051c810160208610156100aa5750805b601f850160051c820191505b818110156100c9578281556001016100b6565b5050505b505050565b81516001600160401b038111156100eb576100eb610033565b6100ff816100f98454610049565b84610083565b602080601f831160018114610134576000841561011c5750858301515b600019600386901b1c1916600185901b1785556100c9565b600085815260208120601f198616915b8281101561016357888601518255948401946001909101908401610144565b50858210156101815787850151600019600388901b60f8161c191681555b5050505050600190811b01905550565b610a27806101a06000396000f3fe608060405234801561001057600080fd5b506004361061007d5760003560e01c80637fcaf6661161005b5780637fcaf666146100f157806389ea642f146101045780639944cc71146101195780639fd159e61461012e57600080fd5b806312a7b914146100825780631cb3eebe1461009d5780631e26fd33146100b2575b600080fd5b60005460ff1660405190151581526020015b60405180910390f35b6100b06100ab36600461047e565b610143565b005b6100b06100c03660046104ca565b600080547fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff0016911515919091179055565b6100b06100ff3660046104f3565b6101ad565b61010c6101bf565b6040516100949190610599565b610121610251565b60405161009491906105d3565b610136610310565b60405161009491906105e6565b604051806040016040528084815260200183838080601f01602080910402602001604051908101604052809392919081815260200183838082843760009201919091525050509152508051600290815560208201516003906101a5908261072e565b505050505050565b60016101ba828483610848565b505050565b6060600180546101ce90610695565b80601f01602080910402602001604051908101604052809291908181526020018280546101fa90610695565b80156102475780601f1061021c57610100808354040283529160200191610247565b820191906000526020600020905b81548152906001019060200180831161022a57829003601f168201915b5050505050905090565b604080518082019091526000815260606020820152604080518082019091526002805482526003805460208401919061028990610695565b80601f01602080910402602001604051908101604052809291908181526020018280546102b590610695565b80156103025780601f106102d757610100808354040283529160200191610302565b820191906000526020600020905b8154815290600101906020018083116102e557829003601f168201915b505050505081525050905090565b60408051600380825260808201909252606091816020015b60408051808201909152600081526060602082015281526020019060019003908161032857905050905060005b815181101561043157604080518082019091526002805482526003805460208401919061038190610695565b80601f01602080910402602001604051908101604052809291908181526020018280546103ad90610695565b80156103fa5780601f106103cf576101008083540402835291602001916103fa565b820191906000526020600020905b8154815290600101906020018083116103dd57829003601f168201915b50505050508152505082828151811061041557610415610963565b60200260200101819052508061042a90610992565b9050610355565b5090565b60008083601f84011261044757600080fd5b50813567ffffffffffffffff81111561045f57600080fd5b60208301915083602082850101111561047757600080fd5b9250929050565b60008060006040848603121561049357600080fd5b83359250602084013567ffffffffffffffff8111156104b157600080fd5b6104bd86828701610435565b9497909650939450505050565b6000602082840312156104dc57600080fd5b813580151581146104ec57600080fd5b9392505050565b6000806020838503121561050657600080fd5b823567ffffffffffffffff81111561051d57600080fd5b61052985828601610435565b90969095509350505050565b6000815180845260005b8181101561055b5760208185018101518683018201520161053f565b5060006020828601015260207fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0601f83011685010191505092915050565b6020815260006104ec6020830184610535565b8051825260006020820151604060208501526105cb6040850182610535565b949350505050565b6020815260006104ec60208301846105ac565b6000602080830181845280855180835260408601915060408160051b870101925083870160005b82811015610659577fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffc08886030184526106478583516105ac565b9450928501929085019060010161060d565b5092979650505050505050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052604160045260246000fd5b600181811c908216806106a957607f821691505b6020821081036106e2577f4e487b7100000000000000000000000000000000000000000000000000000000600052602260045260246000fd5b50919050565b601f8211156101ba57600081815260208120601f850160051c8101602086101561070f5750805b601f850160051c820191505b818110156101a55782815560010161071b565b815167ffffffffffffffff81111561074857610748610666565b61075c816107568454610695565b846106e8565b602080601f8311600181146107af57600084156107795750858301515b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff600386901b1c1916600185901b1785556101a5565b6000858152602081207fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe08616915b828110156107fc578886015182559484019460019091019084016107dd565b508582101561083857878501517fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff600388901b60f8161c191681555b5050505050600190811b01905550565b67ffffffffffffffff83111561086057610860610666565b6108748361086e8354610695565b836106e8565b6000601f8411600181146108c657600085156108905750838201355b7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff600387901b1c1916600186901b17835561095c565b6000838152602090207fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe0861690835b8281101561091557868501358255602094850194600190920191016108f5565b5086821015610950577fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff60f88860031b161c19848701351681555b505060018560011b0183555b5050505050565b7f4e487b7100000000000000000000000000000000000000000000000000000000600052603260045260246000fd5b60007fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff82036109ea577f4e487b7100000000000000000000000000000000000000000000000000000000600052601160045260246000fd5b506001019056fea26469706673582212205dbf820dba2d3dea0502a6521ca26db2e50cf5819a87cc8518ad67dbd8091e3664736f6c63430008130033"

#[ Contract EncodingTest
pragma solidity ^0.8.0;

contract EncodingTest {
    bool boolVal = false;
    string stringVal = "";

    struct Data1 {
        uint a;
        bytes data;
    }

    Data1 data1;

    function setBool(bool _boolVal) public {
        boolVal = _boolVal;
    }

    function getBool() public view returns (bool) {
        return boolVal;
    }

    function setString(string calldata a) public {
        stringVal = a;
    }

    function getString() public view returns (string memory) {
        return stringVal;
    }

    function setData1(uint a, bytes calldata data) public {
        data1 = Data1(a, data);
    }

    function getData1() public view returns(Data1 memory) {
        return data1;
    }

    function getManyData1() public view returns(Data1[] memory result) {
        result = new Data1[](3);
        for (uint i = 0; i < result.length; ++i) {
            result[i] = data1;
        }
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
  proc sendCoin(receiver: Address, amount: UInt256): bool
  proc getBalance(address: Address): UInt256 {.view.}
  proc Transfer(fromAddr, toAddr: indexed[Address], value: UInt256) {.event.}
  proc BlaBla(fromAddr: indexed[Address]) {.event.}

const MetaCoinCode = "608060405234801561001057600080fd5b5032600090815260208190526040902061271090556101c2806100346000396000f30060806040526004361061004b5763ffffffff7c010000000000000000000000000000000000000000000000000000000060003504166390b98a118114610050578063f8b2cb4f14610095575b600080fd5b34801561005c57600080fd5b5061008173ffffffffffffffffffffffffffffffffffffffff600435166024356100d5565b604080519115158252519081900360200190f35b3480156100a157600080fd5b506100c373ffffffffffffffffffffffffffffffffffffffff6004351661016e565b60408051918252519081900360200190f35b336000908152602081905260408120548211156100f457506000610168565b336000818152602081815260408083208054879003905573ffffffffffffffffffffffffffffffffffffffff871680845292819020805487019055805186815290519293927fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef929181900390910190a35060015b92915050565b73ffffffffffffffffffffffffffffffffffffffff16600090815260208190526040902054905600a165627a7a72305820000313ec0ebbff4ffefbe79d615d0ab019d8566100c40eb95a4eee617a87d1090029"

proc `$`(list: seq[Address]): string =
  result.add '['
  for x in list:
    result.add $x
    result.add ", "
  result.add ']'

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
    proc asynctest {.async: (raises: [CancelledError, Exception]).} =
      let
        receipt = await web3.deployContract(EncodingTestCode)
        cc = receipt.contractAddress.get
      echo "Deployed EncodingTest contract: ", cc

      let ns = web3.contractInstance(EncodingTest, cc)

      var b = await ns.getBool()
      assert(b == false)
      await ns.setBool(true)
      b = await ns.getBool()
      assert(b == true)

      var s = await ns.getString()
      assert(s == "")
      await ns.setString("hello")
      s = await ns.getString()
      assert(s == "hello")

      let data1data = @[1.byte, 2, 3, 4, 5]
      await ns.setData1(123.u256, data1data)

      let data1 = await ns.getData1()
      assert(data1.a == 123.u256)
      assert(data1.data == data1data)

      let manyData1 = await ns.getManyData1()
      assert(manyData1.len == 3)
      for i in 0 .. manyData1.high:
        assert(manyData1[i].a == 123.u256)
        assert(manyData1[i].data == data1data)

    waitFor asynctest()

  test "number storage":
    proc asynctest {.async: (raises: [CancelledError, Exception]).} =
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
    proc asynctest {.async: (raises: [CancelledError, Exception]).} =
      let
        receipt = await web3.deployContract(MetaCoinCode)
        cc = receipt.contractAddress.get

      let deployedAtBlock = receipt.blockNumber
      echo "Deployed MetaCoin contract: ", cc, " at block ",
        distinctBase(deployedAtBlock)

      let ns = web3.contractSender(MetaCoin, cc)

      let notifFut = newFuture[void]()
      var notificationsReceived = 0

      let s = await ns.subscribe(Transfer) do (
          fromAddr, toAddr: Address, value: UInt256)
          {.raises: [], gcsafe.}:
        try:
          echo "onTransfer: ", fromAddr, " transferred ", value.toHex,
            " to ", toAddr
          inc notificationsReceived
          assert(fromAddr == web3.defaultAccount)
          assert((notificationsReceived == 1 and value == 50.u256) or
                  (notificationsReceived == 2 and value == 100.u256))
          if notificationsReceived == 2:
            notifFut.complete()
        except Exception as err:
          # chronos still raises exceptions which inherit directly from Exception
          doAssert false, err.msg

      let balNow = await ns.getBalance(web3.defaultAccount).call()
      echo "getbalance (now): ", balNow.toHex
      let balNew = await ns.getBalance(web3.defaultAccount).call(
        blockNumber = deployedAtBlock)
      echo "getbalance (after creation): ", balNew.toHex

      # Let's try to get the balance at a point in time where the contract
      # was not deployed yet:
      try:
        let balFirst = await ns.getBalance(web3.defaultAccount).call(
          blockNumber = 1.Quantity)
        echo "getbalance (first block): ", balFirst.toHex
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
        fromBlock = Opt.some(blockId(deployedAtBlock)),
        toBlock = Opt.some(blockId(1000)))

      await notifFut
      await s.unsubscribe()

    waitFor asynctest()
