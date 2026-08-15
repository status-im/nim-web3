# nim-web3
# Copyright (c) 2018-2026 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

# A fast subset of the test suite, intended to be run as part of Nim's own
# test suite to detect regressions in the Nim compiler / stdlib that would
# break nim-web3.
#
# Selection criteria:
#   1) quick to run (no Hardhat node, no network, no git submodules),
#   2) cover the broadest set of stdlib dependencies and compiler features.
#
# The tests below are deliberately chosen to exercise the areas most likely
# to break across Nim updates:
#   - macros / AST manipulation (the `contract` DSL),
#   - generics, tuples, distinct types, enums, ranges,
#   - the `serialization` framework integration,
#   - std/json and std/strutils,
#   - compile-time type introspection.
#
# Excluded (and why):
#   - test_contracts, test_deposit_contract, test_logs: need a Hardhat node.
#   - test_signed_tx: mostly pure signing tests, but also contains a network
#     test, so it is skipped rather than split.
#   - test_execution_api: needs the tests/execution-apis git submodule.
#   - test_primitives, test_execution_types, test_string_decoder: covered by
#     other tests for the relevant features, kept out to stay lean.

{. warning[UnusedImport]:off .}

import
  test_contract_dsl,      # macros / AST / quote do / compile-time codegen
  test_encoding,          # generics, tuples, distinct, sequtils, random
  test_decoding,          # ranges, enums, overflow, endian conversion
  test_abi_serialization, # serialization framework integration
  test_abi_utils,         # compile-time type introspection
  test_json_marshalling,  # std/json + json_serialization + typetraits
  test_null_conversion    # std/json + strutils + distinct conversion edge cases
