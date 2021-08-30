#!/usr/bin/bash
CUR_DIR=$PWD
SERVICE_NAME=${SERVICE_NAME}
ROOT_DIR=${SERVICE_WORKING_DIR}
BIN_DIR=$ROOT_DIR/bin
APP_DIR=$ROOT_DIR/app

if [ $# -gt 0 ]
then
  NEW_SERVICE=$1
  NEW_SERVICE_PATH=$APP_DIR/$NEW_SERVICE
  if [ -f "$NEW_SERVICE_PATH" ]; then
    chmod +x $NEW_SERVICE_PATH
    rm -f ${BIN_DIR}/${SERVICE_NAME}
    ln -s $NEW_SERVICE_PATH ${BIN_DIR}/${SERVICE_NAME}
    echo
    echo $(ls -lt ${BIN_DIR}/${SERVICE_NAME})
  else
    echo "New app file ($NEW_SERVICE_PATH) not existed"
  fi
else
  echo "$SHELL_NAME <new service name>"
  echo "Lookup new service in $ROOT_DIR/app folder"
  echo "ex: "
  echo "$0 event-service-linux-amd64-0.8.4"
fi
