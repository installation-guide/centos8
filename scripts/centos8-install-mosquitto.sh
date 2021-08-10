#!/usr/bin/bash

###############
# Load common
###############
SCRIPT_DIR=$(dirname $0)
source "$SCRIPT_DIR/centos8-common.sh"

###############
# Execute
###############
if [ $# -ne 1 ]; then
  echo "$0: invalid input parameters ($#)"
  echo "Usage: $0 <envoy version>"
  echo "<envoy version>: 1.18.3, 1.19.0 ..."
  exit 1
fi
MOSQUITTO_VERSION=$1

SERVICE_NAME=mqtt
MOSQUITTO_SERVER=/usr/local/sbin/mosquitto
MOSQUITTO_CONF_FILE=/etc/mosquitto/mosquitto.conf


user_check_sudo
if [ $? -ne 0 ]; then
  echo "please login user with sudo permission"
  return 1
fi

## Create new folder if not exist
#[ ! -d $MOSQUITTO_HOME ] && { mkdir -p $MOSQUITTO_HOME; echo "create $MOSQUITTO_HOME"; }
#[ ! -d $MOSQUITTO_BIN ] && { mkdir -p $MOSQUITTO_CONF; echo "create $MOSQUITTO_BIN"; }
#[ ! -d $MOSQUITTO_CONF ] && { mkdir -p $MOSQUITTO_CONF; echo "create $MOSQUITTO_CONF"; }
#[ ! -d $MOSQUITTO_LOGS ] && { mkdir -p $MOSQUITTO_LOGS; echo "create $MOSQUITTO_LOGS"; }
#[ ! -d $MOSQUITTO_DATA ] && { mkdir -p $MOSQUITTO_DATA; echo "create $MOSQUITTO_DATA"; }
#[ ! -d $MOSQUITTO_PLUGGIN ] && { mkdir -p $MOSQUITTO_PLUGGIN; echo "create $MOSQUITTO_PLUGGIN"; }

###################################
# Download & Build Redis Source
###################################
SETUP_PATH=$HOME/setups
SERVICE_SRC_FILE="mosquitto-${MOSQUITTO_VERSION}.tar.gz"
SERVICE_SRC_URL="https://mosquitto.org/files/source/${SERVICE_SRC_FILE}"
SERVICE_SRC_PATH="$SETUP_PATH/mosquitto-$MOSQUITTO_VERSION"
[ ! -d $SETUP_PATH ] && { mkdir -p $SETUP_PATH; echo "create $SETUP_PATH"; }

## check process running
pgrep -x mosquitto >/dev/null && { echo "mosquitto is Running, please stop service before re-install"; exit; }


################################
# Build Dependency Package
# 
#################################
#install_package_from_repo make openssl-devel c-ares-devel libuuid-devel libcurl-devel
#sudo dnf --enablerepo=powertools install libuv-devel
#install_package_from_repo libwebsockets libwebsockets-devel

#SETUP_PATH=$HOME/setups
CJSON_GIT_URL="https://github.com/DaveGamble/cJSON.git "
CJSON_GIT_VERSION="vlatest"
CJSON_SRC="$SETUP_PATH/cJSON-$CJSON_GIT_VERSION"
CJSON_LIB=" /usr/local/lib/libcjson.so"
is_overwrite=$(is_overwrite_file $CJSON_LIB)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  [ ! -d $SETUP_PATH ] && { mkdir -p $SETUP_PATH; echo "create $SETUP_PATH"; }
  ## Download source
  [ ! -d $CJSON_SRC ] && { \
      mkdir -p $CJSON_SRC; \
      [ $CJSON_GIT_VERSION == "v$CONST_VERSION_LATEST" ] \
        && { git clone --recursive $CJSON_GIT_URL $CJSON_SRC; } \
        || { git clone --recursive $CJSON_GIT_URL -b $CJSON_GIT_VERSION $CJSON_SRC; } \
    }
  ## buil source
  cd $CJSON_SRC && mkdir $CJSON_SRC/build && cd $CJSON_SRC/build && cmake ..
  cd $CJSON_SRC && make && sudo make install
fi


################################
# Build Mosquitto from Source
#################################
is_overwrite=$(is_overwrite_file $MOSQUITTO_SERVER)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  echo "Mosquitto Server's existed in $MOSQUITTO_SERVER"
  if [ ! -f $SERVICE_SRC_PATH ]; then
    ## param: redis path,redis url, output path, command type
    download_and_extract_package_from_url $SETUP_PATH/$SERVICE_SRC_FILE $SERVICE_SRC_URL $SETUP_PATH "tar-extract"
  fi

  [ ! -d $SERVICE_SRC_PATH ] && { echo "Mosquitto source path not exist"; exit 1; }

  echo "Starting install Mosquitto from source: $SERVICE_SRC_PATH"
  cd $SERVICE_SRC_PATH && make WITH_WEBSOCKETS=yes WITH_CJSON=yes && sudo make install
fi

###################################
# Sysconfig Mosquitto
###################################



