# nim-web3
# Copyright (c) 2019-2023 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  options,
  eth_api_types, stew/byteutils, stint,
  eth/[common, keys, rlp], eth/common/transaction

func signTransaction(tr: var Transaction, pk: PrivateKey) =
  let h = tr.txHashNoSignature
  let s = sign(pk, SkMessage(h.data))

  var r = toRaw(s)
  let v = r[64]

  tr.R = fromBytesBE(UInt256, r.toOpenArray(0, 31))
  tr.S = fromBytesBE(UInt256, r.toOpenArray(32, 63))

  tr.V = int64(v) + 27 # TODO! Complete this

func encodeTransaction*(s: EthSend, pk: PrivateKey): seq[byte] =
  var tr = Transaction(txType: TxLegacy)
  tr.gasLimit = GasInt(s.gas.get.uint64)
  tr.gasPrice = s.gasPrice.get.GasInt
  if s.to.isSome:
    tr.to = some(EthAddress(s.to.get))

  if s.value.isSome:
    tr.value = s.value.get
  tr.nonce = uint64(s.nonce.get)
  tr.payload = s.data
  signTransaction(tr, pk)
  return rlp.encode(tr)
