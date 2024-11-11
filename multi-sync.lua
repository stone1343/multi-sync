-- v1.0   2016-10-01 JMS
-- v1.0.1 2016-10-04 JMS Enhanced customizability and usability
-- v1.0.2 2016-10-06 JMS More enhanced customizability and usability
-- v1.1   2016-10-23 JMS {computername} and {username} in -config files, so less customization required
-- v1.1.1 2016-10-25 JMS When outputting 'Latest successful sync', also output if the rule has never been synced
-- v1.1.2 2016-10-27 JMS Bugfix, cmd and options must be global
-- v1.2   2016-10-30 JMS List files modified since last sync
-- v1.2.1 2016-10-31 JMS Move the 'list files modified since last sync' code to where it can also run if dest doesn't exist
-- v1.2.2 2016-12-17 JMS Tolerate null attr from Google Drive
-- v1.2.3 2017-05-13 JMS Added --version flag, including Lua and library versions
--        2017-06-05 JMS Handle syntax error(s) in multi-sync-config.lua more gracefully, fairly significant re-structuring
-- v1.3   2017-09-20 JMS Various enhancements, code merge
-- v2.0   2017-10-15 JMS 'Dry Run' just outputs the final command(s) without executing anything
--                       Name and expression are optional; cmd, options, cmdSyntax and rules are not
--        2017-10-20 JMS Added --list flag, removed options
--        2017-10-25 JMS Added --print-history flag
--        2017-10-26 JMS Added --forget option
--        2017-10-28 JMS v2.0 readiness
--        2017-10-31 JMS v2.0
-- v2.0.1 2017-11-03 JMS path.abspath is not called, src and dest are used as is
-- v2.1   2017-11-07 JMS Use SQLite datetime() function to store the timestamp so it's human-readable in the database
-- v2.1.1 2017-11-29 JMS Correct typo in variable names filePath, fileName; Solved the -c problem
-- v2.1.2 2017-12-02 JMS No code changes, just more standard Linux packaging
-- v2.1.3 2017-12-03 JMS Installer doesn't create ~/.config, Bash does
-- v2.1.4 2017-12-03 JMS Properly handle initial execution, where both -i and -c are assumed
-- v2.2   2018-10-20 JMS Refresh versions, move to github
-- v2.2.1 2018-11-25 JMS Refresh versions again
-- v2.2.2 2018-12-15 JMS Update SQLite to v3.26 ( https://www.zdnet.com/article/sqlite-bug-impacts-thousands-of-apps-including-all-chromium-based-browsers/ )
-- v2.3   2019-01-01 JMS Add pre and post routines, allow an optional database argument to --print-history
--        2019-01-05 JMS Output Lua's _VERSION, which has been patched to include release, e.g. 5.3.5, without hardcoding it here
-- v2.4   2019-02-03 JMS Change packaging, Linux now relies on libraries installed by LuaRocks
-- v2.5   2019-10-05 JMS Calling script responsible for ensuring both multi-sync.sqlite3 and multi-sync-config.lua exist
-- v3.0   2020-08-05 JMS Re-org, breaks compatibility with previous config files, adds textEditor to config file
-- v3.1   2020-12-05 JMS Change command line options and output; debug replaces quiet so the default is quiet
--        2020-12 06 JMS Fix defect with cmdSyntax
-- v3.2   2021-01-03 JMS Linux INSTALLDIR is /usr/local/share/multi-sync, following the FHS better
--                       --verbose replaces --debug command line option, there's no short version of --verbose
-- v3.2.1 2021-06-11 JMS Allow install to ~/.local or /usr/local (or any other location but YMMV)
-- v3.3   2021-11-01 JMS Added functions noRulesSpecified() and thisRuleSpecified for use in config file
-- v4.0   2022-03-20 JMS Re-design configFile, now only supporting rsync and robocopy
-- v4.0.1 2022-04-09 JMS Install improvements
-- v4.0.2 2022-04-16 JMS Less worrying about return codes
-- v4.1   2024-03-03 JMS Don't distribute Windows binaries
-- v4.2   2024-10-20 JMS expression must be specified. Due to how Lua evaluates 'false', it's the same as not being specified
-- v4.3   2024-10-30 JMS Major re-work, again :-)

local multisync_version = '4.3 2024-10-30'
local copyright = 'Copyright (c) 2024 Jeff Stone'

-- These will fail if not found but the alternative isn't much better
lfs = require 'lfs'
luasql = require 'luasql.sqlite3'
argparse = require 'argparse'
file = require 'pl.file'
path = require 'pl.path'
tablex = require 'pl.tablex'
utils = require 'pl.utils'

-- Similar to path.isdir() and path.isfile(), but defined for use in the config file
function isDir(filespec)
  return (path.attrib(filespec, 'mode') == 'directory')
end

function isFile(filespec)
  return (path.attrib(filespec, 'mode') == 'file')
end

-- Another function for use in config file, typically for use in Post routine to copy the database
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

-- Use a function to determine if two filespecs point to the same file
-- In Windows, filespecs are not case-sensitive but they are in Linux
function isSameFilespec(filespec1, filespec2)
  if path.is_windows then
    return(string.upper(filespec1) == string.upper(filespec2))
  else
    return(filespec1 == filespec2)
  end
end

function replaceEnvironmentVariables(str)
  if not path.is_windows then
    str = string.gsub(str, '~', os.getenv('HOME'))
  end
  return string.gsub(string.gsub(str, '{computername}', computerName), '{username}', userName)
end

-- Reference: https://www.gammon.com.au/scripts/doc.php?lua=dofile
function myDofile(fileName)
  local f, err = loadfile(fileName)
  if f then
    return f()
  else
    print(err)
  end
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

--[[
  Main begins here
--]]

dbFilename = 'multi-sync.sqlite3'
configFilename = 'multi-sync-config.lua'
computerName, userName, configDir = os.getenv('COMPUTERNAME'), os.getenv('USERNAME'), os.getenv('CONFIGDIR')
if (not computerName) or (not userName) or (not configDir) then
  print('Set environment variables COMPUTERNAME, USERNAME and CONFIGDIR prior to calling Lua')
  os.exit(2)
end
dbFile = path.join(configDir, dbFilename)
configFile = path.join(configDir, configFilename)
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
        --local file = io.popen('lua -v'); print(file:read())
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
  -- Windows file systems aren't case-sensitive so the database that keeps track shouldn't be either, use 'collate nocase' for src and dest
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
if pre and type(pre) == 'string' then
  local func, err = load(replaceEnvironmentVariables(pre))
  if func then
    pcall(func)
  else
    print('\nCompilation error in pre:', err)
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
    if (expression == nil) then
      expression = true
    else
      if type(expression) ~= 'string' or expression == '' then
        expression = true
      else
        -- Convert it to a boolean
        expression = load('return('..replaceEnvironmentVariables(expression)..')')()
      end
    end
    src = rule.src
    if type(src) ~= 'string' or src == '' then
      src = nil
    else
      src = replaceEnvironmentVariables(src)
    end
    dest = rule.dest
    if type(dest) ~= 'string' or dest == '' then
      dest = nil
    else
      dest = replaceEnvironmentVariables(dest)
    end
    -- Evaluate the rule
    if name and (tablex.size(args.names) ~= 0) and (not tablex.find(args.names, name)) then
      if args.verbose then
        printRule(name, rule.expression, src, dest)
        print('\nRule skipped because of name')
      end
      do break end
    end
    if expression == false then
      if args.verbose then
        printRule(name, rule.expression, src, dest)
        print('\nRule skipped because of expression')
      end
      do break end
    end
    if src == nil then
      if args.verbose then
        printRule(name, rule.expression, src, dest)
        print('\nRule skipped because src is nil')
      end
      do break end
    else
      if (not path.isdir(src)) and (not path.isfile(src)) then
        if args.verbose then
          printRule(name, rule.expression, src, dest)
          print('\nRule skipped because src does not exist')
        end
        do break end
      end
    end
    if dest == nil then
      if args.verbose then
        printRule(name, rule.expression, src, dest)
        print('\nRule skipped because dest is nil')
      end
      do break end
    else
      if (not path.isdir(dest)) or isSameFilespec(src, dest) then
        if args.verbose then
          printRule(name, rule.expression, src, dest)
          print('\nRule skipped because dest does not exist or is the same as src')
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
if post and type(post) == 'string' then
  local func, err = load(replaceEnvironmentVariables(post))
  if func then
    pcall(func)
  else
    print('\nCompilation error in post:', err)
  end
end

-- Close everything
db:close()
env:close()
os.exit()
