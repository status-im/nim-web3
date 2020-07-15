import eth/keys

# You should only create one instance of the RNG per application / library
# Ref is used so that it can be shared between components

let theRNG* = newRng()
