mode = ScriptMode.Verbose

version       = "0.0.1"
author        = "Status Research & Development GmbH"
description   = "This is the humble begginings of library similar to web3.[js|py]"
license       = "MIT or Apache License 2.0"

### Dependencies
requires "nim >= 0.18.0"
requires "chronicles"
requires "chronos"
requires "eth"
requires "faststreams"
requires "json_rpc"
requires "json_serialization"
requires "nimcrypto"
requires "stew"
requires "stint"

### Helper functions
proc test(args, path: string) =
  if not dirExists "build":
    mkDir "build"
  exec "nim " & getEnv("TEST_LANG", "c") & " " & getEnv("NIMFLAGS") & " " & args &
    " --outdir:build -r --hints:off --warnings:off --skipParentCfg " & path


### tasks
task test, "Run all tests":
  test "", "tests/all_tests.nim"
