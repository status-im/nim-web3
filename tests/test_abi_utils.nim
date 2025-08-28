
import
    std/unittest,
    ../web3/abi_utils

suite "ABI utils":
    test "can determine whether types are dynamic or static":
        check static isStatic(uint8)
        check static isDynamic(seq[byte])
        check static isStatic(array[2, array[2, byte]])
        check static isDynamic(array[2, seq[byte]])
        check static isStatic((uint8, bool))
        check static isDynamic((uint8, seq[byte]))
        check static isStatic((uint8, (bool, uint8)))
        check static isDynamic((uint8, (bool, seq[byte])))