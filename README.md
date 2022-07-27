# shellopt.nim

Nim library for CLI tool, parsing command line arguments.
Unlike the Nim default, it is adapted to the standard format of the shell.

# Usage

```sh
# Install this library
nimble install shellopt

# Example source code
cat <<EOL > shellopt_test.nim
import shellopt, options

proc main() =
  let setArgSuccess = setArg(
    ArgOpt(
      long: "flag",
      short: "f",
      flag: true,
    ),
    ArgOpt(
      long: "value",
      short: "v",
    )
  )
  doAssert(setArgSuccess, "setArg() failed")

  echo getBool("flag").get
  echo getBool("f").get
  echo getString("value").get
  echo getString("v").get

when isMainModule:
  main()
EOL

# Run
nim c shellopt_test.nim
./shellopt_test --flag --value hoge
```
