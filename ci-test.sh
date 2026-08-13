#!/bin/bash

set -ex
npm install hardhat@3.3
npm pkg set type="module"
echo "export default {};" > hardhat.config.js
npx hardhat --version
nohup npx hardhat node &
nimble install -y --depsOnly

if [[ -n "${TEST_LANG}" ]]; then
  export TEST_LANG
fi

nimble test
