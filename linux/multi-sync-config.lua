--[=[
  multi-sync-config.lua
]=]

rules = {
  {
    name = 'home',
    src  = '/home/',
    dest = '/media/{username}/backup/{computername}/home/'
  }
}

post = [=[
  if isDir('/media/{username}/backup/{computername}/home/{username}/.config/') then
    copyFile(dbFile, '/media/{username}/backup/{computername}/home/{username}/.config/')
  end
]=]
