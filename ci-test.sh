#!/bin/bash

set -ex
npm install hardhat@3
npm pkg set type="module"
echo "export default {};" > hardhat.config.js
npx hardhat --version
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

nimble test

nimble test --requires="json_rpc#2e7d4b1527f03830c12403c7c8f1b7ef53f55489"
