#!/bin/sh

set -ex
npm install ganache-cli
nohup ./node_modules/.bin/ganache-cli -s 0 &
nimble install -y

# Wait until ganache responds
while ! curl -X POST --data '{"jsonrpc":"2.0","method":"net_version","params":[],"id":67}' localhost:8545 2>/dev/null
do
  true
done
env TEST_LANG="$TEST_LANG" nimble test
