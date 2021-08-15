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
MOSQUITTO_CONF=/etc/mosquitto
MOSQUITTO_CONF_FILE=${MOSQUITTO_CONF}/mosquitto.conf
MOSQUITTO_PASSWORD_FILE=${MOSQUITTO_CONF}/passwd_nm


user_check_sudo
if [ $? -ne 0 ]; then
  echo "please login user with sudo permission"
  return 1
fi

###################################
# Download & Build Redis Source
###################################
SETUP_PATH=$HOME/setups
SERVICE_SRC_FILE="mosquitto-${MOSQUITTO_VERSION}.tar.gz"
SERVICE_SRC_URL="https://mosquitto.org/files/source/${SERVICE_SRC_FILE}"
SERVICE_SRC_PATH="$SETUP_PATH/mosquitto-$MOSQUITTO_VERSION"
SERVICE_SRC_SYSCONFIG_PATH=$SERVICE_SRC_PATH/etc


[ ! -d $SETUP_PATH ] && { mkdir -p $SETUP_PATH; echo "create $SETUP_PATH"; }
[ ! -d $SERVICE_SRC_CONFIG_PATH ] && { mkdir -p $SERVICE_SRC_CONFIG_PATH; echo "create new $SERVICE_SRC_CONFIG_PATH"; }

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
MOSQUITTO_LOGS=${HOME}/v$MOSQUITTO_VERSION/logs
MOSQUITTO_LOG_FILE=${MOSQUITTO_LOGS}/mosquitto.log

[ ! -d $MOSQUITTO_LOGS ] && { mkdir -p $MOSQUITTO_LOGS; }
##

###
#
###
is_overwrite=$(is_overwrite_file $MOSQUITTO_CONF_FILE)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then

  is_overwrite=$(is_overwrite_file $MOSQUITTO_PASSWORD_FILE)
  if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
    MOSQUITTO_SUB_NM_AUTH="mqtt_mbs" \
    MOSQUITTO_PUB_NM_USER="mqtt_mbs" \
    MOSQUITTO_APP_USER="mqtt_mbs" \
    MOSQUITTO_APP_AUTH="" \
      envsubst< $SCRIPT_DIR/mosquitto/passwd_nm >  $SERVICE_SRC_SYSCONFIG_PATH/mosquitto/passwd_nm
    echo "Create/Overwrite $MOSQUITTO_PASSWORD_FILE"
    sudo cp $SERVICE_SRC_SYSCONFIG_PATH/mosquitto/passwd_nm $MOSQUITTO_PASSWORD_FILE
  fi

  sudo chown -R $USER ${MOSQUITTO_CONF} && sudo chmod -R +rx ${MOSQUITTO_CONF}
    USER=$USER \
    MOSQUITTO_PASSWORD_FILE=$MOSQUITTO_PASSWORD_FILE \
    MOSQUITTO_LOG_FILE=$MOSQUITTO_LOG_FILE \
      envsubst< $SCRIPT_DIR/mosquitto/mosquitto.conf >  $SERVICE_SRC_SYSCONFIG_PATH/mosquitto/mosquitto.conf
  echo "Create/Overwrite $MOSQUITTO_CONF_FILE"
  sudo cp $SERVICE_SRC_SYSCONFIG_PATH/mosquitto/mosquitto.conf $MOSQUITTO_CONF_FILE
fi

###################################
# SystemD Service
###################################
is_overwrite=$(is_overwrite_file_with_sudo /etc/systemd/system/$SERVICE_NAME.service)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  ##
  SYSTEMD_PATH=$SERVICE_SRC_SYSCONFIG_PATH/systemd/system
  [ ! -d $SYSTEMD_PATH ] && { mkdir -p $SYSTEMD_PATH; echo "create new $SYSTEMD_PATH"; }
  ###
  MOSQUITTO_LOGS_PATH=$MOSQUITTO_LOGS \
  SERVICE_USER=$USER \
  SERVICE_GROUP=$USER \
  MOSQUITTO_SERVER=$MOSQUITTO_SERVER \
  MOSQUITTO_CONF_FILE=$MOSQUITTO_CONF_FILE \
    envsubst< $SCRIPT_DIR/mosquitto/mosquitto.service >  "$SYSTEMD_PATH/$SERVICE_NAME.service"

  echo "> /etc/systemd/system/$SERVICE_NAME.service"
  sudo cp $SYSTEMD_PATH/$SERVICE_NAME.service /etc/systemd/system/$SERVICE_NAME.service

  echo "> Enable $SERVICE_NAME.service"
  sudo systemctl enable $SERVICE_NAME.service
fi

###################################
# Sudoers Service
###################################
is_overwrite=$(is_overwrite_file_with_sudo /etc/sudoers.d/$SERVICE_NAME)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  SUDOERS_PATH=$SERVICE_SRC_SYSCONFIG_PATH/sudoers.d
  [ ! -d $SUDOERS_PATH ] && { mkdir -p $SUDOERS_PATH; echo "create new $SUDOERS_PATH"; }
  
  SERVICE_NAME=$SERVICE_NAME \
  SERVICE_GROUP=$USER \
    envsubst< $SCRIPT_DIR/mosquitto/mosquitto.sudoers >  $SUDOERS_PATH/$SERVICE_NAME
    
  echo "> /etc/sudoers.d/$SERVICE_NAME"
  sudo cp $SUDOERS_PATH/$SERVICE_NAME /etc/sudoers.d/$SERVICE_NAME
fi


