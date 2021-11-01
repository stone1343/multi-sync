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

 multi-sync-config.lua

 Each rule must define:
  src - a directory or a file
  dest - a directory

 And optionally:
  name - rule name, does not need to be unique
  expression - evaluated as a boolean, so anything other than false and nil is true. If false, the rule will be skipped
  syncCmd
  listCmd
  cmdSyntax

 In expression, src and dest, {computername} and {username} will be replaced with the actual computername and username
 and ~ will be replaced with the value of $HOME

 For rsync to work as expected, all directories should include trailing /

]=]

textEditor = "editor"

-- Defaults, if these are not specified here, must be specified for every rule
-- -a, --archive   archive mode; equals -rlptgoD (no -H,-A,-X)
syncCmd = [[sudo rsync -qa --delete-before --exclude lost+found --exclude '.Trash-*']]
listCmd = [[sudo rsync -nva --delete-before --exclude lost+found --exclude '.Trash-*']]
-- FAT32, used for backing up a FAT32 volume, so ignore some subdirs
syncFAT32 = [[rsync -qrt --modify-window=2 --delete-before --exclude '$RECYCLE.BIN' --exclude 'System Volume Information' --exclude LOST.DIR]]
listFAT32 = [[rsync -nvrt --modify-window=2 --delete-before --exclude '$RECYCLE.BIN' --exclude 'System Volume Information' --exclude LOST.DIR]]
-- NTFS, used for backing up to an NTFS USB stick
syncNTFS = [[rsync -qrt --modify-window=2 --delete-before]]
listNTFS = [[rsync -nvrt --modify-window=2 --delete-before]]

cmdSyntax = [[cmd.." "..src.." "..dest]]

rules = {
  -- To backup
  {
    name = "home",
    src  = "/home/",
    dest = "/media/{username}/backup/{computername}/home/"
  },
  -- To backup2
  {
    name = "home",
    expression = "false", -- disabled
    src  = "/home/",
    dest = "/media/{username}/backup2/{computername}/home/"
  },
  {
    name = "images",
    expression = "thisRuleSpecified()", -- only by name, since it's so big
    src  = "/var/lib/libvirt/images/",
    dest = "/media/{username}/backup2/images/"
  },
  -- Backup fat32drv to backup
  {
    syncCmd = syncFAT32,
    listCmd = listFAT32,
    src  = "/media/{username}/fat32drv/",
    dest = "/media/{username}/backup/fat32drv/"
  },
  -- Copy some directories to ntfsdrv
  {
    name = "music",
    syncCmd = syncNTFS,
    listCmd = listNTFS,
    src  = "/files/music/",
    dest = "/media/{username}/ntfsdrv/files/music/"
  },
  {
    name = "pictures",
    syncCmd = syncNTFS,
    listCmd = listNTFS,
    src  = "/files/pictures/",
    dest = "/media/{username}/ntfsdrv/files/pictures/"
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

