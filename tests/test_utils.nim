import ../web3, chronos, options, json_rpc/rpcclient
import ../web3/[ethtypes]


proc deployContract*(web3: Web3, code: string): Future[Address] {.async.} =
  let provider = web3.provider
  let accounts = await provider.eth_accounts()

  var code = code
  if code[1] notin {'x', 'X'}:
    code = "0x" & code
  var tr: EthSend
  tr.source = accounts[0]
  tr.data = code
  tr.gas = Quantity(3000000).some
  let r = await provider.eth_sendTransaction(tr)
  let receipt = await provider.eth_getTransactionReceipt(r)
  result = receipt.contractAddress.get
  