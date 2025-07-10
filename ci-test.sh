#!/bin/bash

set -ex
npm install hardhat
touch hardhat.config.js
nohup npx hardhat node &
nimble install -y --depsOnly

# Wait until hardhat responds
while ! curl -X POST --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":67}' localhost:8545 2>/dev/null
do
  sleep 1
done
if [[ -n "${TEST_LANG}" ]]; then
  export TEST_LANG
fi
nimble dump --solve
nimble list -i --ver
nimble showPaths # show the paths to make sure they match the ones in the CI
nimble test 
