import
  std/options,
  unittest2,
  chronos,
  stint,
  nimcrypto,
  ../web3,
  ./test_utils,
  ./encodingcontract

contract(EncodingTest):
  proc setBool(val: Bool)
  proc getBool(): Bool {.view.}
  proc mixedArguments(
    integer: UInt256,
    fixedbytes: FixedBytes[32],
    address: Address,
    dynamicbytes: DynamicBytes
  )
  proc MixedArguments(
    integer: UInt256,
    fixedbytes: FixedBytes[32],
    address: Address,
    dynamicbytes: DynamicBytes[0, int.high]
  ) {.event.}

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

  test "decodes dynamic and fixed arguments from an event":

    proc randomBytes(amount: static int): array[amount, byte] =
      doAssert randomBytes(result) == amount

    proc asynctest {.async.} =
      let
        receipt = await web3.deployContract(EncodingTestCode)
        cc = receipt.contractAddress.get

      let ns = web3.contractSender(EncodingTest, cc)

      let integer = UInt256.fromBytes(randomBytes(32))
      let fixedbytes = FixedBytes[32](randomBytes(32))
      let address = Address(randomBytes(20))
      let dynamicbytes = DynamicBytes[0, int.high](@(randomBytes(10)))

      var done = newFuture[void]()

      proc callback(eventInteger: UInt256,
                    eventFixedbytes: FixedBytes[32],
                    eventAddress: Address,
                    eventDynamicbytes: DynamicBytes[0, int.high]) {.gcsafe.} =
        check eventInteger == integer
        check eventFixedbytes == fixedbytes
        check eventAddress == address
        check eventDynamicbytes == dynamicbytes
        done.complete()

      let subscription = await ns.subscribe(MixedArguments, callback)

      discard await ns.mixedArguments(
        integer,
        fixedbytes,
        address,
        dynamicbytes
      ).send()

      await done
      await subscription.unsubscribe()

    waitFor asynctest()
