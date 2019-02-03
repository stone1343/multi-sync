--[=[

 multi-sync-config.lua (v2.4 2019-02-03)

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

 For rsync to work as expected, all directories should include trailing /

]=]

-- Defaults, if these are not specified here, must be specified for every rule
cmd = [[rsync -qrptgoD --delete-before --exclude=".*" --exclude=lost+found]]
list_cmd = [[rsync -nvrptgoD --delete-before --exclude=".*" --exclude=lost+found]]
cmd_syntax = [[cmd.." "..src.." "..dest]]

rules = {
 -- This is a file
 {
  name = "multi-sync-config",
  expression = "isdir('/media/{username}/backup/')",
  src = "/home/{username}/.config/multi-sync-config.lua",
  dest = "/media/{username}/backup/{computername}/home/{username}/.config/",
 },
 {
  name = "home",
  expression = "isdir('/media/{username}/backup/')",
  src = "/home/{username}/",
  dest = "/media/{username}/backup/{computername}/home/{username}/"
 }
}

post = [[
  if isdir('/media/{username}/backup/{computername}/home/{username}/.config/') then
    copyFile(dbFile, '/media/{username}/backup/{computername}/home/{username}/.config/')
  end
]]
