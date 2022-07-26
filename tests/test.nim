import shellopt, unittest, tables, strutils


type
  InputExpect = ref object
    input: seq[string]
    expect: Table[string, string]
  InputExpects = seq[InputExpect]


proc build(s: seq[seq[string]]): InputExpects =
  for ie in s:
    let input = ie[0].splitWhitespace
    var expect: Table[string, string]
    for e in ie[1].splitWhitespace:
      let kv = e.split("=")
      expect[kv[0]] = kv[1]
    result.add(InputExpect(input: input, expect: expect))


proc run(ies: InputExpects) =
  setArg(
    ArgumentOption(
      long: "string",
      valueType: ValueType.string,
      dscr: "string option",
    ),
    ArgumentOption(
      long: "int",
      short: "d",
      valueType: ValueType.int,
      dscr: "int option",
    ),
    ArgumentOption(
      long: "float",
      valueType: ValueType.float,
      dscr: "float option",
    ),
    ArgumentOption(
      long: "bool",
      flag: true,
      dscr: "flag option",
    )
  )
  for ie in ies:
    parseArg(ie.input)
    for k, v in ie.expect:
      case k
      of "string", "s":
        let
          expectValue = v
          actualValue = getValueString(k)
        check expectValue == actualValue
      of "int", "d":
        let
          expectValue = v.parseInt
          actualValue = getValueInt(k)
        check expectValue == actualValue
      of "float", "f":
        let
          expectValue = v.parseFloat
          actualValue = getValueFloat(k)
        check expectValue == actualValue
      of "bool", "b":
        let
          expectValue = v.parseBool
          actualValue = getValueBool(k)
        check expectValue == actualValue
      else:
        check false


let inputExpects = build(@[
  @[
    "--string hello --int 3 --float 3.14 --bool",
    "string=hello s=hello int=3 d=3 float=3.14 f=3.14 bool=true b=true",
  ],
  @[
    "-s hello -i 3 -f 3.14 -b",
    "string=hello s=hello int=3 d=3 float=3.14 f=3.14 bool=true b=true",
  ],
  @[
    "-shello -i3 -f3.14 -b",
    "string=hello s=hello int=3 d=3 float=3.14 f=3.14 bool=true b=true",
  ],
])


when isMainModule:
  run(inputExpects)
