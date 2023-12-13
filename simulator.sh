#!/usr/bin/env bash

# NOTE: Requires nodemon (https://github.com/remy/nodemon)
#       npm i -g nodemon

# Watch all nim files for changes
# When a file change is detected we will restart ganache-cli
# This ensures that our deposit contracts have enough ETH as
# it seems like some of the tests do not properly initialise
# their contracts at this time. (state persists across runs)

nodemon --ext '.nim' --watch tests --watch web3 --exec "ganache-cli"
