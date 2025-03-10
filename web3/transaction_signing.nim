# nim-web3
# Copyright (c) 2019-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  eth_api_types,
  eth/common/[keys, transactions_rlp, transaction_utils]

func encodeTransactionLegacy(s: TransactionArgs, pk: PrivateKey): seq[byte] =
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
      tr.chainId = s.chainId.get
      tr.sign(pk, true)
    else:
      tr.sign(pk, false)
  rlp.encode(tr)

func encodeTransactionEip2930(s: TransactionArgs, pk: PrivateKey): seq[byte] =
  var tr = Transaction(txType: TxEip2930)
  tr.gasLimit = s.gas.get.GasInt
  tr.gasPrice = s.gasPrice.get.GasInt
  tr.to = s.to
  if s.value.isSome:
    tr.value = s.value.get
  tr.nonce = uint64(s.nonce.get)
  tr.payload = s.payload
  tr.chainId = s.chainId.get
  tr.signature = tr.sign(pk, true)
  tr.accessList = s.accessList.get
  rlp.encode(tr)

func encodeTransactionEip1559(s: TransactionArgs, pk: PrivateKey): seq[byte] =
  var tr = Transaction(txType: TxEip1559)
  tr.gasLimit = s.gas.get.GasInt
  tr.maxPriorityFeePerGas = s.maxPriorityFeePerGas.get.GasInt
  tr.maxFeePerGas = s.maxFeePerGas.get.GasInt
  tr.to = s.to
  if s.value.isSome:
    tr.value = s.value.get
  tr.nonce = uint64(s.nonce.get)
  tr.payload = s.payload
  tr.chainId = s.chainId.get
  tr.signature = tr.sign(pk, true)
  if s.accessList.isSome:
    tr.accessList = s.accessList.get
  rlp.encode(tr)

func encodeTransactionEip4844(s: TransactionArgs, pk: PrivateKey): seq[byte] =
  var tr = Transaction(txType: TxEip4844)
  tr.gasLimit = s.gas.get.GasInt
  tr.maxPriorityFeePerGas = s.maxPriorityFeePerGas.get.GasInt
  tr.maxFeePerGas = s.maxFeePerGas.get.GasInt
  tr.to = s.to
  if s.value.isSome:
    tr.value = s.value.get
  tr.nonce = uint64(s.nonce.get)
  tr.payload = s.payload
  tr.chainId = s.chainId.get
  tr.signature = tr.sign(pk, true)
  if s.accessList.isSome:
    tr.accessList = s.accessList.get
  tr.maxFeePerBlobGas = s.maxFeePerBlobGas.get
  tr.versionedHashes = s.blobVersionedHashes.get
  rlp.encode(tr)

func encodeTransactionEip7702(s: TransactionArgs, pk: PrivateKey): seq[byte] =
  var tr = Transaction(txType: TxEip7702)
  tr.gasLimit = s.gas.get.GasInt
  tr.maxPriorityFeePerGas = s.maxPriorityFeePerGas.get.GasInt
  tr.maxFeePerGas = s.maxFeePerGas.get.GasInt
  tr.to = s.to
  if s.value.isSome:
    tr.value = s.value.get
  tr.nonce = uint64(s.nonce.get)
  tr.payload = s.payload
  tr.chainId = s.chainId.get
  tr.signature = tr.sign(pk, true)
  if s.accessList.isSome:
    tr.accessList = s.accessList.get
  tr.authorizationList = s.authorizationList.get
  rlp.encode(tr)

func encodeTransaction*(s: TransactionArgs, pk: PrivateKey, txType: TxType): seq[byte] =
  case txType
  of TxLegacy:
    encodeTransactionLegacy(s, pk)
  of TxEip2930:
    encodeTransactionEip2930(s, pk)
  of TxEip1559:
    encodeTransactionEip1559(s, pk)
  of TxEip4844:
    encodeTransactionEip4844(s, pk)
  of TxEip7702:
    encodeTransactionEip7702(s, pk)

func txType(s: TransactionArgs): TxType =
  if s.authorizationList.isSome:
    return TxEip7702
  if s.blobVersionedHashes.isSome:
    return TxEip4844
  if s.gasPrice.isNone:
    return TxEip1559
  if s.accessList.isSome:
    return TxEip2930
  TxLegacy

func encodeTransaction*(s: TransactionArgs, pk: PrivateKey): seq[byte] =
  encodeTransaction(s, pk, s.txType)

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
