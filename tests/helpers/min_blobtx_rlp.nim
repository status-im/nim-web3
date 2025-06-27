{.push raises: [].}

import
  eth/common/transactions_rlp {.all.}

type
  # Pretend to be a PooledTransaction
  # for testing purpose
  BlobTransaction* = object
    tx*: Transaction

proc readTxTyped(rlp: var Rlp, tx: var BlobTransaction) {.raises: [RlpError].} =
  let
    txType = rlp.readTxType()
    numFields =
      if txType == TxEip4844:
        rlp.listLen
      else:
        1
  if numFields == 4 or numFields == 5:
    rlp.tryEnterList() # spec: rlp([tx_payload, blobs, commitments, proofs])
  rlp.readTxPayload(tx.tx, txType)
  # ignore BlobBundle

proc read*(rlp: var Rlp, T: type BlobTransaction): T {.raises: [RlpError].} =
  if rlp.isList:
    rlp.readTxLegacy(result.tx)
  else:
    rlp.readTxTyped(result)
