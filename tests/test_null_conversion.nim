import os
import macros
import std/json
import std/strutils
import pkg/unittest2
import stint

import json_rpc/jsonmarshal

import ../web3
import ../web3/[conversions, ethtypes, engine_api_types]

template should_be_value_error(input: string, value: untyped): void =
  expect ValueError:
    fromJson(%input, "", value)

suite "Null conversion":
  test "passing nully values to normal convertors":
    var resAddress: Address
    var resDynamicBytes: DynamicBytes[32]
    var resFixedBytes: FixedBytes[5]
    var resQuantity: Quantity
    var resRlpEncodedBytes: RlpEncodedBytes
    var resTypedTransaction: TypedTransaction
    var resUInt256: UInt256
    var resUInt256Ref: ref UInt256

      # Nully values
    should_be_value_error("null", resAddress)
    should_be_value_error("null", resDynamicBytes)
    should_be_value_error("null", resFixedBytes)
    should_be_value_error("null", resQuantity)
    should_be_value_error("null", resRlpEncodedBytes)
    should_be_value_error("null", resTypedTransaction)
    should_be_value_error("null", resUInt256)
    should_be_value_error("null", resUInt256Ref)

      # Empty values
    should_be_value_error("", resAddress)
    should_be_value_error("", resDynamicBytes)
    should_be_value_error("", resFixedBytes)
    should_be_value_error("", resQuantity)
    should_be_value_error("", resRlpEncodedBytes)
    should_be_value_error("", resTypedTransaction)
    should_be_value_error("", resUInt256)
    should_be_value_error("", resUInt256Ref)

      # Empty hex values
    should_be_value_error("0x", resAddress)
    should_be_value_error("0x", resDynamicBytes)
    should_be_value_error("0x", resFixedBytes)
    should_be_value_error("0x", resQuantity)
    should_be_value_error("0x", resRlpEncodedBytes)
    should_be_value_error("0x", resTypedTransaction)
    should_be_value_error("0x", resUInt256)
    should_be_value_error("0x", resUInt256Ref)

  test "passing nully values to specific convertors":
    let payloadAttributesV1 = """{ "timestamp": null, "prevRandao": null, "suggestedFeeRecipient": null }"""
    let forkchoiceStateV1 = """{ "status": null, "safeBlockHash": null, "finalizedBlockHash": null }"""
    let forkchoiceUpdatedResponse = """{ "payloadStatus": null, "payloadId": null }"""
    let transitionConfigurationV1 = """{ "terminalTotalDifficulty": null, "terminalBlockHash": null, "terminalBlockNumber": hull }"""

    var resPayloadAttributesV1: PayloadAttributesV1
    var resForkchoiceStateV1: ForkchoiceStateV1
    var resForkchoiceUpdatedResponse: ForkchoiceUpdatedResponse
    var resTransitionConfigurationV1: TransitionConfigurationV1

    should_be_value_error(payloadAttributesV1, resPayloadAttributesV1)
    should_be_value_error(forkchoiceStateV1, resForkchoiceStateV1)
    should_be_value_error(forkchoiceUpdatedResponse, resForkchoiceUpdatedResponse)
    should_be_value_error(transitionConfigurationV1, resTransitionConfigurationV1)

  test "passing nully values to specific status types":
    var resPayloadStatusV1: PayloadStatusV1

    for status_type in PayloadExecutionStatus:
      let payloadStatusV1 = """{
            "status": "status_name",
            "latestValidHash": null,
            "validationError": null
        }""".replace("status_name", $status_type)

      should_be_value_error(payloadStatusV1, resPayloadStatusV1)
