#!/usr/bin/env bash

INSTALL_DIR=$HOME/.multi-sync
CONFIG_DIR=$HOME/.config
BIN_DIR=$HOME/bin

if [ -f $INSTALL_DIR/multi-sync ]; then
  yes | cp linux/multi-sync $INSTALL_DIR
  yes | cp linux/multi-sync-config.lua $INSTALL_DIR
  yes | cp multi-sync.lua $INSTALL_DIR
  chmod +x $INSTALL_DIR/multi-sync
else
  echo $INSTALL_DIR/multi-sync does not exist, use install.sh instead
fi
