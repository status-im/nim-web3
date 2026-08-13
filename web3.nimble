mode        = ScriptMode.Verbose
version     = "0.8.0"
author      = "Status Research & Development GmbH"
description = "These are the humble beginnings of library similar to web3.[js|py]"
license     = "MIT or Apache License 2.0"

requires "nim >= 2.0.0"
requires "chronicles"
requires "chronos"
requires "bearssl"
requires "eth >= 0.9.0"
requires "faststreams"
requires "json_rpc >= 0.6.0"
requires "serialization >= 0.4.4"
requires "json_serialization >= 0.4.2"
requires "nimcrypto"
requires "stew"
requires "stint"
requires "results"

proc test(args, path: string) =
  if not dirExists "build":
    mkDir "build"

  exec "nim " & getEnv("TEST_LANG", "c") & " " & getEnv("NIMFLAGS") & " " & args &
    " --outdir:build -r --skipParentCfg " &
    path

task test, "Run all tests":
  test "--mm:refc", "tests/all_tests.nim"
  test "--mm:orc", "tests/all_tests.nim"
