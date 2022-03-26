--[=[

  multi-sync-config.lua v4.0

  Each rule must define:
    src - a directory or a file
    dest - a directory

  And optionally:
    name - rule name, does not need to be unique
    expression - evaluated as a boolean, so anything other than false and nil is true. If false, the rule will be skipped
    notLinuxFilesystem - true for FAT, NTFS or other non-Linux filesystem
    options - additional rsync command line options, e.g. exclude

  In expression, src, dest, pre and post {computername} and {username} will be replaced with the actual computername and
  username and ~ will be replaced with the value of $HOME

  For rsync to work as expected, all directories should include trailing /

]=]

rules = {
  {
    name = 'home',
    src  = '/home/',
    dest = '/media/{username}/backup/{computername}/home/'
  }
}

post = [[
  if isDir('/media/{username}/backup/{computername}/home/{username}/.config/') then
    copyFile(dbFile, '/media/{username}/backup/{computername}/home/{username}/.config/')
  end
]]
