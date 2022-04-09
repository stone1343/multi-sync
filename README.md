# *multi-sync*

Rule-driven synchronization for Windows and Linux
 
To install in Ubuntu-based Linux, using current versions as of 2022-04-01:

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
# Install multi-sync v4.0.1
cd ~/Downloads
[ -d multi-sync-4.0.1 ] && rm -rf multi-sync-4.0.1
git clone --depth 1 --branch v4.0.1 https://github.com/stone1343/multi-sync.git multi-sync-4.0.1
if [ -d "multi-sync-4.0.1" ]; then
  cd multi-sync-4.0.1
  sudo ./install
fi
```

Install multi-sync v4.0.1 to %USERPROFILE%\bin in Windows

```
cd %USERPROFILE%\Downloads
if exist multi-sync-4.0.1.zip del multi-sync-4.0.1.zip
curl -L -o multi-sync-4.0.1.zip http://github.com/stone1343/multi-sync/archive/refs/tags/v4.0.1.zip
if exist multi-sync-4.0.1\. rmdir /s /q multi-sync-4.0.1
7z x multi-sync-4.0.1.zip
cd multi-sync-4.0.1
install %USERPROFILE%\bin
```

multi-sync is controlled by a config file, here's a sample:

```lua
--[=[

  multi-sync-config.lua v4.0

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
  -- To backup
  {
    name = 'home',
    src  = '/home/',
    dest = '/media/{username}/backup/{computername}/home/'
  },
  -- To backup2
  {
    name = 'home',
    expression = false, -- disabled
    src  = '/home/',
    dest = '/media/{username}/backup2/{computername}/home/'
  },
  {
    name = 'images',
    expression = '(name and tablex.find(args.cmdLineNames, name))', -- 'this rule specified', since it's so big
    src  = '/var/lib/libvirt/images/',
    dest = '/media/{username}/backup2/images/'
  },
  -- Backup fat32drv to backup
  {
    src  = '/media/{username}/fat32drv/',
    dest = '/media/{username}/backup/fat32drv/',
    notLinuxFilesystem = true
  },
  -- Copy some directories to ntfsdrv
  {
    name = 'music',
    src  = '/files/music/',
    dest = '/media/{username}/ntfsdrv/files/music/',
    notLinuxFilesystem = true
  },
  {
    name = 'pictures',
    src  = '/files/pictures/',
    dest = '/media/{username}/ntfsdrv/files/pictures/',
    notLinuxFilesystem = true
  }
}

post = [[
  if isDir('/media/{username}/backup/{computername}/home/{username}/.config/') then
    copyFile(dbFile, '/media/{username}/backup/{computername}/home/{username}/.config/')
  end
  if isDir('/media/{username}/backup2/{computername}/home/{username}/.config/') then
    copyFile(dbFile, '/media/{username}/backup2/{computername}/home/{username}/.config/')
  end
]]
```
