#!/usr/bin/bash

###############
# Load common
###############
SCRIPT_DIR=$(dirname $0)
source "$SCRIPT_DIR/centos8-common.sh"

###############
# Execute
###############



SERVICE_VERSION=${SERVICE_VERSION:-"latest"}
SERVICE_NAME=${SERVICE_NAME:-"events-service"}
SERVICE_PORT=${SERVICE_PORT:-"9000"}
SERVICE_USE_TLS=${SERVICE_USE_TLS:-"false"}


SERVICE_HOME="$HOME/productions/marketdata/${SERVICE_NAME}"
SERVICE_BIN=$SERVICE_HOME/bin
SERVICE_APP=$SERVICE_HOME/app
SERVICE_CONF=$SERVICE_HOME/config
SERVICE_DATA=$SERVICE_HOME/data
SERVICE_LOGS=$SERVICE_HOME/logs
SERVICE_SCRIPTS=$SERVICE_HOME/shells

SERVICE_SERVER=$SERVICE_BIN/$SERVICE_NAME

[ ! -d $SERVICE_BIN ] && { mkdir -p $SERVICE_BIN; echo "create $SERVICE_BIN"; }
[ ! -d $SERVICE_APP ] && { mkdir -p $SERVICE_APP; echo "create $SERVICE_APP"; }
[ ! -d $SERVICE_CONF ] && { mkdir -p $SERVICE_CONF; echo "create $SERVICE_CONF"; }
[ ! -d $SERVICE_DATA ] && { mkdir -p $SERVICE_DATA; echo "create $SERVICE_DATA"; }
[ ! -d $SERVICE_SCRIPTS ] && { mkdir -p $SERVICE_SCRIPTS; echo "create $SERVICE_SCRIPTS"; }

user_check_sudo
if [ $? -ne 0 ]; then
  echo "please login user with sudo permission"
  return 1
fi

###################################
# Download & Build Redis Source
###################################
echo "$SERVICE_NAME:$SERVICE_VERSION:$SERVICE_PORT"
echo "TLS Enable: $SERVICE_USE_TLS"

## check process running
pgrep -x ${SERVICE_NAME} >/dev/null && { echo "$SERVICE_NAME is Running, please stop service before re-install"; exit; }

exit 0

###################################
# Sysconfig Service
###################################
SETUP_PATH=$HOME/setups
SERVICE_SRC_PATH=${SETUP_PATH}/${SERVICE_NAME}-${SERVICE_VERSION}
SERVICE_SRC_ETC_PATH=${SERVICE_SRC_PATH}/etc

[ ! -d $SERVICE_SRC_PATH ] && { mkdir -p $SERVICE_SRC_PATH; echo "create $SERVICE_SRC_PATH"; }
[ ! -d $SERVICE_SRC_ETC_PATH ] && { mkdir -p $SERVICE_SRC_ETC_PATH; echo "create $SERVICE_SRC_ETC_PATH"; }

SERVICE_SYSCONFIG=/etc/sysconfig/$SERVICE_NAME
is_overwrite=$(is_overwrite_file_with_sudo $SERVICE_SYSCONFIG)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  ##
  SERVICE_SRC_SYSCONFIG_PATH=$SERVICE_SRC_ETC_PATH/sysconfig
  [ ! -d $SERVICE_SRC_SYSCONFIG_PATH ] && { mkdir -p $SERVICE_SRC_SYSCONFIG_PATH; echo "create new $SERVICE_SRC_SYSCONFIG_PATH"; }
  ###
  export SERVICE_CPUS=$(($(nproc --all) -1)); \
  export SERVICE_CACHE_TYPE="redis";\
  export SERVICE_PORT=${SERVICE_PORT};\
  export SERVICE_USE_TLS=${SERVICE_USE_TLS};\
  export SERVICE_WORKING_FOLDER=${SERVICE_HOME};\
    envsubst< $SCRIPT_DIR/grpc/$SERVICE_NAME.sysconfig '${SERVICE_CPUS} ${SERVICE_CACHE_TYPE} ${SERVICE_PORT} ${SERVICE_USE_TLS} ${SERVICE_WORKING_FOLDER}'>  "$SERVICE_SRC_SYSCONFIG_PATH/$SERVICE_NAME.sysconfig"

  echo "> $SERVICE_SYSCONFIG"
  #sudo cp $SERVICE_SRC_SYSCONFIG_PATH/$SERVICE_NAME.sysconfig $SERVICE_SYSCONFIG
fi

###################################
# SystemD Service
###################################
SERVICE_SYSTEMD=/etc/systemd/system/$SERVICE_NAME.service
is_overwrite=$(is_overwrite_file_with_sudo $SERVICE_SYSTEMD)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  ##
  SERVICE_SRC_SYSTEMD_PATH=$SERVICE_SRC_ETC_PATH/systemd/system
  [ ! -d $SERVICE_SRC_SYSTEMD_PATH ] && { mkdir -p $SERVICE_SRC_SYSTEMD_PATH; echo "create new $SERVICE_SRC_SYSTEMD_PATH"; }
  ###
  export SERVICE_DESCRIPTION="Event Service - Market gRPC API" ;\
  export SERVICE_USER=$USER; \
  export SERVICE_GROUP=$USER; \
  export SERVICE_SYSCONFIG=$SERVICE_SYSCONFIG; \
  export SERVICE_SERVER=$SERVICE_SERVER;\
  export SERVICE_SERVER_OPTS="grpc --cmd.grpc.cache.type=redis";\
  export SERVICE_WORKING_FOLDER=$SERVICE_HOME;
    cat $SCRIPT_DIR/grpc/${SERVICE_NAME}.service | envsubst '${SERVICE_DESCRIPTION} ${SERVICE_USER} ${SERVICE_GROUP} ${SERVICE_SYSCONFIG} ${SERVICE_SERVER} ${SERVICE_SERVER_OPTS} ${SERVICE_WORKING_FOLDER}' > "$SERVICE_SRC_SYSTEMD_PATH/$SERVICE_NAME.service"

  echo "> $SERVICE_SYSTEMD"
  #sudo cp $SERVICE_SRC_SYSTEMD_PATH/$SERVICE_NAME.service $SERVICE_SYSTEMD

  echo "> Enable $SERVICE_NAME.service"
  #sudo systemctl enable $KAFKA_SERVICE.service
fi


###################################
# Sudoers Service
###################################
SERVICE_SUDOERS=/etc/sudoers.d/$SERVICE_NAME
is_overwrite=$(is_overwrite_file_with_sudo $SERVICE_SUDOERS)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  SERVICE_SRC_SUDOERS_PATH=$SERVICE_SRC_ETC_PATH/sudoers.d
  [ ! -d $SERVICE_SRC_SUDOERS_PATH ] && { mkdir -p $SERVICE_SRC_SUDOERS_PATH; echo "create new $SERVICE_SRC_SUDOERS_PATH"; }
  
  SERVICE_NAME=$SERVICE_NAME \
  SERVICE_GROUP=$USER \
    envsubst< $SCRIPT_DIR/grpc/$SERVICE_NAME.sudoers >  $SERVICE_SRC_SUDOERS_PATH/$SERVICE_NAME
  echo "> $SERVICE_SUDOERS"
  #sudo cp $SERVICE_SRC_SUDOERS_PATH/$SERVICE_NAME $SERVICE_SUDOERS
fi

###################################
# Service Configuration
###################################
echo
echo
echo ""
echo "$SERVICE_SYSCONFIG"
echo "$SERVICE_SYSTEMD"
echo "$SERVICE_SUDOERS"
echo
echo
