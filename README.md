# *multi-sync*

Rule-driven synchronization for Windows and Linux

## Linux

To install pre-reqs in Ubuntu-based Linux, using current versions as of 2022-04-01:

```bash
# Install Lua, SQLite, other pre-reqs
sudo apt install build-essential libreadline-dev unzip git lua5.4 liblua5.4-dev sqlite3 libsqlite3-dev

# Install LuaRocks 3.8.0 (or check for newer)
cd ~/Downloads
[ -d luarocks-3.8.0 ] && rm -rf luarocks-3.8.0
[ -f luarocks-3.8.0.tar.gz ] && rm luarocks-3.8.0.tar.gz
wget https://luarocks.org/releases/luarocks-3.8.0.tar.gz
tar xf luarocks-3.8.0.tar.gz
cd luarocks-3.8.0
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

Install multi-sync v4.1

```bash
cd ~/Downloads
[ -d multi-sync-4.1 ] && rm -rf multi-sync-4.1
git clone --depth 1 --branch v4.1 https://github.com/stone1343/multi-sync.git multi-sync-4.1
if [ -d "multi-sync-4.1" ]; then
  cd multi-sync-4.1
  sudo ./install
fi
```

Or install the latest and greatest

```bash
cd ~/Downloads
[ -d multi-sync ] && rm -rf multi-sync
git clone https://github.com/stone1343/multi-sync.git multi-sync
if [ -d "multi-sync" ]; then
  cd multi-sync
  sudo ./install
fi
```

Assuming your backup drive is mounted at /media/$USER/backup, you can create a directory and you should be ready to go:

```bash
sudo mkdir -p /media/$USER/backup/$HOSTNAME/home
```

### Default Linux config file

```lua
--[=[

  multi-sync-config.lua v4.1

  Each rule must define:
    src - a directory or a file
    dest - a directory

  And optionally:
    name - rule name, does not need to be unique
    expression - evaluated as a boolean, so anything other than false and nil is true. If false, the rule will be skipped
    notLinuxFilesystem - true for FAT, NTFS or other non-Linux filesystem
    options - additional rsync command line options, e.g. exclude

  In expression, src, dest, pre and post {computername} and {username} will be replaced with the actual computername and
  username and ~ will be replaced with the value of $HOME

  For rsync to work as expected, all directories should include trailing /

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

## Windows

Install multi-sync v4.1 to %USERPROFILE%\bin in Windows

```
pushd %USERPROFILE%\Downloads
if exist multi-sync-4.1.zip del multi-sync-4.1.zip
curl -L -o multi-sync-4.1.zip http://github.com/stone1343/multi-sync/archive/refs/tags/v4.1.zip
if exist multi-sync-4.1\. rmdir /s /q multi-sync-4.1
"C:\Program Files\7-Zip\7z" x multi-sync-4.1.zip
cd multi-sync-4.1
call install %USERPROFILE%\bin
popd
```

Or install the latest and greatest

```
pushd %USERPROFILE%\Downloads
if exist multi-sync.zip del multi-sync.zip
curl -L -o multi-sync-main.zip https://github.com/stone1343/multi-sync/archive/refs/heads/main.zip
if exist multi-sync-main\. rmdir /s /q multi-sync-main
"C:\Program Files\7-Zip\7z" x multi-sync-main.zip
cd multi-sync-main
call install %USERPROFILE%\bin
popd
```

### Default Windows config file

```lua
--[=[

  multi-sync-config.lua v4.1

  Each rule must define:
    src - a directory or a file
    dest - a directory

  And optionally:
    name - rule name, does not need to be unique
    expression - evaluated as a boolean, so anything other than false and nil is true. If false, the rule will be skipped
    options - additional robocopy options

  In expression, src and dest, {computername} and {username} will be replaced with the actual computername and username

  Windows filespecs use [[]] because otherwise \ would be interpreted as an escape character

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