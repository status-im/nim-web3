func encode(x: int): string =
  $x & " "

type
  Encodable = concept x
    encode(x) is string

func encode(x: seq[Encodable]): string =
  result = encode(x.len)
  for i in x:
    result &= encode(i)

func encode(x: openArray[Encodable]): string =
  result = ""
  for i in x:
    result &= encode(i)

func encodeE(x: seq[seq[Encodable]]): string =
  result = encode(x.len)
  var encodings: seq[string]
  var offset = 32*x.len
  for i in x:
    encodings.add encode(i)
    result &= "[" & $offset & "]"
    offset += encodings[^1].len
  for x in encodings:
    result &= x

func encodeE(x: openArray[seq[Encodable]]): string =
  result = ""
  var encodings: seq[string]
  var offset = 32*x.len
  for i in x:
    encodings.add encode(i)
    result &= "[" & $offset & "]"
    offset += encodings[^1].len
  for x in encodings:
    result &= x


echo encode(10)
echo encode(@[10, 20, 30])
echo encode([10, 20, 30])
echo encodeE([@[1,5,7],@[100,200,300]])
echo encodeE(@[@[1,5,7],@[100,200,300]])
