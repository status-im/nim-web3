#!/bin/sh

set -ex
npm install hardhat
touch hardhat.config.js
nohup npx hardhat node &
nimble install -y --depsOnly

# Wait until ganache responds
while ! curl -X POST --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":67}' localhost:8545 2>/dev/null
do
  sleep 1
done
if [[ -n "${TEST_LANG}" ]]; then
  export TEST_LANG
fi
nimble test
