import os, sets, strutils, tables, sequtils


type
  Argument = string
  Arguments = seq[Argument]
  # required condition
  # 1. `long` or `short` must be set.
  # 2. Don't set `required` and `flag` at the same time.
  # 3. Don't set strings of more than 2 characters for `short` and `shortAlias`.
  # 4. Don't set strings of single character for `long` and `longAlias`.
  # Violation of these raises an ArgumentInvalidOptionError.
  ArgumentOption* = ref object
    long*: string
    longAlias*: seq[string]
    short*: string
    shortAlias*: seq[string]
    required*: bool
    value: string
    flag*: bool
    valueFlag: bool
  ArgumentOptions* = seq[ArgumentOption]

  # Errors
  # See above.
  ArgumentInvalidOptionError = object of CatchableError
  # The option names (`long` or `short` or these alias) are duplicated.
  ArgumentDuplicateError = object of CatchableError
  # The required options are not specified at runtime.
  ArgumentRequiredError = object of CatchableError
  # Get a value with unset option name.
  ArgumentUnknownError = object of CatchableError


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
      raise ArgumentInvalidOptionError.newException("Neither `long` nor `short` is set\n" & $arg[])
    if arg.required and arg.flag:
      raise ArgumentInvalidOptionError.newException("`required` and `flag` are set at the same." & $arg[])
    if arg.short.len > 1 or arg.shortAlias.countIt(it.len > 1) > 0:
      raise ArgumentInvalidOptionError.newException("Set strings of more than 2 characters for `short` or `shortAlias`" & $arg[])
    if arg.long.len == 1 or arg.longAlias.countIt(it.len == 1) > 0:
      raise ArgumentInvalidOptionError.newException("Set strings of single character for `long` or `longAlias`" & $arg[])

    argumentOptions.add(arg)

    longNames[arg[].long] = arg
    for l in arg[].longAlias:
      longNames[l] = arg

    shortNames[arg[].short] = arg
    for s in arg[].shortAlias:
      shortNames[s] = arg

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
      let arg = longNames[long]
      if arg.flag:
        arg.valueFlag = true
      else:
        i.inc
        arg.value = cmdargs[i]
    elif cmdarg.startsWith("-"):
      let shorts = cmdarg[1..^1]
      for j in 0..shorts.high:
        let s = $shorts[j]
        let arg = shortNames[s]
        if arg.flag:
          arg.valueFlag = true
        else:
          if j == shorts.high:
            i.inc
            arg.value = cmdargs[i]
          else:
            arg.value = shorts[j+1..^1]
          break
    else:
      arguments.add(cmdarg)
    i.inc

  let requiredErrors = argumentOptions
    .filterIt(it.required and it.value == "")
    .mapIt(it.name)
  if requiredErrors.len > 0:
    raise ArgumentRequiredError.newException("Required options: " & $requiredErrors & " are not set.")


proc getValue*(s: string): string =
  parseArg()

  let arg =
    if longNames.hasKey(s):
      longNames[s]
    elif shortNames.hasKey(s):
      shortNames[s]
    else:
      raise ArgumentUnknownError.newException("Unknown option: " & s)
  arg.value


# 1-index
proc getValue*(i: int): string =
  parseArg()

  arguments[i-1]


proc getValueF*(s: string): bool =
  parseArg()

  let arg =
    if longNames.hasKey(s):
      longNames[s]
    elif shortNames.hasKey(s):
      shortNames[s]
    else:
      raise ArgumentUnknownError.newException("Unknown option: " & s)
  arg.valueFlag
