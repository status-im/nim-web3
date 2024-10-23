# nim-web3
# Copyright (c) 2019-2024 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

mode        = ScriptMode.Verbose
version     = "0.3.4"
author      = "Status Research & Development GmbH"
description = "These are the humble beginnings of library similar to web3.[js|py]"
license     = "MIT or Apache License 2.0"

### Dependencies
requires "nim >= 2.0.0"
requires "chronicles"
requires "chronos"
requires "bearssl"
requires "eth"
requires "faststreams"
requires "json_rpc"
requires "json_serialization"
requires "nimcrypto"
requires "stew"
requires "stint"
requires "results"

### Helper functions
proc test(args, path: string) =
  if not dirExists "build":
    mkDir "build"

  exec "nim " & getEnv("TEST_LANG", "c") & " " & getEnv("NIMFLAGS") & " " & args &
    " --outdir:build -r --skipParentCfg" &
    " --warning[ObservableStores]:off --warning[GcUnsafe2]:off" &
    " --styleCheck:usages --styleCheck:error" &
    " --hint[XDeclaredButNotUsed]:off --hint[Processing]:off " &
    path


### tasks
task test, "Run all tests":
  test "--mm:refc", "tests/all_tests.nim"
  test "--mm:orc", "tests/all_tests.nim"
