import
  std/options,
  chronos, stint,
  stew/byteutils,
  ../../web3,
  ../../web3/primitives

proc deployContract*(web3: Web3, code: string, gasPrice = 0): Future[ReceiptObject] {.async.} =
  let provider = web3.provider
  let accounts = await provider.eth_accounts()

  var code = code
  var tr: EthSend
  tr.`from` = web3.defaultAccount
  tr.data = hexToSeqByte(code)
  tr.gas = Quantity(3000000).some
  if gasPrice != 0:
    tr.gasPrice = some(gasPrice.Quantity)

  let r = await web3.send(tr)
  return await web3.getMinedTransactionReceipt(r)

func ethToWei*(eth: UInt256): UInt256 =
  eth * 1000000000000000000.u256

type
  BlobData* = DynamicBytes[0, 512]

func conv*(T: type, x: int): T =
  type BaseType = distinctBase T
  var res: BaseType
  when BaseType is seq:
    res.setLen(1)
  res[^1] = x.byte
  T(res)

func address*(x: int): Address =
  conv(typeof result, x)

func txhash*(x: int): TxHash =
  conv(typeof result, x)

func blob*(x: int): BlobData =
  conv(typeof result, x)

func h256*(x: int): Hash256 =
  conv(typeof result, x)
