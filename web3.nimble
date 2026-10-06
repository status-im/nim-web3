# nim-web3
# Copyright (c) 2019-2025 Status Research & Development GmbH
# Licensed under either of
#  * Apache License, version 2.0, ([LICENSE-APACHE](LICENSE-APACHE))
#  * MIT license ([LICENSE-MIT](LICENSE-MIT))
# at your option.
# This file may not be copied, modified, or distributed except according to
# those terms.

mode = ScriptMode.Verbose

packageName   = "web3"
version       = "0.9.0"
author        = "Status Research & Development GmbH"
description   = "These are the humble beginnings of library similar to web3.[js|py]"
license       = "MIT or Apache License 2.0"

requires "nim >= 2.2.14",
         "bearssl >= 0.2.13",
         "chronicles >= 0.12.4",
         "chronos >= 4.4.0",
         "eth >= 0.9.0",
         "faststreams >= 0.5.0",
         "json_rpc >= 0.7.0",
         "serialization >= 0.4.4",
         "json_serialization >= 0.5.0",
         "nimcrypto >= 0.7.0",
         "results >= 0.5.0",
         "stew >= 0.5.0",
         "stint >= 0.9.0"

let nimc = getEnv("NIMC", "nim") # Which nim compiler to use
let lang = getEnv("NIMLANG", "c") # Which backend (c/cpp/js)
let flags = getEnv("NIMFLAGS", "") # Extra flags for the compiler
let verbose = getEnv("V", "") notin ["", "0"]
let platform = getEnv("PLATFORM", "")

from std/os import quoteShell

let cfg =
  " --styleCheck:usages --styleCheck:error" &
  (if verbose: "" else: " --verbosity:0") &
  " --skipParentCfg --skipUserCfg --outdir:build -f " &
  quoteShell("--nimcache:build/nimcache/$projectName")

proc build(args, path: string) =
  exec nimc & " " & lang & " " & cfg & " " & flags & " " & args & " " & path

proc run(args, path: string) =
  build args & " -r", path

proc setupHardhat() =
  # ci-test.sh relies on POSIX shell features (background jobs, a `while` wait
  # loop, `sleep`) that cmd.exe does not understand. nimble's `exec` uses the
  # platform's default shell (cmd.exe on Windows), so we run the script through
  # bash explicitly. bash is available on every CI runner (Git Bash on Windows).
  let bash = findExe("bash")
  if bash.len == 0:
    quit("bash is required to set up the Hardhat test node", QuitFailure)
  exec "\"" & bash & "\" ci-test.sh"


task test, "Run all tests":
  setupHardhat()
  run "--mm:refc", "tests/all_tests"
  run "--mm:orc", "tests/all_tests"

task test_slim, "Run the fast subset of tests (no Hardhat node)":
  # A quick, self-contained subset of the test suite. Runs without the Hardhat
  # node or any network access, so it is suitable for running inside Nim's own
  # test suite to catch compiler / stdlib regressions. See tests/slim_tests.nim
  # for the selection criteria.
  run "--mm:refc", "tests/slim_tests"
  run "--mm:orc", "tests/slim_tests"

task test_asan, "Run all tests with ASAN":
  if platform != "x86":
    # https://clang.llvm.org/docs/AddressSanitizer.html
    putEnv("ASAN_OPTIONS", "detect_leaks=0:detect_stack_use_after_return=1")
    # https://clang.llvm.org/docs/UndefinedBehaviorSanitizer.html
    putEnv("UBSAN_OPTIONS", "print_stacktrace=1")
    let asanArgs =
      " --mm:orc -d:useMalloc --cc:clang --debugger:native" &
      " --passC:-fsanitize=address,undefined" &
      " --passL:-fsanitize=address,undefined" &
      " --passC:-fno-sanitize-recover=undefined" &
      " --passC:-fno-sanitize-merge" &
      " --passC:-fno-omit-frame-pointer" &
      " --passC:-O1"  # error: inline assembly requires more registers than available
    setupHardhat()
    run asanArgs, "tests/all_tests"
