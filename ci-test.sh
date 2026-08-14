#!/bin/bash

# Sets up the Hardhat node used by the test suite. Invoked by the `test` task
# in web3.nimble so that `nimble test` performs the necessary setup itself.

set -ex
npm install hardhat@3.3
npm pkg set type="module"
echo "export default {};" > hardhat.config.js
npx hardhat --version
nohup npx hardhat node &

# Wait until hardhat responds
while ! curl -X POST --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":67}' localhost:8545 2>/dev/null
do
  sleep 1
done
