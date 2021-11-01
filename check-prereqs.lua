
function prequire(...)
  return pcall(require, ...)
end

local exitRC = 0

if not prequire("lfs") then
  print("luafilesystem not found")
  exitRC = 1
end
if not prequire("luasql.sqlite3") then
  print("luasql-sqlite3 not found")
  exitRC = 1
end
if not prequire("argparse") then
  print("argparse not found")
  exitRC = 1
end
if not prequire("pl.file") or not prequire("pl.path") or not prequire("pl.tablex") or not prequire("pl.utils") then
  print("Penlight not found")
  exitRC = 1
end

os.exit(exitRC)
