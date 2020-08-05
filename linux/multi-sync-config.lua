--[=[

 multi-sync-config.lua (v3.0 2020-08-05)

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

 For rsync to work as expected, all directories should include trailing /

]=]

textEditor = "nano"

-- Defaults, if these are not specified here, must be specified for every rule
syncCmd = [[rsync -qa --delete-before --exclude=lost+found --exclude='.*']]
listCmd = [[rsync -nva --delete-before --exclude=lost+found --exclude='.*']]
cmdSyntax = [[cmd.." "..src.." "..dest]]

rules = {
 -- This is a file
 {
  name = "multi-sync-config",
  src = "/home/{username}/.config/multi-sync-config.lua",
  dest = "/media/{username}/backup/{computername}/home/{username}/.config/",
 },
 {
  name = "home",
  src = "/home/{username}/",
  dest = "/media/{username}/backup/{computername}/home/{username}/"
 }
}

post = [[
  if isDir('/media/{username}/backup/{computername}/home/{username}/.config/') then
    copyFile(dbFile, '/media/{username}/backup/{computername}/home/{username}/.config/')
  end
]]
