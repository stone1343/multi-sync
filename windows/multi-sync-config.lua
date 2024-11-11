--[[ multi-sync-config.lua ]]

rules = {
  {
    name = 'documents',
    src  = 'C:\\Users\\'..userName..'\\Documents',
    dest = 'E:\\backup\\'..computerName..'\\'..userName..'\\Documents'
  },
  {
    name = 'music',
    src  = 'C:\\Users\\'..userName..'\\Music',
    dest = 'E:\\backup\\'..computerName..'\\'..userName..'\\Music'
  },
  {
    name = 'pictures',
    src  = 'C:\\Users\\'..userName..'\\Pictures',
    dest = 'E:\\backup\\'..computerName..'\\'..userName..'\\Pictures'
  },
  {
    name = 'videos',
    expression = [[false]] -- Disabled
    src  = 'C:\\Users\\'..userName..'\\Videos',
    dest = 'E:\\backup\\'..computerName..'\\'..userName..'\\Documents'
  },
}

function post()
  if isDir('E:\\backup\\'..computerName) then
    copyFile(dbFile, 'E:\\backup\\'..computerName)
  end
end
