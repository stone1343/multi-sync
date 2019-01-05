-- v1.0   2016-10-01 JMS
-- v1.0.1 2016-10-04 JMS Enhanced customizability and usability
-- v1.0.2 2016-10-06 JMS More enhanced customizability and usability
-- v1.1   2016-10-23 JMS {computername} and {username} in -config files, so less customization required
-- v1.1.1 2016-10-25 JMS When outputting 'Latest successful sync', also output if the rule has never been synced
-- v1.1.2 2016-10-27 JMS Bugfix, cmd and options must be global
-- v1.2   2016-10-30 JMS List files modified since last sync
-- v1.2.1 2016-10-31 JMS Move the "list files modified since last sync" code to where it can also run if dest doesn't exist
-- v1.2.2 2016-12-17 JMS Tolerate null attr from Google Drive
-- v1.2.3 2017-05-13 JMS Added --version flag, including Lua and library versions
--        2017-06-05 JMS Handle syntax error(s) in multi-sync-config.lua more gracefully, fairly significant re-structuring
-- v1.3   2017-09-20 JMS Various enhancements, code merge
-- v2.0   2017-10-15 JMS "Dry Run" just outputs the final command(s) without executing anything
--                       Name and expression are optional; cmd, options, cmd_syntax and rules are not
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
--        2019-01-05 JMS Patch to output Lua release, e.g. 5.3.5, without hardcoding it here

local version = "multi-sync 2.3"

-- These will fail if not found but the alternative isn't much better
local luasql = require "luasql.sqlite3"
local lfs = require "lfs"
local file = require "pl.file"
local path = require "pl.path"
local tablex = require "pl.tablex"
local utils = require "pl.utils"
local argparse = require "argparse"

function isdir(filespec)
  return (path.attrib(filespec, "mode") == "directory")
end

function isfile(filespec)
  return (path.attrib(filespec, "mode") == "file")
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

--[[
function formatAsLocalTime(utc)
  local localTime = os.date("*t", utc)
  return string.format("%04d-%02d-%02d %02d:%02d:%02d", localTime.year, localTime.month, localTime.day, localTime.hour, localTime.min, localTime.sec)..((localTime.isdst) and " DST" or "")
end
]]

function replaceEnvironmentVariables(str)
  return string.gsub(string.gsub(str, "{computername}", computerName), "{username}", userName)
end

function crlf()
  print("")
end

function pause()
  io.write("\nPress [Enter] to continue...")
  io.read()
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
function printRule(name, expression, src, dest, cmd, cmd_syntax, actual_cmd)
  -- formatString works like C sprintf, -12 indicates the field is 12 characters wide and left-justified
  local formatString = "%-12s  %s"
  if name then print(string.format(formatString, "name", name)) end
  if expression then print(string.format(formatString, "expression", expression)) end
  if src then print(string.format(formatString, "src", src)) end
  if dest then print(string.format(formatString, "dest", dest)) end
  if cmd then print(string.format(formatString, "cmd", cmd)) end
  if cmd_syntax then print(string.format(formatString, "cmd_syntax", cmd_syntax)) end
  if actual_cmd then print(string.format(formatString, "actual_cmd", actual_cmd)) end
end

-- A function to execute SQL statement and exit if it fails
function executeSQL(db, SQL)
  local cur, err = db:execute(SQL)
  if not cur then
    print(string.format("SQL failed\n %s%s", SQL, err and "\n"..err))
    db:close()
    env:close()
    os.exit(2)
  end
  return cur
end

function lastSync(db, src, dest)
  -- Display the info in the database, there will only ever be zero or one record(s) due to constraint
  --local cur = executeSQL(db, string.format("select utc, rc from sync_history where src='%s' and dest='%s'", src, dest))
  local cur = executeSQL(db, string.format("select datetime(utc, 'localtime') as timestamp, rc from sync_history where src='%s' and dest='%s'", src, dest))
  local row = cur:fetch({}, "a")
  --print("\nLast sync: "..(row and (formatAsLocalTime(row.utc)..", rc = "..row.rc) or "never"))
  print("\nLast sync: "..(row and (row.timestamp..", rc = "..row.rc) or "never"))
  cur:close()
end

-- Seems much more complicated than necessary, but it works
function printHistory(db, rowid)
  local headers = {"rowid", "src", "dest", "timestamp", "rc"}
  local n = 0
  local rows = {}
  local maxlen = {0, 0, 0, 0, 0}
  for i = 1, 5 do
    maxlen[i]= math.max(maxlen[i], string.len(headers[i]))
  end
  local cur = executeSQL(db, string.format("select rowid, src, dest, datetime(utc, 'localtime'), rc from sync_history %s order by rowid;", rowid and " where rowid="..rowid))
  -- Could use
  --  row, err = cur:fetch({})
  -- with a fetcher function but in my experience this never fails
  local row = cur:fetch({})
  while row do
    n = n + 1
    rows[n] = {}
    for i = 1, 5 do
      --[[
      if i == 4 then
        rows[n][i] = formatAsLocalTime(row[i])
      else
        rows[n][i] = row[i]
      end
      ]]
      rows[n][i] = row[i]
      maxlen[i] = math.max(maxlen[i], string.len(rows[n][i]))
    end
    row = cur:fetch(row)
  end
  cur:close()
  if n > 0 then
    local fiveBytes = "s  %-"
    local formatString = "%-"..maxlen[1]..fiveBytes..maxlen[2]..fiveBytes..maxlen[3]..fiveBytes..maxlen[4]..fiveBytes..maxlen[5].."s"
    -- Print the header
    print(string.format("\n"..formatString, headers[1], headers[2], headers[3], headers[4], headers[5]))
    print(string.rep("-", maxlen[1]).."  "..string.rep("-", maxlen[2]).."  "..string.rep("-", maxlen[3]).."  "..string.rep("-", maxlen[4]).."  "..string.rep("-", maxlen[5]))
    -- Print the data
    for i = 1, n do
      print(string.format(formatString, rows[i][1], rows[i][2], rows[i][3], rows[i][4], rows[i][5]))
    end
  else
    if rowid then
      print("\nNo rowid "..rowid)
    else
      print("\nNo sync history")
    end
  end
  return n
end

function copyFile(src, dest)
  if path.isdir(dest) then
    file.copy(src, dest)
  else
    print("\ncopyFile requires dest to be an existing directory")
  end
end

--[[
    Main begins here
--]]

-- This basically forces user to run via the caller (.bat or Bash)
computerName, userName = os.getenv("MS_COMPUTERNAME"), os.getenv("MS_USERNAME")
local appData, editor = os.getenv("MS_APPDATA"), os.getenv("MS_EDITOR")
if (not computerName) or (not userName) or (not appData) or (not editor) then
  print("Set environment variables MS_COMPUTERNAME, MS_USERNAME, MS_APPDATA and MS_EDITOR prior to calling Lua")
  os.exit(2)
end

env = luasql.sqlite3()
local parser = argparse()
  :name "multi-sync"
  :description "Rule-based script for using rsync or other tool to automate multiple backups"
  -- https://opensource.org/licenses/MIT
  :epilog [[Copyright (c) 2018-2019 Jeff Stone

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.]]

parser:flag "-d" "--debug"
  :description "Debug mode, output more information"
  :target "debug"
parser:flag "-n" "--dry-run"
  :description "Output the final command(s), do not execute"
  :target "dryRun"
parser:flag "-l" "--list"
  :description "List files which would be copied"
  :target "list"
parser:flag "-m" "--mkdir"
  :description "If dest directory does not exist, attempt to create it"
  :target "mkdir"
parser:mutex(
  parser:flag "-c" "--configure"
    :description "Configure rules"
    :target "configure",
  parser:flag "-i" "--initialize"
    :description "Initialize the database"
    :target "initialize",
  parser:flag "-p" "--print-history"
    :description "Print sync history"
    :target "printHistory"
    :args("?"),
  parser:option "-f" "--forget"
    :description "Forget row(s) of sync history"
    :target "forget"
    :args("+"),
  parser:flag "-v" "--version"
    :description "Output version information and exit"
    :action(
      function()
        print("\n"..version)
        print(_VERSION)
        print(lfs._VERSION)
        print(luasql._VERSION)
        local db = env:connect(":memory:")
        local cur = executeSQL(db, "select 'SQLite '||sqlite_version()")
        print(cur:fetch())
        cur:close()
        db:close()
        env:close()
        print("argparse "..argparse._VERSION)
        print("Penlight "..utils._VERSION)
        os.exit(0)
      end
    )
)
parser:argument "names"
  :args("*")
  :description "Specify rule(s) to run by name. May specify zero, one or more names"
  :target "cmdLineNames"

local args = parser:parse()
local filePath, fileName, fileExt
filePath, fileName = path.splitpath(arg[0])
fileName, fileExt = path.splitext(fileName)
dbFile = path.join(appData, fileName..".sqlite3")
config = path.join(appData, fileName.."-config.lua")
local db

if args.debug then
  local formatString = "%-12s  %s"
  print(string.format("\n"..formatString, "computerName", computerName))
  print(string.format(formatString, "userName", userName))
  print(string.format(formatString, "appData", appData))
  print(string.format(formatString, "editor", editor))
  print(string.format(formatString, "dbFile", dbFile))
  print(string.format(formatString, "config", config))
end

-- Process -c (assumed first time)
if not path.exists(config) then
  file.copy(path.join(filePath, fileName.."-config.lua"), config)
  args.configure = true
end
if args.configure then
  if path.isfile(config) then
    os.execute(editor.." "..config)
  end
  os.exit(0)
end

-- Process -p
if args.printHistory then
  if args.printHistory[1] then
    local dbArgument = path.join(args.printHistory[1], fileName..".sqlite3")
    if isfile(dbArgument) then
      print("\nPrinting sync history from "..dbArgument)
      dbFile = dbArgument
    else
      print("\nprint-history argument must a directory containing "..fileName..".sqlite3")
      dbFile = nil
    end
  end
  if dbFile then
    db = env:connect(dbFile)
    printHistory(db)
    db:close()
  end
  os.exit(0)
end

-- Process -i (assumed first time)
if not path.exists(dbFile) then
  args.initialize = true
end
db = env:connect(dbFile)
if args.initialize then
  -- This one can't use executeSQL because it is guaranteed to fail the first time since the table doesn't exist
  db:execute("drop table sync_history")
  -- Windows file systems aren't case-sensitive so the database that keeps track shouldn't be either, use "collate nocase" for src and dest
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
end

-- Process -f
if args.forget then
  for i = 1, tablex.size(args.forget) do
    local f = tonumber(args.forget[i])
    if f then
      if printHistory(db, f) == 1 then
        executeSQL(db, "delete from sync_history where rowid="..f)
        print("Deleted rowid "..f)
      end
    else
      print("\nIgnoring non-numeric "..args.forget[i])
    end
  end
  db:close()
  os.exit(0)
end

-- Process config
myDofile(config) -- Good possibility of a syntax error in config, so handle it more gracefully than Lua's dofile()
if not rules then
  print("Syntax error in config, rules must be specified")
  db:close()
  os.exit(2)
end

if pre then
  local func, err = load(replaceEnvironmentVariables(pre))
  if func then
    pcall(func)
  else
    print("\nCompilation error in pre:", err)
  end
end

-- Process rules
local exitRC, default_cmd, default_list_cmd, default_cmd_syntax = 0, cmd, list_cmd, cmd_syntax
for i, rule in pairs(rules) do
  local pauseFlag = False
  -- Evaluate the rule
  name = rule.name
  if name == "" then name = nil end
  expression = rule.expression
  if expression == "" then expression = nil end
  if expression then expression = replaceEnvironmentVariables(expression) end
  src = rule.src
  if src == "" then src = nil end
  if src then src = replaceEnvironmentVariables(src) end
  dest = rule.dest
  if dest == "" then dest = nil end
  if dest then dest = replaceEnvironmentVariables(dest) end
  -- Get these from the rule or the defaults
  if args.list then
    cmd = rule.list_cmd and rule.list_cmd or default_list_cmd
  else
    cmd = rule.cmd and rule.cmd or default_cmd
  end
  if cmd == "" then cmd = nil end
  cmd_syntax = rule.cmd_syntax and rule.cmd_syntax or default_cmd_syntax
  if cmd_syntax == "" then cmd_syntax = nil end
  -- Print everything but the actual command
  if args.debug then crlf(); printRule(name, expression, src, dest, cmd, cmd_syntax) end
  if src and dest then
    -- NQ "no quotes" versions of src and dest
    local srcNQ, destNQ = src, dest
    -- If src and/or dest have spaces, add quotes for commands
    if string.find(src, " ") then src=[["]]..src..[["]] end
    if string.find(dest, " ") then dest=[["]]..dest..[["]] end
    if (tablex.size(args.cmdLineNames) == 0) or (name and tablex.find(args.cmdLineNames, name)) then
      -- Also have to double up \
      if not expression or load("return("..string.gsub(expression, "\\", "\\\\")..")")() then
        if cmd and cmd_syntax then
          local actual_cmd = load("return("..cmd_syntax..")")()
          -- Finally print the actual command
          if args.debug then printRule(nil, nil, nil, nil, nil, nil, actual_cmd) end
          if path.isdir(srcNQ) or path.isfile(srcNQ) then
            -- If dest directory doesn't exist, attempt to create it
            if args.mkdir and (not path.isdir(destNQ)) and (not path.isfile(destNQ)) then
              if path.is_windows then
                os.execute("mkdir "..dest)
              else
                os.execute("mkdir -p "..dest)
              end
            end
            -- If dest directory still doesn't exist, nothing we can do for this rule
            if path.isdir(destNQ) then
              if not isSameFilespec(srcNQ, destNQ) then
                if not args.debug then crlf(); printRule(nil, nil, src, dest) end
                if not args.dryRun then
                  local handler = io.popen(actual_cmd)
                  local data = handler:read("*a")
                  print("\n"..data)
                  local dummy, err, rc = handler:close()
                  print("rc = "..rc)
                  if rc ~= 0 then
                    print(err)
                    exitRC, pauseFlag = 1, True
                   end
                  if not args.list then executeSQL(db, string.format("insert or replace into sync_history (src, dest, utc, rc) values('%s', '%s', datetime('now'), '%d')", src, dest, rc)) end
                else
                  if not args.debug then printRule(nil, nil, nil, nil, nil, nil, actual_cmd) end
                  lastSync(db, src, dest)
                end
              else
                if not args.debug then crlf(); printRule(nil, nil, src, dest) end
                print("\nRule skipped because src and dest are the same")
                pauseFlag = True
              end
            else
              if not args.debug then crlf(); printRule(nil, nil, src, dest) end
              print("\nRule skipped because dest does not exist")
              lastSync(db, src, dest)
              pauseFlag = True
            end
          else
            if not args.debug then crlf(); printRule(nil, nil, src, dest) end
            print("\nRule skipped because src does not exist")
            lastSync(db, src, dest)
            pauseFlag = True
          end
        else
          -- There was a problem with the rule definition, print everything
          if not args.debug then crlf(); printRule(name, expression, src, dest, cmd, cmd_syntax) end
          print("\nRule skipped because cmd and/or cmd_syntax are nil")
          lastSync(db, src, dest)
          pauseFlag = True
        end
        -- Since we're in the loud part of the loop, if debug, make sure we pause
        if args.debug then pauseFlag = True end
      else
        if args.debug then
          print("\nRule skipped because of expression")
          pauseFlag = True
        end
      end
    else
      if args.debug then
        print("\nRule skipped because of name")
        pauseFlag = True
      end
    end
  else
    if not args.debug then crlf(); printRule(name, expression, src, dest) end
    print("\nRule skipped because src and/or dest are not specified")
    pauseFlag = True
  end
  if pauseFlag then
    pause()
  end
end

if post then
  local func, err = load(replaceEnvironmentVariables(post))
  if func then
    pcall(func)
  else
    print("\nCompilation error in post:", err)
  end
end

-- Close everything
db:close()
env:close()
os.exit(exitRC)
