import
  ethtypes

func parseCmdArg*(T: type Address, input: TaintedString): T
                 {.raises: [ValueError, Defect].} =
  fromHex(T, string input)

func completeCmdArg*(T: type Address, input: TaintedString): seq[string] =
  @[]

func parseCmdArg*(T: type BlockHash, input: TaintedString): T
                 {.raises: [ValueError, Defect].} =
  fromHex(T, string input)

func completeCmdArg*(T: type BlockHash, input: TaintedString): seq[string] =
  @[]
