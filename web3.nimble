mode = ScriptMode.Verbose

version       = "0.0.1"
author        = "Status Research & Development GmbH"
description   = "This is the humble begginings of library similar to web3.[js|py]"
license       = "MIT or Apache License 2.0"

### Dependencies
requires "nim >= 0.18.0"
requires "nimcrypto"
requires "stint"
requires "chronicles"
requires "chronos"
requires "json_rpc"
requires "byteutils"
requires "eth"


### Helper functions
proc test(name: string, defaultLang = "c") =
  # TODO, don't forget to change defaultLang to `cpp` if the project requires C++
  if not dirExists "build":
    mkDir "build"
  --run
  switch("out", ("./build/" & name))
  setCommand defaultLang, "tests/" & name & ".nim"

### tasks
task test, "Run all tests":
  test "all_tests"
