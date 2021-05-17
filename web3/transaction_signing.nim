import
  options,
  ethtypes, stew/byteutils, stint,
  eth/[common, keys, rlp], eth/common/transaction

proc signTransaction(tr: var LegacyTx, pk: PrivateKey) =
  let h = tr.txHashNoSignature
  let s = sign(pk, SkMessage(h.data))

  var r = toRaw(s)
  let v = r[64]

  tr.R = fromBytesBE(UInt256, r.toOpenArray(0, 31))
  tr.S = fromBytesBE(UInt256, r.toOpenArray(32, 63))

  tr.V = int64(v) + 27 # TODO! Complete this

proc encodeTransaction*(s: EthSend, pk: PrivateKey): string =
  var tr: LegacyTx
  tr.gasLimit = GasInt(s.gas.get.uint64)
  tr.gasPrice = s.gasPrice.get
  if s.to.isSome:
    tr.to = EthAddress(s.to.get)
  else:
    tr.isContractCreation = true

  if s.value.isSome:
    tr.value = s.value.get
  tr.nonce = uint64(s.nonce.get)
  # TODO: The following is a misdesign indication.
  # All the encodings should be done into seq[byte], not a hex string.
  if s.data.len != 0:
    tr.payload = hexToSeqByte(s.data)
  signTransaction(tr, pk)
  return rlp.encode(tr).toHex
