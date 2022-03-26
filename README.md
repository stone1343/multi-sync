# *multi-sync*

Rule-driven synchronization for Windows and Linux
 
To install in Linux:
* cd
* git clone https://github.com/stone1343/multi-sync.git
* cd multi-sync
* sudo ./install /usr/local

or

* ./install ~/.local
* cd ..
* rm -rf multi-sync

To install in Windows
* Download .zip from https://github.com/stone1343/multi-sync
* Unzip the .zip
* In Command Prompt, cd to the multi-sync directory
* Use install.bat to install it, must specify a directory, for example you could use %USERPROFILE%\bin
  * install %USERPROFILE%\bin

multi-sync is controlled by a config file, which is literally a Lua script, here's a sample:

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
