#!/usr/bin/bash

###############
# Load common
###############
SCRIPT_DIR=$(dirname $0)
source "$SCRIPT_DIR/centos8-common.sh"

###############
# Execute
###############

SERVICE_NAME=keycloak

JAVA_HOME=${JAVA_HOME:-/opt/open-jdk-14.0.1}
SERVICE_VERSION=${SERVICE_VERSION:-19.0.1}
SERVICE_PORT=${SERVICE_PORT:-8080}

SERVICE_HOME="$HOME/${SERVICE_NAME}-${SERVICE_VERSION}"
SERVICE_BIN=$SERVICE_HOME/bin
SERVICE_CONF=$SERVICE_HOME/conf
SERVICE_LOGS=$SERVICE_HOME/logs
KEYCLOAK_TEMP_DIR=$SERVICE_HOME/tmp

SERVICE_START=$SERVICE_BIN/kc.sh

SERVICE_CONFIG_FILE=$SERVICE_CONF/$SERVICE_NAME.conf

user_check_sudo
if [ $? -ne 0 ]; then
  echo "please login user with sudo permission"
  return 1
fi

###################################
# Download & Build Redis Source
###################################
SETUP_PATH=$HOME/setups
SERVICE_SRC_FILE="$SERVICE_NAME-${SERVICE_VERSION}.tar.gz"
#https://github.com/keycloak/keycloak/releases/download/19.0.1/keycloak-19.0.1.tar.gz
SERVICE_SRC_URL="https://github.com/keycloak/keycloak/releases/download/${SERVICE_VERSION}/${SERVICE_SRC_FILE}"

[ ! -d $SERVICE_LOGS ] && { mkdir -p $SERVICE_LOGS; echo "create $SERVICE_LOGS"; }

## check process running
pgrep -x $SERVICE_NAME >/dev/null && { echo "keycloak is Running, please stop service before re-install"; exit; }


################################
# Build keycloak from Source
#################################
is_overwrite=$(is_overwrite_file $SERVICE_HOME)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  echo "Download $SERVICE_SRC_URL"
  ## param: redis path,redis url, output path, command type
  download_and_extract_package_from_url $SETUP_PATH/$SERVICE_SRC_FILE $SERVICE_SRC_URL $HOME "tar-extract"
fi

[ ! -d $SERVICE_SRC_PATH ] && { mkdir -p $SERVICE_SRC_PATH; echo "create $SERVICE_SRC_PATH"; }

###################################
# Sysconfig Service
###################################
SETUP_PATH=$HOME/setups
SERVICE_SRC_PATH=${SETUP_PATH}/$SERVICE_NAME-${SERVICE_VERSION}
SERVICE_SRC_SYSCONFIG_PATH=${SERVICE_SRC_PATH}/etc

[ ! -d $SERVICE_SRC_PATH ] && { mkdir -p $SERVICE_SRC_PATH; echo "create $SERVICE_SRC_PATH"; }
[ ! -d $SERVICE_SRC_SYSCONFIG_PATH ] && { mkdir -p $SERVICE_SRC_SYSCONFIG_PATH; echo "create $SERVICE_SRC_PATH"; }

SERVICE_SYSCONFIG=/etc/sysconfig/$SERVICE_NAME
is_overwrite=$(is_overwrite_file_with_sudo $SERVICE_SYSCONFIG)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  ##
  SYSCONFIG_PATH=$SERVICE_SRC_SYSCONFIG_PATH/sysconfig
  [ ! -d $SYSCONFIG_PATH ] && { mkdir -p $SYSCONFIG_PATH; echo "create new $SYSCONFIG_PATH"; }
  ###
  JAVA_HOME=$JAVA_HOME \
    envsubst< $SCRIPT_DIR/$SERVICE_NAME/$SERVICE_NAME.sysconfig >  "$SYSCONFIG_PATH/$SERVICE_NAME.sysconfig"

  echo "> $SERVICE_SYSCONFIG"
  sudo cp $SYSCONFIG_PATH/$SERVICE_NAME.sysconfig $SERVICE_SYSCONFIG
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
  export SERVICE_USER=$USER; \
  export SERVICE_GROUP=$USER; \
  export SERVICE_VERSION=$SERVICE_VERSION; \
  export SERVICE_SYSCONFIG=$SERVICE_SYSCONFIG; \
  export SERVICE_LOGS=$SERVICE_LOGS; \
      cat $SCRIPT_DIR/$SERVICE_NAME/$SERVICE_NAME.service | envsubst '$SERVICE_VERSION $SERVICE_USER ${SERVICE_GROUP} ${SERVICE_SYSCONFIG} $SERVICE_LOGS' > "$SYSTEMD_PATH/$SERVICE_NAME.service"

  echo "> /etc/systemd/system/$SERVICE_NAME.service"
  sudo cp $SYSTEMD_PATH/$SERVICE_NAME.service /etc/systemd/system/$SERVICE_NAME.service
  
  echo "> reload $SERVICE_NAME.service"
  sudo systemctl daemon-reload

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
    envsubst< $SCRIPT_DIR/$SERVICE_NAME/$SERVICE_NAME.sudoers >  $SUDOERS_PATH/$SERVICE_NAME
  echo "> /etc/sudoers.d/$SERVICE_NAME"
  sudo cp $SUDOERS_PATH/$SERVICE_NAME /etc/sudoers.d/$SERVICE_NAME
fi

# ###################################
# Configuration Service
# ###################################
is_overwrite=$(is_overwrite_file_with_sudo $SERVICE_CONFIG_FILE)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  TEMP_CONF_PATH=$SERVICE_SRC_SYSCONFIG_PATH/conf
  [ ! -d $TEMP_CONF_PATH ] && { mkdir -p $TEMP_CONF_PATH; echo "create new $TEMP_CONF_PATH"; }
  
  export SERVICE_VERSION=$SERVICE_VERSION; \
  export SERVICE_LOGS=$SERVICE_LOGS; \
  export SERVICE_CONF=$SERVICE_CONF; \
  export SERVICE_PORT=$SERVICE_PORT; \
      cat $SCRIPT_DIR/$SERVICE_NAME/$SERVICE_NAME.conf | envsubst '$SERVICE_VERSION $SERVICE_CONF $SERVICE_LOGS $SERVICE_PORT' > "$TEMP_CONF_PATH/$SERVICE_NAME.conf"

  echo "> $SERVICE_CONF/$SERVICE_NAME.conf"
  sudo cp $TEMP_CONF_PATH/$SERVICE_NAME.conf $SERVICE_CONFIG_FILE
fi

# echo