# nim-web3
# Copyright (c) 2019-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  eth_api_types,
  eth/common/[keys, transactions_rlp, transaction_utils]

func encodeTransaction*(s: TransactionArgs, pk: PrivateKey): seq[byte] =
  var tr = Transaction(txType: TxLegacy)
  tr.gasLimit = s.gas.get.GasInt
  tr.gasPrice = s.gasPrice.get.GasInt
  tr.to = s.to

  if s.value.isSome:
    tr.value = s.value.get
  tr.nonce = uint64(s.nonce.get)
  tr.payload = s.payload
  tr.signature =
    if s.chainId.isSome():
      tr.chainId = ChainId(s.chainId.get)
      tr.sign(pk, true)
    else:
      tr.sign(pk, false)
  rlp.encode(tr)

func encodeTransaction*(s: TransactionArgs, pk: PrivateKey, chainId: ChainId): seq[byte] {.deprecated: "Provide chainId in TransactionArgs".} =
  var tr = Transaction(txType: TxLegacy, chainId: chainId)
  tr.gasLimit = s.gas.get.GasInt
  tr.gasPrice = s.gasPrice.get.GasInt
  tr.to = s.to

  if s.value.isSome:
    tr.value = s.value.get
  tr.nonce = uint64(s.nonce.get)
  tr.payload = s.payload
  tr.signature = tr.sign(pk, true)
  rlp.encode(tr)
