import util, shellopt


let inputExpects = build(@[
  # long options
  @[
    "--string hello --int 3 --float 3.14 --bool",
    "string=hello s=hello int=3 d=3 float=3.14 f=3.14 bool=true b=true",
  ],
  # short options (separated by space)
  @[
    "-s hello -d 3 -f 3.14 -b",
    "string=hello s=hello int=3 d=3 float=3.14 f=3.14 bool=true b=true",
  ],
  # short options (joined option and value)
  @[
    "-shello -d3 -f3.14 -b",
    "string=hello s=hello int=3 d=3 float=3.14 f=3.14 bool=true b=true",
  ],
])


when isMainModule:
  run(inputExpects)
