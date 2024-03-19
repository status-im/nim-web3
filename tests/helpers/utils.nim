import
  std/options,
  chronos,
  stew/byteutils,
  ../../web3,
  ../../web3/primitives

proc deployContract*(web3: Web3, code: string, gasPrice = 0): Future[ReceiptObject] {.async.} =
  var code = code
  var tr: TransactionArgs
  tr.`from` = some(web3.defaultAccount)
  tr.data = some(hexToSeqByte(code))
  tr.gas = Quantity(3000000).some
  if gasPrice != 0:
    tr.gasPrice = some(gasPrice.Quantity)

  let r = await web3.send(tr)
  return await web3.getMinedTransactionReceipt(r)
