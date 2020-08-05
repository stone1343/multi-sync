--[=[

 multi-sync-config.lua (v3.0 2020-08-05)

 Each rule must define:
  src - a directory or a file
  dest - a directory

 And optionally:
  name - rule name, does not need to be unique
  expression - evaluated as a boolean, so anything other than false and nil is true. If false, the rule will be skipped
  cmd
  list_cmd
  cmd_syntax

 In expression, src and dest, {computername} and {username} will be replaced with the actual computername and username

 Windows filespecs use [[]] because otherwise \ would be interpreted as an escape character

]=]

text_editor = "notepad"

-- Defaults, if these are not specified here, must be specified for every rule
cmd = "sfk sync -mirror -wipe -nohidden -yes"
list_cmd = "sfk sync -mirror -wipe -nohidden"
cmd_syntax = [[cmd.." "..src.." "..dest]]

rules = {
 -- This is a file
 {
  name = "multi-sync-config",
  src = [[C:\Users\{username}\AppData\Local\multi-sync-config.lua]],
  dest = [[E:\backup\{computername}\{username}\AppData\Local]],
 },
 {
  name = "documents",
  src = [[C:\Users\{username}\Documents]],
  dest = [[E:\backup\{computername}\{username}\Documents]],
 },
 {
  name = "music",
  src = [[C:\Users\{username}\Music]],
  dest = [[E:\backup\{computername}\{username}\Music]],
 },
 {
  name = "pictures",
  src = [[C:\Users\{username}\Pictures]],
  dest = [[E:\backup\{computername}\{username}\Pictures]],
 },
 {
  name = "videos",
  src = [[C:\Users\{username}\Videos]],
  dest = [[E:\backup\{computername}\{username}\Videos]],
 },
}

post = [[
  if isdir('E:\backup\{computername}\{username}\AppData\Local') then
    copyFile(dbFile, 'E:\backup\{computername}\{username}\AppData\Local')
  end
]]
