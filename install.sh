#!/usr/bin/env bash

INSTALL_DIR=$HOME/.multi-sync
BIN_DIR=$HOME/bin
CONFIG_DIR=$HOME/.config
LUA=lua-5.3.5
LFS=luafilesystem-1_7_0_2
SQLITE3=sqlite-amalgamation-3260000
LUASQL=luasql-2.4.0

# Pre-reqs
#sudo apt install build-essential libreadline-dev libtinfo-dev libtool-bin unzip

# Get source code
#wget https://www.lua.org/ftp/lua-5.3.5.tar.gz
#wget https://github.com/keplerproject/luafilesystem/archive/v1_7_0_2.tar.gz
#wget https://github.com/stevedonovan/Penlight/archive/1.6.0.tar.gz
#wget https://github.com/mpeterv/argparse/archive/0.6.0.tar.gz
#wget https://www.sqlite.org/2018/sqlite-amalgamation-3250200.zip
#wget https://github.com/keplerproject/luasql/archive/v2.3.5.tar.gz

# Do manually
#git clone ssh://stone1343@git.code.sf.net/p/multi-sync/code multi-sync
#cd multi-sync

if [ ! -d $LUA ]; then
  tar xf $LUA.tar.gz
fi
cd $LUA
make linux
cd ..
if [ ! -f $LUA/src/lua ]; then
  echo "Lua was not built"
  exit
fi

if [ ! -d $LFS ]; then
  tar xf $LFS.tar.gz
fi
cd $LFS
# Don't use the makefile, just compile by hand
if [ ! -f src/lfs.so ]; then
  gcc -O2 -Wall -fPIC -W -Waggregate-return -Wcast-align -Wmissing-prototypes -Wnested-externs -Wshadow -Wwrite-strings -pedantic -I../$LUA/src   -c -o src/lfs.o src/lfs.c
  gcc -shared  -o src/lfs.so src/lfs.o
fi
cd ..
if [ ! -f $LFS/src/lfs.so ]; then
  echo "LuaFileSystem was not built"
  exit
fi

if [ ! -d $SQLITE3 ]; then
  unzip $SQLITE3.zip
fi
cd $SQLITE3
if [ ! -f sqlite3 ]; then
  gcc -O2 -DSQLITE_THREADSAFE=0 -DSQLITE_OMIT_LOAD_EXTENSION shell.c sqlite3.c -o sqlite3
fi
cd ..
if [ ! -f $SQLITE3/sqlite3 ]; then
  echo "SQLite3 was not built"
  exit
fi

if [ ! -d $LUASQL ]; then
  tar xf $LUASQL.tar.gz
fi
cd $LUASQL/src
if [ ! -f sqlite3.h ]; then
  cp ../../$SQLITE3/sqlite3.h .
fi
if [ ! -f sqlite3.c ]; then
  cp ../../$SQLITE3/sqlite3.c .
fi
if [ ! -f sqlite3.so ]; then
  gcc -O2 -shared -pedantic -fPIC -Wall -Wmissing-prototypes -Wmissing-declarations -DSQLITE_THREADSAFE=0 -DSQLITE_OMIT_LOAD_EXTENSION -I../..//$LUA/src -DLUASQL_VERSION_NUMBER='"2.3.5"' luasql.c ls_sqlite3.c sqlite3.c -o sqlite3.so
fi
cd ../..

# Copying executables that were just built
[ ! -d $INSTALL_DIR/pl ] && mkdir -p $INSTALL_DIR/pl
[ ! -d $INSTALL_DIR/luasql ] && mkdir $INSTALL_DIR/luasql
yes | cp $LUA/src/lua $INSTALL_DIR
yes | cp $LFS/src/lfs.so $INSTALL_DIR
yes | cp $SQLITE3/sqlite3 $INSTALL_DIR
yes | cp $LUASQL/src/sqlite3.so $INSTALL_DIR/luasql

# Copying executables as distributed
yes | cp argparse.lua $INSTALL_DIR
yes | cp -r pl/* $INSTALL_DIR/pl
yes | cp linux/multi-sync $INSTALL_DIR
yes | cp linux/multi-sync-config.lua $INSTALL_DIR
yes | cp multi-sync.lua $INSTALL_DIR
chmod +x $INSTALL_DIR/multi-sync

# Now install multi-sync in ~/bin as a symbolic link
[ ! -d $BIN_DIR ] && mkdir -p $BIN_DIR
[ -f $BIN_DIR/multi-sync ] && rm $BIN_DIR/multi-sync
ln -s $INSTALL_DIR/multi-sync $BIN_DIR/multi-sync
# If lua and sqlite3 don't exist in ~/bin, make symbolic links for them too
[ ! -f $BIN_DIR/lua ] && ln -s $INSTALL_DIR/lua $BIN_DIR/lua
[ ! -f $BIN_DIR/sqlite3 ] && ln -s $INSTALL_DIR/sqlite3 $BIN_DIR/sqlite3

# Finally, create the .config directory if it doesn't exist
[ ! -d $CONFIG_DIR ] && mkdir $CONFIG_DIR
