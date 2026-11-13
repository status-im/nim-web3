import
  results,
  chronos,
  stint,
  stew/byteutils,
  ../../web3,
  ../../web3/primitives

export
  stint

proc deployContract*(web3: Web3, code: string, gasPrice: UInt256 = 0.u256): Future[ReceiptObject] {.async.} =
  var code = code
  var tr: TransactionArgs
  tr.`from` = Opt.some(web3.defaultAccount)
  tr.data = Opt.some(hexToSeqByte(code))
  tr.gas = Opt.some Quantity(3000000)
  if gasPrice != 0:
    tr.gasPrice = Opt.some(gasPrice)

  let r = await web3.send(tr)
  return await web3.getMinedTransactionReceipt(r)
