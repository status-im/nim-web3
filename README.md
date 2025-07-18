# web3

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![License: Apache](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
![Stability: experimental](https://img.shields.io/badge/stability-experimental-orange.svg)
![Github action](https://github.com/status-im/nim-web3/workflows/CI/badge.svg)

The humble beginnings of a Nim library similar to web3.[js|py]

## Installation

You can install the developement version of the library through nimble with the following command

```console
nimble install https://github.com/status-im/nim-web3@#master
```

## Development

Install nodemon globally, hardhat locally and create a `hardhat.config.js` file:

```bash
npm install -g nodemon
npm install hardhat
echo "module.exports = {};" > hardhat.config.js
```

Then you should run `./simulator.sh` which runs `hardhat node`

This creates a local simulated Ethereum network on your local machine and the tests will use this for their E2E processing

## License

Licensed and distributed under either of

- MIT license: [LICENSE-MIT](LICENSE-MIT) or http://opensource.org/licenses/MIT

or

- Apache License, Version 2.0, ([LICENSE-APACHEv2](LICENSE-APACHEv2) or http://www.apache.org/licenses/LICENSE-2.0)

at your option. This file may not be copied, modified, or distributed except according to those terms.
