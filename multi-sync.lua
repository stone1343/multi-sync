-- v4.3    2024-10-30 JMS Major re-work, again :-)
-- v5.0    2024-11-22 JMS Added rsync remote syntax for Linux, pre and post are now just Lua functions

local multisync_version = '5.0c 2024-11-22'
local copyright = 'Copyright (c) 2024 Jeff Stone'

-- These will fail if not found but the alternative isn't much better
lfs = require 'lfs'
luasql = require 'luasql.sqlite3'
argparse = require 'argparse'
file = require 'pl.file'
path = require 'pl.path'
tablex = require 'pl.tablex'
utils = require 'pl.utils'

-- Reference: https://www.gammon.com.au/scripts/doc.php?lua=dofile
function myDofile(fileName)
  local f, err = loadfile(fileName)
  if f then
    return f()
  else
    print(err)
  end
end

function traceError(err)
  print("traceError: "..err)
end

-- Added in v5.0 for rsync remote
function validateIP(ip)
  local ip1, ip2, ip3, ip4 = ip:match("^([1-9]?%d?%d)%.([1-9]?%d?%d)%.([1-9]?%d?%d)%.([1-9]?%d?%d)$")
  if ip1 and ip2 and ip3 and ip4 then
    ip1, ip2, ip3, ip4 = tonumber(ip1), tonumber(ip2), tonumber(ip3), tonumber(ip4)
    if ip1 <= 255 and ip2 <= 255 and ip3 <= 255 and ip4 <= 255 then
      return true
    end
  end
  return false
end

function validateRemote(remote)
  -- Match host IP address
  local user, host, file = remote:match("^([%a][%a%d_]+)@([%d.]+):([%a%d%p]+)$")
  if user and host and file then
    if not validateIP(host) then host = nil end
  else
    -- Match hostname
    local user, host, file = remote:match("^([%a][%a%d_]+)@([%a][%a%d_]+):([%a%d%p]+)$")
    if host and string.len(host) > 20 then host = nil end
  end
  if string.len(user) > 20 then user = nil end
  -- if user and host and file then
  --   print('\nValid')
  -- else
  --   print('\nInvalid')
  -- end
  return(user and host and file)
end

function validateSrc(src)
  return (isDir(src) or isFile(src) or (not path.is_windows and validateRemote(src)))
end

function validateDest(dest)
  return (isDir(dest) or isFile(dest) or (not path.is_windows and validateRemote(dest)))
end

-- None of the parameters are required
function printRule(name, expression, src, dest, cmd)
  -- formatString works like C sprintf, -12 indicates the field is 12 characters wide and left-justified
  local formatString = '%-12s  %s'
  print('')
  if name then print(string.format(formatString, 'name', name)) end
  if expression then print(string.format(formatString, 'expression', expression)) end
  if src then print(string.format(formatString, 'src', src)) end
  if dest then print(string.format(formatString, 'dest', dest)) end
  if cmd then print(string.format(formatString, 'cmd', cmd)) end
end

-- A function to execute SQL statement and exit if it fails
function executeSQL(db, SQL)
  local cur, err = db:execute(SQL)
  if not cur then
    print(string.format('SQL failed\n %s%s', SQL, err and '\n'..err))
    db:close()
    env:close()
    os.exit(2)
  end
  return cur
end

function lastSync(db, src, dest)
  -- Display the info in the database, there will only ever be zero or one record(s) due to constraint
  local cur = executeSQL(db, string.format([[select datetime(utc, 'localtime') as timestamp, rc from sync_history where src='%s' and dest='%s']], src, dest))
  local row = cur:fetch({}, 'a')
  print('\nLast sync: '..(row and (row.timestamp..', rc = '..row.rc) or 'never'))
  cur:close()
end

-- Seems much more complicated than necessary, but it works
function printHistory(db, rowid)
  local headers = {'rowid', 'src', 'dest', 'timestamp', 'rc'}
  local n = 0
  local rows = {}
  local maxlen = {0, 0, 0, 0, 0}
  for i = 1, 5 do
    maxlen[i]= math.max(maxlen[i], string.len(headers[i]))
  end
  local cur = executeSQL(db, string.format([[select rowid, src, dest, datetime(utc, 'localtime'), rc from sync_history %s order by rowid;]], rowid and ' where rowid='..rowid))
  local row = cur:fetch({})
  while row do
    n = n + 1
    rows[n] = {}
    for i = 1, 5 do
      rows[n][i] = row[i]
      maxlen[i] = math.max(maxlen[i], string.len(rows[n][i]))
    end
    row = cur:fetch(row)
  end
  cur:close()
  if n > 0 then
    local formatString = '%-'..maxlen[1]..'s  %-'..maxlen[2]..'s  %-'..maxlen[3]..'s  %-'..maxlen[4]..'s  %-'..maxlen[5]..'s'
    -- Print the header
    print(string.format('\n'..formatString, headers[1], headers[2], headers[3], headers[4], headers[5]))
    print(string.rep('-', maxlen[1])..'  '..string.rep('-', maxlen[2])..'  '..string.rep('-', maxlen[3])..'  '..string.rep('-', maxlen[4])..'  '..string.rep('-', maxlen[5]))
    -- Print the data
    for i = 1, n do
      print(string.format(formatString, rows[i][1], rows[i][2], rows[i][3], rows[i][4], rows[i][5]))
    end
  else
    if rowid then
      print('No rowid '..rowid)
    else
      print('No sync history')
    end
  end
  return n
end

-- Functions specifically for use in config file

function isDir(filespec)
  return (path.attrib(filespec, 'mode') == 'directory')
end

function isFile(filespec)
  return (path.attrib(filespec, 'mode') == 'file')
end

function copyFile(src, dest)
  if path.isfile(src) then
    if path.isdir(dest) then
      file.copy(src, dest)
    else
      print('\ncopyFile requires dest to be an existing directory')
    end
  else
    print('\ncopyFile requires src to be an existing file')
  end
end

--[[
  Main begins here
--]]

computerName, userName, configDir = os.getenv('COMPUTERNAME'), os.getenv('USERNAME'), os.getenv('CONFIGDIR')
if (not computerName) or (not userName) or (not configDir) then
  print('Set environment variables COMPUTERNAME, USERNAME and CONFIGDIR prior to calling Lua')
  os.exit(2)
end
configFile = path.join(configDir, 'multi-sync-config.lua')
dbFilename = 'multi-sync.sqlite3'
dbFile = path.join(configDir, dbFilename)
local db
env = luasql.sqlite3()
local parser = argparse('multi-sync', 'Rules-based script for using rsync or robocopy to automate backups', copyright)
parser:mutex(
  -- Flags which do one thing and exit
  parser:flag '--version'
    :description 'Output version information and exit'
    :action(
      function()
        print('multi-sync '..multisync_version..'\n')
        print(_VERSION)
        print(lfs._VERSION)
        print(luasql._VERSION)
        local db = env:connect(':memory:')
        local cur = executeSQL(db, [[select 'SQLite '||sqlite_version()]])
        print(cur:fetch())
        cur:close()
        db:close()
        env:close()
        print('Argparse '..argparse.version)
        print('Penlight '..utils._VERSION)
        print('\n'..copyright)
        os.exit(0)
      end
    ),
  parser:flag '-i' '--initialize'
    :description 'Initialize the database'
    :target 'initialize',
  parser:flag '-c' '--configure'
    :description 'Configure rules'
    :target 'configure',
  parser:flag '-p' '--print-history'
    :description 'Print sync history'
    :target 'printHistory'
    -- One optional argument = location of multi-sync.sqlite3
    :args('?'),
  parser:option '-f' '--forget'
    :description 'Forget row(s) of sync history'
    :target 'forget'
    -- One or more arguments = rowid(s) to forget
    :args('+')
)
-- Optional flags for normal operation
-- Even though they're not mutually-exclusive with the above flags, these would have no effect
parser:flag '-v' '--verbose'
  :description 'Verbose mode'
  :target 'verbose'
parser:flag '-l' '--list'
  :description 'List files which would be copied'
  :target 'list'
parser:flag '-n' '--dry-run'
  :description 'Output the final command(s), do not execute'
  :target 'dryRun'
parser:argument 'names'
  :description 'Specify rule(s) to run by name. May specify zero, one or more names'
  :target 'names'
  -- Zero, one or more arguments = names to process
  :args('*')
args = parser:parse()

-- Process -i
if args.initialize then
  db = env:connect(dbFile)
  -- This one can't use executeSQL because it is guaranteed to fail the first time since the table doesn't exist
  db:execute('drop table sync_history')
  -- Windows filesystems aren't case-sensitive so the database that keeps track shouldn't be either, use 'collate nocase' for src and dest
  if path.is_windows then
    executeSQL(db, [[
      create table sync_history(
        src text not null collate nocase,
        dest text not null collate nocase,
        utc text,
        rc integer,
        constraint unique_src_dest unique(src, dest)
      )
    ]])
  else
    executeSQL(db, [[
      create table sync_history(
        src text not null,
        dest text not null,
        utc text,
        rc integer,
        constraint unique_src_dest unique(src, dest)
      )
    ]])
  end
  db:close()
  env:close()
  os.exit(0)
end

-- Process -c
if args.configure then
  if path.is_windows then
    os.execute('notepad '..configFile)
  else
    os.execute('editor '..configFile)
  end
  env:close()
  os.exit(0)
end

-- Process -p
if args.printHistory then
  if args.printHistory[1] then
    dbFile = nil
    local dbArgument = args.printHistory[1]
    -- If argument points directly to the DB
    if isFile(dbArgument) and string.sub(dbArgument, -string.len(dbFilename)) == dbFilename then
      dbFile = dbArgument
    -- Or if it specifies the directory where the DB is
    elseif isFile(path.join(dbArgument, dbFilename)) then
      dbFile = path.join(dbArgument, dbFilename)
    else
      print('print-history argument must specify multi-sync.sqlite3 or a directory containing it')
    end
  end
  if dbFile then
    print('Printing sync history from '..dbFile)
    db = env:connect(dbFile)
    printHistory(db)
    db:close()
  end
  env:close()
  os.exit(0)
end

-- Process -f
if args.forget then
  db = env:connect(dbFile)
  for i = 1, tablex.size(args.forget) do
    local f = tonumber(args.forget[i])
    if f then
      if printHistory(db, f) == 1 then
        executeSQL(db, 'delete from sync_history where rowid='..f)
        print('Deleted rowid '..f)
      end
    else
      print('Ignoring non-numeric '..args.forget[i])
    end
  end
  db:close()
  env:close()
  os.exit(0)
end

-- Process configFile
myDofile(configFile) -- Good possibility of a syntax error in configFile, so handle it more gracefully than Lua's dofile()
if not rules then
  print('Syntax error in configFile, rules must be specified')
  env:close()
  os.exit(2)
end

db = env:connect(dbFile)

-- "Pre" routine
if pre then
  if not xpcall(pre, traceError) then
    env:close()
    os.exit(2)
  end
end

-- Process rules
for i, rule in pairs(rules) do
  -- From https://stackoverflow.com/questions/3524970/why-does-lua-have-no-continue-statement, use an infinite 'repeat until true', code must explicitly 'do break end'
  repeat -- 'repeat until true' is an infinite loop, break out of it with 'do break end'
    -- Parse the rule
    name = rule.name
    if type(name) ~= 'string' or name == '' then name = nil end
    expression = rule.expression
    -- In Lua, nil and false are equivalent, anything else is considered true
    if not expression then
      expression = true
    else
      if type(expression) ~= 'string' or expression == '' then
        expression = true
      else
        -- Convert it to a boolean
        expression = load('return('..expression..')')()
        --print('expression '..tostring(expression))
      end
    end
    src = rule.src
    if type(src) ~= 'string' or src == '' then
      src = nil
    end
    dest = rule.dest
    if type(dest) ~= 'string' or dest == '' then
      dest = nil
    end
    -- Evaluate the rule
    if name and (tablex.size(args.names) ~= 0) and (not tablex.find(args.names, name)) then
      if args.verbose then
        printRule(name, rule.expression, src, dest)
        print('\nRule skipped because of name')
      end
      do break end
    end
    if not expression then
      if args.verbose then
        printRule(name, rule.expression, src, dest)
        print('\nRule skipped because of expression')
      end
      do break end
    end
    if not src then
      if args.verbose then
        printRule(name, rule.expression, src, dest)
        print('\nRule skipped because src is nil')
      end
      do break end
    else
      if not validateSrc(src) then
        if args.verbose then
          printRule(name, rule.expression, src, dest)
          print('\nRule skipped because src is invalid')
        end
        do break end
      end
    end
    if not dest then
      if args.verbose then
        printRule(name, rule.expression, src, dest)
        print('\nRule skipped because dest is nil')
      end
      do break end
    else
      if not validateDest(dest) then
        if args.verbose then
          printRule(name, rule.expression, src, dest)
          print('\nRule skipped because dest is invalid')
        end
        do break end
      end
    end
    -- Process the rule
    if path.is_windows then
      options = rule.options and rule.options or '/njh /ndl /njs /r:2 /w:2 /xjd'
      if args.list then
        options = options..' /l'
      else
        options = options..' /nfl'
      end
      if path.isfile(src) then
        cmd = 'robocopy "'..path.dirname(src)..'" "'..dest..'" "'..path.basename(src)..'" '..options
      else
        cmd = 'robocopy "'..src..'" "'..dest..'" /mir '..options
      end
    else
      options = rule.options and rule.options or '-a --delete'
      if args.list then
        options = '-nv '..options
      else
        options = '-q '..options
      end
      cmd = 'rsync '..options..' \''..src..'\' \''..dest..'\''
    end
    printRule(name, rule.expression, src, dest, cmd)
    if (not args.dryRun) then
      local handler = io.popen(cmd)
      local stdout = handler:read('*a')
      local dummy, err, rc = handler:close()
      if string.len(stdout) ~= 0 then
        print('\n'..stdout)
      end
      if not args.list then executeSQL(db, string.format([[insert or replace into sync_history (src, dest, utc, rc) values('%s', '%s', datetime('now'), '%d')]], src, dest, rc)) end
    end
    lastSync(db, src, dest)
    do break end -- break out of ininite 'repeat until true' loop and continue with for loop
  until true -- 'repeat until true' is an infinite loop
end --for

-- "Post" routine
if post then
  if not xpcall(post, traceError) then
    env:close()
    os.exit(2)
  end
end

-- Close everything
db:close()
env:close()
os.exit()
