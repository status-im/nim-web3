#!/bin/bash

set -ex
nimble install -y --depsOnly

if [[ -n "${TEST_LANG}" ]]; then
  export TEST_LANG
fi

nimble test
