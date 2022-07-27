import os, logging, strutils, tables, sequtils, strformat, options, sugar


type
  Arg = string
  Args = seq[Arg]
  ArgType* {.pure.} = enum
    string, int, float, bool
  # required condition
  # 1. `long` or `short` must be set.
  # 2. Don't set `required` and `flag` (same as `argType: ArgType.bool`) at the same time.
  # 3. Don't set a string of more than 2 characters for `short`.
  # 4. Don't set a string of single character for `long`.
  # 5. Don't duplicate `long` and `short`.
  # If these conditions are not met, the ArgOpt is ignored.
  # log level: lvlError
  ArgOpt* = ref object
    long*: string
    short*: string
    argType*: ArgType
    dscr*: string
    # If `required` is true but don't set at runtime, 
    required*: bool
    valueAsString: string
    flag*: bool # Alias: valueType bool
  ArgOpts* = seq[ArgOpt]


proc name(a: ArgOpt): string =
  if a.long != "":
    return a.long
  else:
    return a.short


var
  logger = newConsoleLogger(lvlWarn)
  calledSetArg = false
  arguments: Args
  argumentOptions: ArgOpts
  longNames: Table[string, ArgOpt]
  shortNames: Table[string, ArgOpt]
  usage: string


proc loggerSetup*(lvl: Level) =
  logger = newConsoleLogger(lvl)


proc loggerSetup*(lvl: Level, fmtStr: string) =
  logger = newConsoleLogger(lvl, fmtStr)


proc loggerSetup*(lvl: Level, fmtStr: string, useStderr: bool) =
  logger = newConsoleLogger(lvl, fmtStr, useStderr)


# If all parsing success, return true.
proc parseArg*(cmdargs = os.commandLineParams()): bool =
  result = true
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
        logger.log(lvlError, "Unknown option: " & $long)
        result = false
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
          logger.log(lvlError, "Unknown option: " & $short)
          result = false
    else:
      arguments.add(cmdarg)
    i.inc

  let requiredNotSet = argumentOptions
    .filterIt(it.required and it.valueAsString == "")
    .mapIt(it.name)
  if requiredNotSet.len > 0:
    logger.log(lvlError, fmt"Required options: {requiredNotSet} are not set.")
    result = false


proc init() =
  argumentOptions = @[]
  longNames = initTable[string, ArgOpt]()
  shortNames = initTable[string, ArgOpt]()

  argumentOptions.add(ArgOpt(
    long: "help",
    short: "h",
    flag: true,
    dscr: "Print this help message."
  ))
  longNames["help"] = argumentOptions[0]
  shortNames["h"] = argumentOptions[0]


# If all set and parsing success, return true
proc setArg*(args: ArgOpts, doParse = true): bool =
  calledSetArg = true
  result = true

  # initialize
  init()

  for arg in args:
    var ignore = false

    if arg.long == "" and arg.short == "":
      logger.log(lvlError, "Neither `long` nor `short` is set", $arg[])
      ignore = true

    if arg.required and arg.flag:
      logger.log(lvlError, "`required` and `flag` are set at the same.", $arg[])
      ignore = true

    if arg.short.len > 1:
      logger.log(lvlError, "Set strings of more than 2 characters for `short`.", $arg[])
      ignore = true

    if arg.long.len == 10:
      logger.log(lvlError, "Set strings of single character for `long`", $arg[])
      ignore = true

    if arg.long != "":
      if longNames.hasKey(arg.long):
        logger.log(lvlError, "Duplicate long options: " & arg.long)
        ignore = true
      else:
        longNames[arg.long] = arg

    if arg.short != "":
      if shortNames.hasKey(arg.short):
        logger.log(lvlError, "Duplicate short options: " & arg.short)
        ignore = true
      else:
        shortNames[arg.short] = arg
    else:
      # Set short option name automatically.
      if arg.long != "":
        let s = $arg.long[0]
        if not shortNames.hasKey(s):
          arg.short = s
          shortNames[arg.short] = arg

    if ignore:
      result = false
    else:
      if arg.argType == ArgType.bool:
        arg.flag = true
      elif arg.flag == true:
        arg.argType = ArgType.bool

      argumentOptions.add(arg)

  if doParse:
    return parseArg() and result
  else:
    return result


proc setArg*(args: varargs[ArgOpt]): bool =
  let argsSeq = args.toSeq
  setArg(argsSeq)


# 1-index
proc getArg*(i: int): Option[string] =
  let id = i-1

  if id <= arguments.high:
    return arguments[id].some
  else:
    let num =
      case i
      of 1: "1st"
      of 2: "2nd"
      of 3: "3rd"
      else: $i & "th"
    logger.log(lvlError, fmt"The {num} argument is called, but there are only {arguments.len} arguments.")


proc getArgOpt(s: string): Option[ArgOpt] =
  if not calledSetArg:
    logger.log(lvlFatal, "`setArg()` has not been called!")
    return

  if longNames.hasKey(s):
    return longNames[s].some
  elif shortNames.hasKey(s):
    return shortNames[s].some
  else:
    logger.log(lvlError, "Unknown option: " & s)


proc getString*(s: string): Option[string] =
  let arg = getArgOpt(s)
  if arg.filter(it => it.argType == ArgType.string).isNone:
    logger.log(lvlInfo, "argType of {arg.get.name} is {arg.get.argType}, not string.")
  arg.map(it => it.valueAsString)


proc getInt*(s: string): Option[int] =
  let arg = getArgOpt(s)
  arg.filter(it => it.argType == ArgType.int).map(it => it.valueAsString.parseInt)


proc getFloat*(s: string): Option[float] =
  let arg = getArgOpt(s)
  arg.filter(it => it.argType == ArgType.float).map(it => it.valueAsString.parseFloat)


proc getBool*(s: string): Option[bool] =
  let arg = getArgOpt(s)
  arg.filter(it => it.argType == ArgType.bool).map(it => it.valueAsString == "true")


proc setUsage*(s: string) =
  usage = s


proc getStrings(arg: ArgOpt): (string, string, string) =
  var keys: seq[string]
  if arg.short != "":
    keys.add("-" & arg.short)
  if arg.long != "":
    keys.add("--" & arg.long)
  (keys.join(", "), $arg.argType, arg.dscr)


proc getHelpDocument*(): string =
  let
    executableName = getAppFilename().splitPath.tail
    required = argumentOptions
      .filterIt(it.required)
      .map(getStrings)
    optional = argumentOptions
      .filterIt(not it.required)
      .map(getStrings)

  var cols: (int, int, int)
  for r in required:
    if cols[0] < r[0].len:
      cols[0] = r[0].len
    if cols[1] < r[1].len:
      cols[1] = r[1].len
  for o in optional:
    if cols[0] < o[0].len:
      cols[0] = o[0].len
    if cols[1] < o[1].len:
      cols[1] = o[1].len
  cols[0].inc(2)
  cols[1].inc(4)

  var
    requiredDoc = required
      .mapIt("  " & it[0].alignLeft(cols[0]) & ": " & it[1].alignLeft(cols[1]) & it[2])
      .join("\n")
    optionalDoc = optional
      .mapIt("  " & it[0].alignLeft(cols[0]) & ": " & it[1].alignLeft(cols[1]) & it[2])
      .join("\n")

  var doc = fmt"""
Usage:
  {executableName} [OPTIONS]... ARGS...
{usage}

OPTIONS:"""

  if requiredDoc != "":
    doc = doc & "\n[required]\n" & requiredDoc
  if optionalDoc != "":
    doc = doc & "\n[optional]\n" & optionalDoc

  return doc
