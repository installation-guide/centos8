#!/usr/bin/bash

###############
# Load common
###############
SCRIPT_DIR=$(dirname $0)
source "$SCRIPT_DIR/centos8-common.sh"

###############
# Execute
###############

JAVA_HOME=${JAVA_HOME:-/opt/open-jdk-14.0.1}
KEYCLOAK_VERSION=${KEYCLOAK_VERSION:-19.0.1}
KEYCLOAK_PORT=${KEYCLOAK_PORT:-8080}

KEYCLOAK_HOME="$HOME/keycloak-${KEYCLOAK_VERSION}"
KEYCLOAK_BIN=$KEYCLOAK_HOME/bin
KEYCLOAK_CONF=$KEYCLOAK_HOME/conf
KEYCLOAK_LOGS=$KEYCLOAK_HOME/logs
KEYCLOAK_TEMP_DIR=$KEYCLOAK_HOME/tmp


KEYCLOAK_SERVICE=keycloak

KEYCLOAK_SERVER_START=$KEYCLOAK_BIN/kc.sh

KEYCLOAK_CONFIG_FILE=$KEYCLOAK_CONF/keycloak.conf

user_check_sudo
if [ $? -ne 0 ]; then
  echo "please login user with sudo permission"
  return 1
fi

###################################
# Download & Build Redis Source
###################################
SETUP_PATH=$HOME/setups
SERVICE_SRC_FILE="keycloak-${KEYCLOAK_VERSION}.tar.gz"
#https://github.com/keycloak/keycloak/releases/download/19.0.1/keycloak-19.0.1.tar.gz
SERVICE_SRC_URL="https://github.com/keycloak/keycloak/releases/download/${KEYCLOAK_VERSION}/${SERVICE_SRC_FILE}"

[ ! -d $SETUP_PATH ] && { mkdir -p $SETUP_PATH; echo "create $SETUP_PATH"; }

## check process running
pgrep -x keycloak >/dev/null && { echo "keycloak is Running, please stop service before re-install"; exit; }


# ################################
# # Build keycloak from Source
# #################################
# is_overwrite=$(is_overwrite_file $KEYCLOAK_HOME)
# if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
#   echo "Download $SERVICE_SRC_URL"
#   ## param: redis path,redis url, output path, command type
#   download_and_extract_package_from_url $SETUP_PATH/$SERVICE_SRC_FILE $SERVICE_SRC_URL $HOME "tar-extract"
# fi

# ###################################
# # Sysconfig Service
# ###################################
# SETUP_PATH=$HOME/setups
# SERVICE_SRC_PATH=${SETUP_PATH}/KEYCLOAK_${SCALA_VERSION}-${KEYCLOAK_VERSION}
# SERVICE_SRC_SYSCONFIG_PATH=${SERVICE_SRC_PATH}/etc

# [ ! -d $SERVICE_SRC_PATH ] && { mkdir -p $SERVICE_SRC_PATH; echo "create $SERVICE_SRC_PATH"; }
# [ ! -d $SERVICE_SRC_SYSCONFIG_PATH ] && { mkdir -p $SERVICE_SRC_SYSCONFIG_PATH; echo "create $SERVICE_SRC_PATH"; }

# KEYCLOAK_SYSCONFIG=/etc/sysconfig/$KEYCLOAK_SERVICE
# is_overwrite=$(is_overwrite_file_with_sudo $KEYCLOAK_SYSCONFIG)
# if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
#   ##
#   SYSCONFIG_PATH=$SERVICE_SRC_SYSCONFIG_PATH/sysconfig
#   [ ! -d $SYSCONFIG_PATH ] && { mkdir -p $SYSCONFIG_PATH; echo "create new $SYSCONFIG_PATH"; }
#   ###
#   JAVA_HOME=$JAVA_HOME \
#     envsubst< $SCRIPT_DIR/KEYCLOAK/$KEYCLOAK_SERVICE.sysconfig >  "$SYSCONFIG_PATH/$KEYCLOAK_SERVICE.sysconfig"

#   echo "> $KEYCLOAK_SYSCONFIG"
#   sudo cp $SYSCONFIG_PATH/$KEYCLOAK_SERVICE.sysconfig $KEYCLOAK_SYSCONFIG
# fi

# ZOOKEEPER_SYSCONFIG=/etc/sysconfig/$ZOOKEEPER_SERVICE
# is_overwrite=$(is_overwrite_file_with_sudo $ZOOKEEPER_SYSCONFIG)
# if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
#   ##
#   SYSCONFIG_PATH=$SERVICE_SRC_SYSCONFIG_PATH/sysconfig
#   [ ! -d $SYSCONFIG_PATH ] && { mkdir -p $SYSCONFIG_PATH; echo "create new $SYSCONFIG_PATH"; }
#   ###
#   JAVA_HOME=$JAVA_HOME \
#     envsubst< $SCRIPT_DIR/KEYCLOAK/$ZOOKEEPER_SERVICE.sysconfig >  "$SYSCONFIG_PATH/$ZOOKEEPER_SERVICE.sysconfig"

#   echo "> $ZOOKEEPER_SYSCONFIG"
#   sudo cp $SYSCONFIG_PATH/$ZOOKEEPER_SERVICE.sysconfig $ZOOKEEPER_SYSCONFIG
# fi


# ###################################
# # SystemD Service
# ###################################
# is_overwrite=$(is_overwrite_file_with_sudo /etc/systemd/system/$KEYCLOAK_SERVICE.service)
# if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
#   ##
#   SYSTEMD_PATH=$SERVICE_SRC_SYSCONFIG_PATH/systemd/system
#   [ ! -d $SYSTEMD_PATH ] && { mkdir -p $SYSTEMD_PATH; echo "create new $SYSTEMD_PATH"; }
#   ###
#   export SERVICE_USER=$USER; \
#   export SERVICE_GROUP=$USER; \
#   export KEYCLOAK_SYSCONFIG=$KEYCLOAK_SYSCONFIG; \
#   export KEYCLOAK_SERVER_START=$KEYCLOAK_SERVER_START; \
#   export KEYCLOAK_SERVER_STOP=$KEYCLOAK_SERVER_STOP; \
#   export KEYCLOAK_SERVER_CONFIG_FILE=$KEYCLOAK_CONFIG_FILE; \
#   export KEYCLOAK_TEMP=$KEYCLOAK_TEMP_DIR/KEYCLOAK-logs; \
#     cat $SCRIPT_DIR/KEYCLOAK/KEYCLOAK.service | envsubst '$SERVICE_USER ${SERVICE_GROUP} ${KEYCLOAK_SYSCONFIG} ${KEYCLOAK_SERVER_START} ${KEYCLOAK_SERVER_STOP} ${KEYCLOAK_SERVER_CONFIG_FILE} ${KEYCLOAK_TEMP}' > "$SYSTEMD_PATH/$KEYCLOAK_SERVICE.service"

#   echo "> /etc/systemd/system/$KEYCLOAK_SERVICE.service"
#   sudo cp $SYSTEMD_PATH/$KEYCLOAK_SERVICE.service /etc/systemd/system/$KEYCLOAK_SERVICE.service

#   echo "> Enable $KEYCLOAK_SERVICE.service"
#   sudo systemctl enable $KEYCLOAK_SERVICE.service
# fi

# is_overwrite=$(is_overwrite_file_with_sudo /etc/systemd/system/$ZOOKEEPER_SERVICE.service)
# if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
#   ##
#   SYSTEMD_PATH=$SERVICE_SRC_SYSCONFIG_PATH/systemd/system
#   [ ! -d $SYSTEMD_PATH ] && { mkdir -p $SYSTEMD_PATH; echo "create new $SYSTEMD_PATH"; }
#   ###
#   export SERVICE_USER=$USER; \
#   export SERVICE_GROUP=$USER; \
#   export ZOOKEEPER_SYSCONFIG=$ZOOKEEPER_SYSCONFIG; \
#   export ZOOKEEPER_SERVER_START=$ZOOKEEPER_SERVER_START; \
#   export ZOOKEEPER_SERVER_STOP=$ZOOKEEPER_SERVER_STOP; \
#   export ZOOKEEPER_SERVER_CONFIG_FILE=$ZOOKEEPER_CONFIG_FILE; \
#   export ZOOKEEPER_TEMP=$KEYCLOAK_TEMP_DIR/zookeeper; \
#     cat $SCRIPT_DIR/KEYCLOAK/zookeeper.service | envsubst '$SERVICE_USER ${SERVICE_GROUP}  ${ZOOKEEPER_SYSCONFIG} ${ZOOKEEPER_SERVER_START} ${ZOOKEEPER_SERVER_STOP} ${ZOOKEEPER_SERVER_CONFIG_FILE} ${ZOOKEEPER_TEMP}' > "$SYSTEMD_PATH/$ZOOKEEPER_SERVICE.service"

#   echo "> /etc/systemd/system/$ZOOKEEPER_SERVICE.service"
#   sudo cp $SYSTEMD_PATH/$ZOOKEEPER_SERVICE.service /etc/systemd/system/$ZOOKEEPER_SERVICE.service

#   echo "> Enable $ZOOKEEPER_SERVICE.service"
#   sudo systemctl enable $ZOOKEEPER_SERVICE.service
# fi

# ###################################
# # Sudoers Service
# ###################################
# is_overwrite=$(is_overwrite_file_with_sudo /etc/sudoers.d/$KEYCLOAK_SERVICE)
# if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
#   SUDOERS_PATH=$SERVICE_SRC_SYSCONFIG_PATH/sudoers.d
#   [ ! -d $SUDOERS_PATH ] && { mkdir -p $SUDOERS_PATH; echo "create new $SUDOERS_PATH"; }
  
#   SERVICE_NAME=$KEYCLOAK_SERVICE \
#   SERVICE_GROUP=$USER \
#     envsubst< $SCRIPT_DIR/KEYCLOAK/KEYCLOAK.sudoers >  $SUDOERS_PATH/$KEYCLOAK_SERVICE
#   echo "> /etc/sudoers.d/$KEYCLOAK_SERVICE"
#   sudo cp $SUDOERS_PATH/$KEYCLOAK_SERVICE /etc/sudoers.d/$KEYCLOAK_SERVICE
# fi

# is_overwrite=$(is_overwrite_file_with_sudo /etc/sudoers.d/$ZOOKEEPER_SERVICE)
# if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
#   SUDOERS_PATH=$SERVICE_SRC_SYSCONFIG_PATH/sudoers.d
#   [ ! -d $SUDOERS_PATH ] && { mkdir -p $SUDOERS_PATH; echo "create new $SUDOERS_PATH"; }
  
#   SERVICE_NAME=$ZOOKEEPER_SERVICE \
#   SERVICE_GROUP=$USER \
#     envsubst< $SCRIPT_DIR/KEYCLOAK/zookeeper.sudoers >  $SUDOERS_PATH/$ZOOKEEPER_SERVICE
#   echo "> /etc/sudoers.d/$ZOOKEEPER_SERVICE"
#   sudo cp $SUDOERS_PATH/$ZOOKEEPER_SERVICE /etc/sudoers.d/$ZOOKEEPER_SERVICE
# fi

# ###################################
# # KEYCLOAK & Zookeeper Configuration
# ###################################
# echo
# echo
# if [ -f $ZOOKEEPER_CONFIG_FILE ]; then
#   echo
#   echo "> $ZOOKEEPER_CONFIG_FILE"
#   echo "dataDir=${KEYCLOAK_TEMP_DIR}/zookeeper"
#   sed -i "/^dataDir=.*/c dataDir=${KEYCLOAK_TEMP_DIR}/zookeeper" $ZOOKEEPER_CONFIG_FILE
#   sed -i "/^clientPort=.*/c clientPort=${ZOOKEEPER_PORT}" $ZOOKEEPER_CONFIG_FILE
# fi

# if [ -f $KEYCLOAK_CONFIG_FILE ]; then
#   echo
#   echo "> $KEYCLOAK_CONFIG_FILE"
#   echo "log.dirs=${KEYCLOAK_TEMP_DIR}/KEYCLOAK-logs"
#   sed -i "/^log.dirs=.*/c log.dirs=${KEYCLOAK_TEMP_DIR}/KEYCLOAK-logs" $KEYCLOAK_CONFIG_FILE
#   #listeners=PLAINTEXT://:9092
#   sed -i "/^listeners=.*/c listeners=PLAINTEXT://:${KEYCLOAK_PORT}" $KEYCLOAK_CONFIG_FILE
#   sed -i "/^#listeners=.*/c listeners=PLAINTEXT://:${KEYCLOAK_PORT}" $KEYCLOAK_CONFIG_FILE
#   #advertised.listeners=PLAINTEXT://your.host.name:9092
#   sed -i "/^advertised.listeners=.*/c advertised.listeners=PLAINTEXT://$(hostname):${KEYCLOAK_PORT}" $KEYCLOAK_CONFIG_FILE
#   sed -i "/^#advertised.listeners=.*/c advertised.listeners=PLAINTEXT://$(hostname):${KEYCLOAK_PORT}" $KEYCLOAK_CONFIG_FILE
  
#   sed -i "/^zookeeper.connect=.*/c zookeeper.connect=localhost:${ZOOKEEPER_PORT}" $KEYCLOAK_CONFIG_FILE
# fi
# echo
# echo