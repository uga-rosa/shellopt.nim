import os, sets, strutils, tables, sequtils, strformat


type
  Argument = string
  Arguments = seq[Argument]
  ValueType* {.pure.} = enum
    string, int, float, bool
  # required condition
  # 1. `long` or `short` must be set.
  # 2. Don't set `required` and `flag` at the same time.
  # 3. Don't set strings of more than 2 characters for `short` and `shortAlias`.
  # 4. Don't set strings of single character for `long` and `longAlias`.
  # Violation of these raises an ArgumentInvalidOptionError.
  ArgumentOption* = ref object
    long*: string
    short*: string
    valueType*: ValueType
    dscr*: string
    required*: bool
    valueAsString: string
    flag*: bool # Alias: valueType bool
  ArgumentOptions* = seq[ArgumentOption]

  # Errors
  # See above.
  ArgumentOptionError = object of CatchableError
  # The option names (`long` or `short`) are duplicated.
  ArgumentDuplicateError = object of CatchableError
  # The required options are not specified at runtime.
  ArgumentRequiredError = object of CatchableError
  # Unknown option name
  ArgumentNameError = object of CatchableError
  # Get a value with invalid type.
  ArgumentTypeError = object of CatchableError
  # Parsing failed
  ArgumentParseError = object of CatchableError


var
  calledSetArg = false
  calledParseArg = false
  arguments: Arguments
  argumentOptions: ArgumentOptions
  longNames: Table[string, ArgumentOption]
  shortNames: Table[string, ArgumentOption]


proc setArg*(args: ArgumentOptions) =
  for arg in args:
    if arg.long == "" and arg.short == "":
      raise ArgumentOptionError.newException("Neither `long` nor `short` is set\n" & $arg[])
    if arg.required and arg.flag:
      raise ArgumentOptionError.newException("`required` and `flag` are set at the same.\n" & $arg[])
    if arg.short.len > 1:
      raise ArgumentOptionError.newException("Set strings of more than 2 characters for `short`.\n" & $arg[])
    if arg.long.len == 10:
      raise ArgumentOptionError.newException("Set strings of single character for `long`\n" & $arg[])

    if arg.valueType == ValueType.bool:
      arg.flag = true
    elif arg.flag == true:
      arg.valueType = ValueType.bool

    argumentOptions.add(arg)

    # Set short option name automatically.
    if arg.short == "":
      let s = $arg.long[0]
      if not shortNames.hasKey(s):
        arg.short = s

    longNames[arg.long] = arg
    shortNames[arg.short] = arg

  if longNames.len != longNames.keys.toSeq.toHashSet.len:
    raise ArgumentDuplicateError.newException("Duplicate long options")

  if shortNames.len != shortNames.keys.toSeq.toHashSet.len:
    raise ArgumentDuplicateError.newException("Duplicate short options")

  calledSetArg = true
  calledParseArg = false


proc setArg*(args: varargs[ArgumentOption]) =
  let argsSeq = args.toSeq
  setArg(argsSeq)


proc name(arg: ArgumentOption): string =
  if arg.long != "":
    return arg.long
  else:
    return arg.short


proc parseArg*(cmdargs = os.commandLineParams()) =
  if not calledSetArg:
    raiseAssert("Please call `setArg()` first.")

  if calledParseArg:
    return
  calledParseArg = true

  var i = 0
  while i <= cmdargs.high:
    let cmdarg = cmdargs[i]
    if cmdarg.startsWith("--"):
      let long = cmdarg[2..^1]
      if longNames.hasKey(long):
        let arg = longNames[long]
        if arg.flag:
          arg.valueAsString = "true"
        else:
          i.inc
          arg.valueAsString = cmdargs[i]
      else:
        raise ArgumentNameError.newException("Unknown option: " & $long)
    elif cmdarg.startsWith("-"):
      let shorts = cmdarg[1..^1]
      for j in 0..shorts.high:
        let short = $shorts[j]
        if shortNames.hasKey(short):
          let arg = shortNames[short]
          if arg.flag:
            arg.valueAsString = "true"
          else:
            if j == shorts.high:
              i.inc
              arg.valueAsString = cmdargs[i]
            else:
              arg.valueAsString = shorts[j+1..^1]
            break
        else:
          raise ArgumentNameError.newException("Unknown option: " & $short)
    else:
      arguments.add(cmdarg)
    i.inc

  let requiredErrors = argumentOptions
    .filterIt(it.required and it.valueAsString == "")
    .mapIt(it.name)
  if requiredErrors.len > 0:
    raise ArgumentRequiredError.newException(fmt"Required options: {requiredErrors} are not set.")


# 1-index
proc getValue*(i: int): string =
  let id = i-1
  parseArg()

  if id <= arguments.high:
    return arguments[id]
  else:
    let num =
      case i
      of 1: "1st"
      of 2: "2nd"
      of 3: "3rd"
      else: $i & "th"
    raise ArgumentNameError.newException(fmt"The {num} argument is called, but there are only {arguments.len} arguments.")


proc getArg(s: string): ArgumentOption =
  parseArg()
  if longNames.hasKey(s):
    return longNames[s]
  elif shortNames.hasKey(s):
    return shortNames[s]
  else:
    raise ArgumentNameError.newException("Unknown option: " & s)


# getValue`Type`() raises ArgumentTypeError if the type is not appropriate.
# The only exception is this function, which is allowed to be retrieved as a string even if it is set to another type.
proc getValueString*(s: string): string =
  let arg = getArg(s)
  # Omitted type check
  return arg.valueAsString


proc getValueInt*(s: string): int =
  let arg = getArg(s)
  if arg.valueType == ValueType.int:
    try:
      return arg.valueAsString.parseInt
    except ValueError:
      raise ArgumentParseError.newException(fmt"{arg.valueAsString} cannot be parsed to int.")
  else:
    raise ArgumentTypeError.newException(fmt"Option `{arg.name}`'s type is {arg.valueType}, not int.")


proc getValueFloat*(s: string): float =
  let arg = getArg(s)
  if arg.valueType == ValueType.float:
    try:
      return arg.valueAsString.parseFloat
    except ValueError:
      raise ArgumentParseError.newException(fmt"{arg.valueAsString} cannot be parsed to float.")
  else:
    raise ArgumentTypeError.newException(fmt"Option `{arg.name}`'s type is {arg.valueType}, not float.")


proc getValueBool*(s: string): bool =
  let arg = getArg(s)
  if arg.flag:
    # if arg.flag == true, arg.valueAsString should be "" or "true".
    return arg.valueAsString == "true"
  else:
    raise ArgumentTypeError.newException(fmt"Option `{arg.name}`'s type is {arg.valueType}, not bool.")
