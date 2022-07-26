import shellopt, unittest, tables, strutils


type
  InputExpect = ref object
    set: ArgumentOptions
    input: seq[string]
    expect: Table[string, string]
  InputExpects = seq[InputExpect]


proc build(s: seq[(ArgumentOptions, seq[string])]): InputExpects =
  for sie in s:
    let
      set = sie[0]
      ie = sie[1]
      i = ie[0]
      e = ie[1]

    let input = i.splitWhitespace
    var expect: Table[string, string]
    for e in e.splitWhitespace:
      let kv = e.split("=")
      expect[kv[0]] = kv[1]
    result.add(InputExpect(set: set, input: input, expect: expect))


proc run(ies: InputExpects) =
  for ie in ies:
    setArg(ie.set)
    parseArg(ie.input)
    for k, v in ie.expect:
      if v == "true":
        let
          expectValue = true
          actualValue = getValueF(k)
        check expectValue == actualValue
      else:
        let
          expectValue = v
          actualValue = getValue(k)
        check expectValue == actualValue


let inputExpects = build(@[
  (@[
    ArgumentOption(
      long: "flag",
      short: "f",
      flag: true,
    ),
    ArgumentOption(
      long: "value",
      short: "v"
    ),
  ], @[
    "--flag --value hoge",
    "flag=true f=true value=hoge v=hoge",
  ]),
  (@[
    ArgumentOption(
      long: "flag",
      short: "f",
      flag: true,
    ),
    ArgumentOption(
      long: "value",
      short: "v"
    ),
  ], @[
    "-fvhoge",
    "flag=true f=true value=hoge v=hoge",
  ]),
])


when isMainModule:
  run(inputExpects)
