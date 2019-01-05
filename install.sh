#!/usr/bin/env bash

INSTALL_DIR=$HOME/.multi-sync
CONFIG_DIR=$HOME/.config
BIN_DIR=$HOME/bin

# Note lua.h is patched below to include release
LUA=lua-5.3.5
LFS=luafilesystem-1_7_0_2
SQLITE3=sqlite-amalgamation-3260000
# Note luasql.c is patched below to correct the version
LUASQL=luasql-2.4.0

# Pre-reqs
#sudo apt install build-essential libreadline-dev libtinfo-dev libtool-bin unzip

if [ ! -d $LUA ]; then
  tar xf $LUA.tar.gz
  # Patch lua.h to include release, this can only be done once since LUA_VERSION_RELEASE is appended
  sed -i 's/#define LUA_VERSION\t"Lua " LUA_VERSION_MAJOR "." LUA_VERSION_MINOR/#define LUA_VERSION\t"Lua " LUA_VERSION_MAJOR "." LUA_VERSION_MINOR "." LUA_VERSION_RELEASE/g' $LUA/src/lua.h
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
  # Patch luasql.c to correct the version, see https://github.com/keplerproject/luasql/issues/102
  sed -i 's/LuaSQL 2.3.5/LuaSQL 2.4.0/g' $LUASQL/src/luasql.c
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

# Create the .config directory if it doesn't exist
[ ! -d $CONFIG_DIR ] && mkdir $CONFIG_DIR

# Finally install multi-sync in ~/bin if it exists
if [ -d $BIN_DIR ]; then
  yes | cp linux/bin/multi-sync $BIN_DIR
fi
