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

-- Can't use _VERSION since that's used by Lua
local version = "3.1"

-- These will fail if not found but the alternative isn't much better
local lfs = require "lfs"
local luasql = require "luasql.sqlite3"
local argparse = require "argparse"
local file = require "pl.file"
local path = require "pl.path"
local tablex = require "pl.tablex"
local utils = require "pl.utils"

-- Similar to path.isdir() and path.isfile(), but defined for use in the config file
function isDir(filespec)
  return (path.attrib(filespec, "mode") == "directory")
end

function isFile(filespec)
  return (path.attrib(filespec, "mode") == "file")
end

-- Another function defined for use in the config file
function copyFile(src, dest)
  if path.isdir(dest) then
    file.copy(src, dest)
  else
    print("\ncopyFile requires dest to be an existing directory")
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
  -- Likely good enough proxy for Linux 
  if os.getenv("HOME") then
    str = string.gsub(str, "~", os.getenv("HOME"))
  end
  return string.gsub(string.gsub(str, "{computername}", computerName), "{username}", userName)
end

function crlf()
  print("")
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
function printRule(name, expression, src, dest, cmd, cmdSyntax, actualCmd)
  -- formatString works like C sprintf, -12 indicates the field is 12 characters wide and left-justified
  local formatString = "%-12s  %s"
  if name then print(string.format(formatString, "name", name)) end
  if expression then print(string.format(formatString, "expression", expression)) end
  if src then print(string.format(formatString, "src", src)) end
  if dest then print(string.format(formatString, "dest", dest)) end
  if cmd then print(string.format(formatString, "cmd", cmd)) end
  if cmdSyntax then print(string.format(formatString, "cmdSyntax", cmdSyntax)) end
  if actualCmd then print(string.format(formatString, "actualCmd", actualCmd)) end
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
  local cur = executeSQL(db, string.format("select datetime(utc, 'localtime') as timestamp, rc from sync_history where src='%s' and dest='%s'", src, dest))
  local row = cur:fetch({}, "a")
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
    local formatString = "%-"..maxlen[1].."s  %-"..maxlen[2].."s  %-"..maxlen[3].."s  %-"..maxlen[4].."s  %-"..maxlen[5].."s"
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

--[[
    Main begins here
--]]

multisync = "multi-sync"
local dbFilename = multisync..".sqlite3"
local configFilename = multisync.."-config.lua"

-- This basically forces user to use the correct entry point (.bat or Bash)
computerName, userName = os.getenv("COMPUTERNAME"), os.getenv("USERNAME")
local configDir = os.getenv("CONFIGDIR")
if (not computerName) or (not userName) or (not configDir) then
  print("Set environment variables COMPUTERNAME, USERNAME and CONFIGDIR prior to calling Lua")
  os.exit(2)
end

env = luasql.sqlite3()
local parser = argparse()
  :name "multi-sync"
  :description "Rules-based script for using rsync, robocopy or other tool to automate backups"
  -- https://opensource.org/licenses/MIT
  :epilog [[Copyright (c) 2018-2020 Jeff Stone

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.]]

parser:flag "-n" "--dry-run"
  :description "Output the final command(s), do not execute"
  :target "dryRun"
parser:flag "-d" "--debug"
  :description "Debug mode, display more information"
  :target "debug"
parser:mutex(
  parser:flag "-c" "--configure"
    :description "Configure rules"
    :target "configure",
  parser:flag "-i" "--initialize"
    :description "Initialize the database"
    :target "initialize",
  parser:flag "-l" "--list"
    :description "List files which would be copied"
    :target "list", 
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
        print("\n"..multisync.." "..version)
        print(_VERSION)
        print(lfs._VERSION)
        print(luasql._VERSION)
        local db = env:connect(":memory:")
        local cur = executeSQL(db, "select 'SQLite '||sqlite_version()")
        print(cur:fetch())
        cur:close()
        db:close()
        env:close()
        -- In case argparse makes the change suggested here https://github.com/mpeterv/argparse/issues/21
        print("argparse "..argparse.version)
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
dbFile = path.join(configDir, dbFilename)
configFile = path.join(configDir, configFilename)
local db

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
      print("\nprint-history argument must specify multi-sync.sqlite3 or a directory containing it")
    end
  end
  if dbFile then
    print("\nPrinting sync history from "..dbFile)
    db = env:connect(dbFile)
    printHistory(db)
    db:close()
  end
  os.exit(0)
end

-- Process -f
if args.forget then
  db = env:connect(dbFile)
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

-- Process configFile
myDofile(configFile) -- Good possibility of a syntax error in configFile, so handle it more gracefully than Lua's dofile()
if not rules or not textEditor then
  print("\nSyntax error in configFile, rules and textEditor must be specified")
  os.exit(2)
end

-- Process -c
if args.configure then
  if path.isfile(configFile) then
    os.execute(textEditor.." "..configFile)
  end
  os.exit(0)
end

db = env:connect(dbFile)

-- Process -i
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

-- Pre routine
if pre then
  local func, err = load(replaceEnvironmentVariables(pre))
  if func then
    pcall(func)
  else
    print("\nCompilation error in pre:", err)
  end
end

-- Process rules
local exitRC
for i, rule in pairs(rules) do
  -- NQ "no quotes" versions of src and dest
  local srcNQ, destNQ
  -- Evaluate the rule
  name = rule.name
  if name == "" then name = nil end
  expression = rule.expression
  if expression == "" then expression = nil end
  if expression then expression = replaceEnvironmentVariables(expression) end
  src = rule.src
  if src == "" then src = nil end
  if src then
    src = replaceEnvironmentVariables(src)
    srcNQ = src
    if string.find(src, " ") then src=[["]]..src..[["]] end
  end
  dest = rule.dest
  if dest == "" then dest = nil end
  if dest then
    dest = replaceEnvironmentVariables(dest)
    destNQ = dest
    if string.find(dest, " ") then dest=[["]]..dest..[["]] end
  end
  -- Get these from the rule or the defaults
  if args.list then
    cmd = rule.listCmd and rule.listCmd or listCmd
  else
    cmd = rule.syncCmd and rule.syncCmd or syncCmd
  end
  if cmd == "" then cmd = nil end
  cmdSyntax = rule.cmdSyntax and rule.cmdSyntax or cmdSyntax
  if cmdSyntax == "" then cmdSyntax = nil end
  if src and dest then
    if not isSameFilespec(srcNQ, destNQ) then
      if cmd and cmdSyntax then
        local actualCmd = load("return("..cmdSyntax..")")()
        if path.isdir(srcNQ) or path.isfile(srcNQ) then
          if path.isdir(destNQ) then
            if (tablex.size(args.cmdLineNames) == 0) or (name and tablex.find(args.cmdLineNames, name)) then
              if not expression or load("return("..string.gsub(expression, "\\", "\\\\")..")")() then
                crlf()
                if not args.dryRun then
                  local handler = io.popen(actualCmd)
                  local stdout = handler:read("*a")
                  local dummy, err, rc = handler:close()
                  if debug then
                    printRule(name, expression, src, dest, nil, nil, actualCmd)
                  else
                    printRule(nil, nil, src, dest, nil, nil, actualCmd)
                  end
                  if string.len(stdout) ~= 0 or rc ~= 0 then
                  end
                  if string.len(stdout) ~= 0 then print("\n"..stdout) end
                  if rc ~= 0 then
                    print("rc = "..rc)
                    print(err)
                    exitRC = 1
                  end
                  if not args.list then executeSQL(db, string.format("insert or replace into sync_history (src, dest, utc, rc) values('%s', '%s', datetime('now'), '%d')", src, dest, rc)) end
                else
                  printRule(nil, nil, src, dest, nil, nil, actualCmd)
                end
                lastSync(db, src, dest)
              else
                if args.debug then
                  crlf();
                  printRule(name, expression, src, dest)
                  print("\nRule skipped because of expression")
                end
              end
            else
              if args.debug then
                crlf();
                printRule(name, expression, src, dest)
                print("\nRule skipped because of name")
              end
            end
          else
            if args.debug then
              crlf();
              printRule(name, expression, src, dest)
              print("\nRule skipped because dest does not exist")
              lastSync(db, src, dest)
            end
          end
        else
          if args.debug then
            crlf()
            printRule(name, expression, src, dest)
            print("\nRule skipped because src does not exist")
            lastSync(db, src, dest)
          end
        end
      else
        -- This is a config issue, should always be displayed
        crlf()
        printRule(name, expression, src, dest, cmd, cmdSyntax)
        print("\nRule skipped because cmd and/or cmdSyntax are nil")
      end
    else
      -- This is a config issue, should always be displayed
      crlf()
      printRule(name, expression, src, dest)
      print("\nRule skipped because src and dest are the same")
    end
  else
    -- This is a config issue, should always be displayed
    crlf()
    printRule(name, expression, src, dest)
    print("\nRule skipped because src and/or dest are not specified")
  end
end --for

-- Post routine
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
