# nim-web3
# Copyright (c) 2023-2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

import
  std/[json, strutils],
  pkg/unittest2,
  stint,
  ../web3/[conversions, eth_api_types, engine_api_types]

template should_be_value_error(input: string, value: untyped): void =
  expect SerializationError:
    value = EthJson.decode(input, typeof(value))

template should_not_error(input: string, value: untyped): void =
  value = EthJson.decode(input, typeof(value))

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
    should_be_value_error("null", resAddress)
    should_be_value_error("null", resDynamicBytes)
    should_be_value_error("null", resFixedBytes)
    should_be_value_error("null", resQuantity)
    should_be_value_error("null", resRlpEncodedBytes)
    should_be_value_error("null", resTypedTransaction)
    should_be_value_error("null", resUInt256)
    should_not_error("null", resUInt256Ref)

  test "passing empty values to normal convertors":
    should_be_value_error("", resAddress)
    should_be_value_error("", resDynamicBytes)
    should_be_value_error("", resFixedBytes)
    should_be_value_error("", resQuantity)
    should_be_value_error("", resRlpEncodedBytes)
    should_be_value_error("", resTypedTransaction)
    should_be_value_error("", resUInt256)
    should_be_value_error("", resUInt256Ref)

  test "passing invalid hex (0x) values to normal convertors":
    should_be_value_error("\"0x\"", resAddress)
    should_be_value_error("\"0x\"", resDynamicBytes)
    should_be_value_error("\"0x\"", resFixedBytes)
    should_be_value_error("\"0x\"", resQuantity)
    should_be_value_error("\"0x\"", resUInt256)
    should_be_value_error("\"0x\"", resUInt256Ref)

  test "passing hex (0x) values to normal convertors":
    should_not_error("\"0x\"", resRlpEncodedBytes)
    should_not_error("\"0x\"", resTypedTransaction)

  test "passing malformed hex (0x_) values to normal convertors":
    should_be_value_error("\"0x_\"", resAddress)
    should_be_value_error("\"0x_\"", resDynamicBytes)
    should_be_value_error("\"0x_\"", resFixedBytes)
    should_be_value_error("\"0x_\"", resQuantity)
    should_be_value_error("\"0x_\"", resRlpEncodedBytes)
    should_be_value_error("\"0x_\"", resTypedTransaction)
    should_be_value_error("\"0x_\"", resUInt256)
    should_be_value_error("\"0x_\"", resUInt256Ref)

  ## Covering the web3/engine_api_types
  ##
  ## NOTE: These will be transformed by EthJson
  test "passing nully values to specific convertors":

    let payloadAttributesV1 = """{ "timestamp": {item}, "prevRandao": {item}, "suggestedFeeRecipient": {item} }"""
    let forkchoiceStateV1 = """{ "status": {item}, "safeBlockHash": {item}, "finalizedBlockHash": {item} }"""
    let forkchoiceUpdatedResponseV1 = """{ "payloadStatus": {item}, "payloadId": {item} }"""

    var resPayloadAttributesV1: PayloadAttributesV1
    var resForkchoiceStateV1: ForkchoiceStateV1
    var resForkchoiceUpdatedResponseV1: ForkchoiceUpdatedResponseV1

    for item in @["\"\"", "\"0x\"", "\"0x_\"", ""]:
      template format(str: string): string =
        str.replace("{item}", item)

      should_be_value_error(payloadAttributesV1.format(), resPayloadAttributesV1)
      should_be_value_error(forkchoiceStateV1.format(), resForkchoiceStateV1)
      should_be_value_error(forkchoiceUpdatedResponseV1.format(), resForkchoiceUpdatedResponseV1)

    template setNull(str: string): string =
      str.replace("{item}", "null")

    should_not_error(payloadAttributesV1.setNull(), resPayloadAttributesV1)
    should_not_error(forkchoiceStateV1.setNull(), resForkchoiceStateV1)
    should_not_error(forkchoiceUpdatedResponseV1.setNull(), resForkchoiceUpdatedResponseV1)

  ## If different status types can have branching logic
  ## we should cover each status type with different null ops
  test "passing nully values to specific status types":

    var resPayloadStatusV1: PayloadStatusV1

    for status_type in PayloadExecutionStatus:
      let payloadStatusV1 = """{
            "status": "status_name",
            "latestValidHash": null,
            "validationError": null
        }""".replace("status_name", $status_type)

      should_not_error(payloadStatusV1, resPayloadStatusV1)
