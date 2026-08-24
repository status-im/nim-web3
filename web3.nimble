# nim-web3
# Copyright (c) 2019-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

mode        = ScriptMode.Verbose
version     = "0.8.1"
author      = "Status Research & Development GmbH"
description = "These are the humble beginnings of library similar to web3.[js|py]"
license     = "MIT or Apache License 2.0"

### Dependencies
requires "nim >= 2.0.10"
requires "bearssl >= 0.2.13"
requires "chronicles >= 0.12.4"
requires "chronos >= 4.4.0"
requires "eth >= 0.9.0"
requires "faststreams >= 0.5.0"
requires "json_rpc >= 0.6.0"
requires "json_serialization >= 0.4.2"
requires "nimcrypto >= 0.7.0"
requires "results >= 0.5.0"
requires "serialization >= 0.4.4"
requires "stew >= 0.5.0"
requires "stint >= 0.9.0"

### Helper functions
proc test(args, path: string) =
  if not dirExists "build":
    mkDir "build"

  exec "nim " & getEnv("TEST_LANG", "c") & " " & getEnv("NIMFLAGS") & " " & args &
    " --outdir:build -r --skipParentCfg" &
    " --styleCheck:usages --styleCheck:error" &
    " --hint[Processing]:off " &
    path

proc setupHardhat() =
  # ci-test.sh relies on POSIX shell features (background jobs, a `while` wait
  # loop, `sleep`) that cmd.exe does not understand. nimble's `exec` uses the
  # platform's default shell (cmd.exe on Windows), so we run the script through
  # bash explicitly. bash is available on every CI runner (Git Bash on Windows).
  let bash = findExe("bash")
  if bash.len == 0:
    quit("bash is required to set up the Hardhat test node", QuitFailure)
  exec "\"" & bash & "\" ci-test.sh"


### tasks
task test, "Run all tests":
  setupHardhat()
  test "--mm:refc", "tests/all_tests.nim"
  test "--mm:orc", "tests/all_tests.nim"

task test_slim, "Run the fast subset of tests (no Hardhat node)":
  # A quick, self-contained subset of the test suite. Runs without the Hardhat
  # node or any network access, so it is suitable for running inside Nim's own
  # test suite to catch compiler / stdlib regressions. See tests/slim_tests.nim
  # for the selection criteria.
  test "--mm:refc", "tests/slim_tests.nim"
  test "--mm:orc", "tests/slim_tests.nim"
