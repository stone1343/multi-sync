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
 and ~ will be replaced with the value of $HOME

 For rsync to work as expected, all directories should include trailing /

]=]

textEditor = "editor"

-- Defaults, if these are not specified here, must be specified for every rule
syncCmd = [[sudo rsync -qa --delete-before --exclude lost+found --exclude '.Trash-*']]
listCmd = [[rsync -nva --delete-before --exclude lost+found --exclude '.Trash-*']]
cmdSyntax = [[cmd.." "..src.." "..dest]]

rules = {
 {
  name = "home",
  src  = "/home/",
  dest = "/media/{username}/backup/{computername}/home/"
 }
}

post = [[
 if isDir('/media/{username}/backup/{computername}/home/{username}/.config/') then
  copyFile(dbFile, '/media/{username}/backup/{computername}/home/{username}/.config/')
 end
]]
