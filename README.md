# web3

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)
![Github action](https://github.com/status-im/nim-web3/workflows/nim-web3%20CI/badge.svg)

The humble beginnings of a Nim library similar to web3.[js|py]

## Installation

You can install the developement version of the library through nimble with the following command

```
nimble install https://github.com/status-im/nim-web3@#master
```

## Development

You should first run `./simulator.sh` which runs `ganache-cli`

This creates a local simulated Ethereum network on your local machine and the tests will use this for their E2E processing

### Interaction with nimbus-eth2

This repo relies heavily on parts of the `nimbus-eth2` repo.
In order to work properly here you need to `source /nimbus-eth2/env.sh`

#### Example

Need to log the output of the `websocketclient.nim` responses:

1. Make modifications in `/nimbus-eth2/vendor/nim-json-rpc/json-rpc/clients/websocketclient.nim`
2. `source /nimbus-eth2/env.sh`
3. Run tests (`nimble test`) in the web3-repo

We should now see our output logged correctly to the console.

## License

Licensed and distributed under either of

- MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

- Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. This file may not be copied, modified, or distributed except according to those terms.
