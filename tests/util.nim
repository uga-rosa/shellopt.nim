import shellopt, unittest, tables, strutils, options, os


type
  InputExpect = ref object
    input: seq[string]
    expect: Table[string, string]
  InputExpects = seq[InputExpect]


proc build*(s: seq[seq[string]]): InputExpects =
  for ie in s:
    let input = ie[0].parseCmdLine
    var expect: Table[string, string]
    for e in ie[1].splitWhitespace:
      let kv = e.split("=")
      expect[kv[0]] = kv[1]
    result.add(InputExpect(input: input, expect: expect))


proc run*(ies: InputExpects) =
  let setSuccess = setArg(@[
    ArgOpt(
      long: "string",
      argType: ArgType.string,
      dscr: "string option",
      required : true,
    ),
    ArgOpt(
      long: "int",
      short: "d",
      argType: ArgType.int,
      dscr: "int option",
    ),
    ArgOpt(
      long: "float",
      argType: ArgType.float,
      dscr: "float option",
    ),
    ArgOpt(
      long: "bool",
      flag: true,
      dscr: "flag option",
    )
  ], false)
  doAssert(setSuccess, "setArg failed")
  for ie in ies:
    let parseSuccess = parseArg(ie.input)
    doAssert(parseSuccess, "parseArg failed")
    for k, v in ie.expect:
      case k
      of "string", "s":
        let
          expectValue = v
          actualValue = getString(k)
        check actualValue.isSome
        check expectValue == actualValue.get
      of "int", "d":
        let
          expectValue = v.parseInt
          actualValue = getInt(k)
        check actualValue.isSome
        check expectValue == actualValue.get
      of "float", "f":
        let
          expectValue = v.parseFloat
          actualValue = getFloat(k)
        check actualValue.isSome
        check expectValue == actualValue.get
      of "bool", "b":
        let
          expectValue = v.parseBool
          actualValue = getBool(k)
        check actualValue.isSome
        check expectValue == actualValue.get
      else:
        check false
