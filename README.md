# *multi-sync*

Rule-driven synchronization for Linux and Windows

## Linux

To install pre-reqs in Ubuntu-based Linux, using current versions as of 2024-10-26:

```bash
# Install Lua 5.4, SQLite, other pre-reqs
sudo apt install build-essential libreadline-dev git lua5.4 liblua5.4-dev sqlite3 libsqlite3-dev

# Install LuaRocks 3.11.1 (or check for newer)
cd ~/Downloads
[ -d luarocks-3.11.1 ] && rm -rf luarocks-3.11.1
[ -f luarocks-3.11.1.tar.gz ] && rm luarocks-3.11.1.tar.gz
wget https://luarocks.org/releases/luarocks-3.11.1.tar.gz
tar xf luarocks-3.11.1.tar.gz
cd luarocks-3.11.1
./configure --lua-version=5.4
make
sudo make install
# Install required rocks
# Due to https://githubhot.com/repo/keplerproject/luasql/issues/136, currently need to patch the LuaSQL rockspec
cd ~/Downloads
[ -f luasql-sqlite3-2.6.0-1.rockspec ] && rm luasql-sqlite3-2.6.0-1.rockspec
wget https://luarocks.org/manifests/tomasguisasola/luasql-sqlite3-2.6.0-1.rockspec
sed -i 's/url = "git:/url = "git+https:/g' luasql-sqlite3-2.6.0-1.rockspec
sudo luarocks install luasql-sqlite3-2.6.0-1.rockspec
sudo luarocks install luafilesystem
sudo luarocks install argparse
sudo luarocks install penlight
```

Install multi-sync v4.3

```bash
cd ~/Downloads
[ -d multi-sync-4.3 ] && rm -rf multi-sync-4.3
git clone --depth 1 --branch v4.3 https://github.com/stone1343/multi-sync.git multi-sync-4.3
if [ -d "multi-sync-4.3" ]; then
  cd multi-sync-4.3
  sudo ./install
  cd ..
  rm -rf multi-sync-4.3
fi
```

Assuming your backup drive is mounted at /media/$USER/backup, you can create a directory and you should be ready to go:

```bash
sudo mkdir -p /media/$USER/backup/$HOSTNAME/home
```

## Windows

Install multi-sync v4.3 to %USERPROFILE%\bin

```
cd %USERPROFILE%\Downloads
if exist multi-sync-4.3\. rmdir /s /q multi-sync-4.3
git clone --depth 1 --branch v4.3 https://github.com/stone1343/multi-sync.git multi-sync-4.3
cd multi-sync-4.3
call install %USERPROFILE%\bin
cd ..
rmdir /s /q multi-sync-4.3
```

## Config file

* Each rule must define:
  * src - a directory or a file
  * dest - a directory

* And optionally:
  * name - rule name, does not need to be unique
  * expression - evaluated as a boolean, so anything other than false is true. If false, the rule will be skipped
  * options - additional options for robocopy (Windows) or rsync (Linux)

  In expression, src, dest, pre and post, {computername} and {username} will be replaced with the actual computername and username.

  Windows filespecs use [[]] because otherwise \ would be interpreted as an escape character.

### Sample Linux config file

```lua
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

post = [[
  if isDir('/media/{username}/backup/{computername}/home/{username}/.config/') then
    copyFile(dbFile, '/media/{username}/backup/{computername}/home/{username}/.config/')
  end
]]
```

### Sample Windows config file

```lua
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
    src  = [[C:\Users\{username}\Videos]],
    dest = [[E:\backup\{computername}\{username}\Videos]]
  },
}

post = [=[
  if isDir([[E:\backup\{computername}\{username}\AppData\Local]]) then
    copyFile(dbFile, [[E:\backup\{computername}\{username}\AppData\Local]])
  end
]=]
```