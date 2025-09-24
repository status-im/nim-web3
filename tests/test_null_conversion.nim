import
  std/[strutils],
  pkg/unittest2,
  stew/[byteutils],
  stint,
  ../web3/[conversions, eth_api_types, engine_api_types]

template should_be_value_error(input: seq[byte], value: untyped): void =
  expect SerializationError:
    value = JrpcConv.decode(input, typeof(value))
    echo $typeof(value)

template should_not_error(input: seq[byte], value: untyped): void =
  value = JrpcConv.decode(input, typeof(value))

var null = "0xF6".hexToSeqByte
var empty = newSeq[byte]()
var emptyStr = "0x60".hexToSeqByte # ""
var emptyHex = "0x623078".hexToSeqByte # "0x"
var badHex = "0x6330785F".hexToSeqByte # "0x_"

suite "Null conversion":
  var resAddress: Address
  var resDynamicBytes: DynamicBytes[32]
  var resFixedBytes: FixedBytes[5]
  var resQuantity: Quantity
  var resRlpEncodedBytes: RlpEncodedBytes
  var resTypedTransaction: TypedTransaction
  var resUInt256: UInt256
  var resUInt256Ref: ref UInt256

  ## Covers the converters which can be found in web3/conversions.nim
  ## Ensure that when passing a nully value they respond with a SerializationError
  test "passing null values to normal convertors":
    should_be_value_error(null, resAddress)
    should_be_value_error(null, resDynamicBytes)
    should_be_value_error(null, resFixedBytes)
    should_be_value_error(null, resQuantity)
    should_be_value_error(null, resRlpEncodedBytes)
    should_be_value_error(null, resTypedTransaction)
    should_be_value_error(null, resUInt256)
    should_not_error(null, resUInt256Ref)

  test "passing empty values to normal convertors":
    should_be_value_error(empty, resAddress)
    should_be_value_error(empty, resDynamicBytes)
    should_be_value_error(empty, resFixedBytes)
    should_be_value_error(empty, resQuantity)
    should_be_value_error(empty, resRlpEncodedBytes)
    should_be_value_error(empty, resTypedTransaction)
    should_be_value_error(empty, resUInt256)
    should_be_value_error(empty, resUInt256Ref)

  test "passing invalid hex (0x) values to normal convertors":
    should_be_value_error(emptyHex, resAddress)
    should_be_value_error(emptyHex, resDynamicBytes)
    should_be_value_error(emptyHex, resFixedBytes)
    should_be_value_error(emptyHex, resQuantity)
    should_be_value_error(emptyHex, resUInt256)
    should_be_value_error(emptyHex, resUInt256Ref)

  test "passing hex (0x) values to normal convertors":
    should_not_error(emptyHex, resRlpEncodedBytes)
    should_not_error(emptyHex, resTypedTransaction)

  test "passing malformed hex (0x_) values to normal convertors":
    should_be_value_error(badHex, resAddress)
    should_be_value_error(badHex, resDynamicBytes)
    should_be_value_error(badHex, resFixedBytes)
    should_be_value_error(badHex, resQuantity)
    should_be_value_error(badHex, resRlpEncodedBytes)
    should_be_value_error(badHex, resTypedTransaction)
    should_be_value_error(badHex, resUInt256)
    should_be_value_error(badHex, resUInt256Ref)

  ## Covering the web3/engine_api_types
  ##
  ## NOTE: These will be transformed by the JrpcConv imported from
  ##       nim-json-rpc/json_rpc/jsonmarshal
  test "passing nully values to specific convertors":
    type
      CborPayloadAttributesV1 = object
        timestamp, prevRandao, suggestedFeeRecipient: CborBytes
      CborForkchoiceStateV1 = object
        status, safeBlockHash, finalizedBlockHash: CborBytes
      CborForkchoiceUpdatedResponse = object
        payloadStatus, payloadId: CborBytes

    var resPayloadAttributesV1: PayloadAttributesV1
    var resForkchoiceStateV1: ForkchoiceStateV1
    var resForkchoiceUpdatedResponse: ForkchoiceUpdatedResponse

    for item in @[empty, emptyHex, emptyStr, badHex]:
      let cborItem = item.CborBytes
      should_be_value_error(CborPayloadAttributesV1(
        timestamp: cborItem, prevRandao: cborItem, suggestedFeeRecipient: cborItem
      ).toCbor(), resPayloadAttributesV1)
      should_be_value_error(CborForkchoiceStateV1(
        status: cborItem, safeBlockHash: cborItem, finalizedBlockHash: cborItem
      ).toCbor(), resForkchoiceStateV1)
      should_be_value_error(CborForkchoiceUpdatedResponse(
        payloadStatus: cborItem, payloadId: cborItem
      ).toCbor(), resForkchoiceUpdatedResponse)

    for item in @[null]:
      let cborItem = item.CborBytes
      should_not_error(CborPayloadAttributesV1(
        timestamp: cborItem, prevRandao: cborItem, suggestedFeeRecipient: cborItem
      ).toCbor(), resPayloadAttributesV1)
      should_not_error(CborForkchoiceStateV1(
        status: cborItem, safeBlockHash: cborItem, finalizedBlockHash: cborItem
      ).toCbor(), resForkchoiceStateV1)
      should_not_error(CborForkchoiceUpdatedResponse(
        payloadStatus: cborItem, payloadId: cborItem
      ).toCbor(), resForkchoiceUpdatedResponse)

  ## If different status types can have branching logic
  ## we should cover each status type with different null ops
  test "passing nully values to specific status types":
    type CborPayloadStatusV1 = object
      status: string
      latestValidHash, validationError: CborSimpleValue

    var resPayloadStatusV1: PayloadStatusV1

    for status_type in PayloadExecutionStatus:
      let val = CborPayloadStatusV1(
        status: $status_type,
        latestValidHash: cborNull,
        validationError: cborNull
      )
      should_not_error(val.toCbor(), resPayloadStatusV1)
