import os, sets, strutils, tables, sequtils


type
  Argument = string
  Arguments = seq[Argument]
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
  ArgumentSetError = object of CatchableError
  ArgumentUnknownError = object of CatchableError


var
  set = false
  parsed = false
  arguments: Arguments
  argumentOptions: ArgumentOptions
  longNames: Table[string, ArgumentOption]
  shortNames: Table[string, ArgumentOption]


proc getKeys(t: Table[string, ArgumentOption]): seq[string] =
  for k in t.keys:
    result.add(k)


proc setArg*(args: ArgumentOptions) =
  for arg in args:
    argumentOptions.add(arg)

    longNames[arg[].long] = arg
    for l in arg[].longAlias:
      longNames[l] = arg

    shortNames[arg[].short] = arg
    for s in arg[].shortAlias:
      shortNames[s] = arg

  if longNames.len != longNames.getKeys.toHashSet.len:
    raise ArgumentSetError.newException("Duplicate long options")

  if shortNames.len != shortNames.getKeys.toHashSet.len:
    raise ArgumentSetError.newException("Duplicate short options")

  set = true
  parsed = false


proc setArg*(args: varargs[ArgumentOption]) =
  let argsSeq = args.toSeq
  setArg(argsSeq)


proc parseArgs*(cmdargs = os.commandLineParams()) =
  if not set:
    raiseAssert("Please call `setArg()` first.")

  if parsed:
    return
  parsed = true

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


proc getValue*(s: string): string =
  parseArgs()

  let arg = if longNames.hasKey(s):
    longNames[s]
  elif shortNames.hasKey(s):
    shortNames[s]
  else:
    raise ArgumentUnknownError.newException("Unknown option: " & s)
  arg.value


proc getValue*(i: int): string =
  arguments[i-1]


proc getValueF*(s: string): bool =
  parseArgs()

  let arg = if longNames.hasKey(s):
    longNames[s]
  elif shortNames.hasKey(s):
    shortNames[s]
  else:
    raise ArgumentUnknownError.newException("Unknown option: " & s)
  arg.valueFlag
