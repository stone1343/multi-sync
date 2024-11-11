--[=[
  multi-sync-config.lua
]=]

rules = {
  {
    name = 'documents',
    src  = [[C:\Users\{username}\Documents]],
    dest = [[E:\backup\{computername}\{username}\Documents]]
  },
  {
    name = 'music',
    src  = [[C:\Users\{username}\Music]],
    dest = [[E:\backup\{computername}\{username}\Music]]
  },
  {
    name = 'pictures',
    src  = [[C:\Users\{username}\Pictures]],
    dest = [[E:\backup\{computername}\{username}\Pictures]]
  },
  {
    name = 'videos',
    expression = [=[false]=] -- Disabled
    src  = [[C:\Users\{username}\Videos]],
    dest = [[E:\backup\{computername}\{username}\Videos]]
  },
}

post = [=[
  if isDir([[E:\backup\{computername}\{username}\AppData\Local]]) then
    copyFile(dbFile, [[E:\backup\{computername}\{username}\AppData\Local]])
  end
]=]
