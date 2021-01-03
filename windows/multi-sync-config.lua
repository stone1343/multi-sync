--[=[

 multi-sync-config.lua v3.2 2021-01-03

 Each rule must define:
  src - a directory or a file
  dest - a directory

 And optionally:
  name - rule name, does not need to be unique
  expression - evaluated as a boolean, so anything other than false and nil is true. If false, the rule will be skipped
  syncCmd
  listCmd
  cmdSyntax

 In expression, src and dest, {computername} and {username} will be replaced with the actual computername and username

 Windows filespecs use [[]] because otherwise \ would be interpreted as an escape character

]=]

textEditor = "notepad"

-- Defaults, if these are not specified here, must be specified for every rule
syncCmd = "/njh /njs /nfl /ndl /r:2 /w:2"
listCmd = syncCmd.." /l"
cmdSyntax = [["robocopy "..src.." "..dest.." /mir "..cmd]]

rules = {
 {
  -- This is a file
  name = "multi-sync-config",
  src  = [[C:\Users\{username}\AppData\Local]],
  dest = [[E:\backup\{computername}\{username}\AppData\Local]],
  cmdSyntax = [["robocopy "..src.." "..dest.." multi-sync-config.lua "..cmd]]
 },
 {
  name = "documents",
  src  = [[C:\Users\{username}\Documents]],
  dest = [[E:\backup\{computername}\{username}\Documents]]
 },
 {
  name = "music",
  src  = [[C:\Users\{username}\Music]],
  dest = [[E:\backup\{computername}\{username}\Music]]
 },
 {
  name = "pictures",
  src  = [[C:\Users\{username}\Pictures]],
  dest = [[E:\backup\{computername}\{username}\Pictures]]
 },
 {
  name = "videos",
  src  = [[C:\Users\{username}\Videos]],
  dest = [[E:\backup\{computername}\{username}\Videos]]
 },
}

post = [[
  if isDir('E:\backup\{computername}\{username}\AppData\Local') then
    copyFile(dbFile, 'E:\backup\{computername}\{username}\AppData\Local')
  end
]]
