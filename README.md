# shellopt.nim

A library for parsing command line arguments in the form commonly used in shell.

# Usage

```sh
# Install this library
git clone https://github.com/uga-rosa/shellopt.nim
cd shellopt.nim
nimble install

# Example source code
echo <<EOL > shellopt_test.nim
import shellopt

proc main() =
  setArg(
    ArgumentOption(
      long: "flag",
      short: "f",
      flag: true,
    ),
    ArgumentOption(
      long: "value",
      short: "v",
    )
  )

  echo getValueF("flag")
  echo getValueF("f")
  echo getValue("value")
  echo getValue("v")

when isMainModule:
  main()
EOL

# Run
nim c shellopt_test.nim
./shellopt_test --flag --value hoge
```
