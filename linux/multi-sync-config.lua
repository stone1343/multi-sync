--[[ multi-sync-config.lua ]]

rules = {
  {
    name = 'home',
    src  = '/home/',
    dest = '/media/'..userName..'/backup/'..computerName..'/home/'
  }
}

function post()
  if isDir('/media/'..userName..'/backup/'..computerName') then
    copyFile(dbFile, '/media/'..userName..'/backup/'..computerName)
  end
end
