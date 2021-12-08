import std/options
import pkg/unittest2
import pkg/chronos
import pkg/stint
import ../web3
import ./test_utils
import ./encodingcontract

contract(EncodingTest):
  proc setBool(val: Bool)
  proc getBool(): Bool {.view.}
  proc mixedArguments(
    integer: UInt256,
    fixedbytes: FixedBytes[32],
    address: Address,
    dynamicbytes: DynamicBytes
  )

suite "ABI encoding":

  var web3: Web3
  var accounts: seq[Address]

  setup:
    proc asyncsetup {.async.} =
      web3 = await newWeb3("ws://127.0.0.1:8545/")
      accounts = await web3.provider.eth_accounts()
      web3.defaultAccount = accounts[0]
    waitFor asyncsetup()

  teardown:
    proc asyncteardown {.async.} =
      await web3.close()
    waitFor asyncteardown()

  test "encodes booleans":
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

  test "encodes dynamic and fixed arguments in a single call":
    proc asynctest {.async.} =
      let
        receipt = await web3.deployContract(EncodingTestCode)
        cc = receipt.contractAddress.get

      let ns = web3.contractSender(EncodingTest, cc)
      var arr: array[32, byte]
      var address: array[20, byte]
      var sequence: seq[byte]
      try:
        discard await ns.mixedArguments(
          0.u256,
          FixedBytes[32](arr),
          Address(address),
          DynamicBytes(sequence)
        ).send()
      except Exception as error:
        echo error.msg
        fail()

    waitFor asynctest()
