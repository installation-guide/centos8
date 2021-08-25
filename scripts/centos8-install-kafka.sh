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
SCALA_VERSION=${SCALA_VERSION:-2.12}
KAFKA_VERSION=${KAFKA_VERSION:-2.5.0}
KAFKA_ADMIN_PORT=${KAFKA_ADMIN_PORT:-3888}

KAFKA_HOME="$HOME/kafka_${SCALA_VERSION}-${KAFKA_VERSION}"
KAFKA_BIN=$KAFKA_HOME/bin
KAFKA_CONF=$KAFKA_HOME/config
KAFKA_LOGS=$KAFKA_HOME/logs
KAFKA_TEMP=$KAFKA_HOME/tmp


KAFKA_SERVICE=kafka
ZOOKEEPER_SERVICE=zookeeper

KAFKA_SERVER_START=$KAFKA_BIN/kafka-server-start.sh
KAFKA_SERVER_STOP=$KAFKA_BIN/kafka-server-stop.sh

ZOOKEEPER_SERVER_START=$KAFKA_BIN/zookeeper-server-start.sh
ZOOKEEPER_SERVER_STOP=$KAFKA_BIN/zookeeper-server-stop.sh

KAFKA_CONFIG_FILE=$KAFKA_CONF/server.properties
ZOOKEEPER_CONFIG_FILE=$KAFKA_CONF/zookeeper.properties

user_check_sudo
if [ $? -ne 0 ]; then
  echo "please login user with sudo permission"
  return 1
fi

###################################
# Download & Build Redis Source
###################################
SETUP_PATH=$HOME/setups
SERVICE_SRC_FILE="kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz"
SERVICE_SRC_URL="https://downloads.apache.org/kafka/${KAFKA_VERSION}/${SERVICE_SRC_FILE}"

[ ! -d $SETUP_PATH ] && { mkdir -p $SETUP_PATH; echo "create $SETUP_PATH"; }

## check process running
pgrep -x kafka >/dev/null && { echo "kafka is Running, please stop service before re-install"; exit; }
pgrep -x zookeeper >/dev/null && { echo "zookeeper is Running, please stop service before re-install"; exit; }

################################
# Build Kafka from Source
#################################
is_overwrite=$(is_overwrite_file $KAFKA_HOME)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  echo "Download $SERVICE_SRC_URL"
  ## param: redis path,redis url, output path, command type
  download_and_extract_package_from_url $SETUP_PATH/$SERVICE_SRC_FILE $SERVICE_SRC_URL $HOME "tar-extract"
fi

###################################
# Sysconfig Service
###################################
SETUP_PATH=$HOME/setups
SERVICE_SRC_PATH=${SETUP_PATH}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}
SERVICE_SRC_SYSCONFIG_PATH=${SERVICE_SRC_PATH}/etc

[ ! -d $SERVICE_SRC_PATH ] && { mkdir -p $SERVICE_SRC_PATH; echo "create $SERVICE_SRC_PATH"; }
[ ! -d $SERVICE_SRC_SYSCONFIG_PATH ] && { mkdir -p $SERVICE_SRC_SYSCONFIG_PATH; echo "create $SERVICE_SRC_PATH"; }

KAFKA_SYSCONFIG=/etc/sysconfig/$KAFKA_SERVICE
is_overwrite=$(is_overwrite_file_with_sudo $KAFKA_SYSCONFIG)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  ##
  SYSCONFIG_PATH=$SERVICE_SRC_SYSCONFIG_PATH/sysconfig
  [ ! -d $SYSCONFIG_PATH ] && { mkdir -p $SYSCONFIG_PATH; echo "create new $SYSCONFIG_PATH"; }
  ###
  JAVA_HOME=$JAVA_HOME \
    envsubst< $SCRIPT_DIR/kafka/$KAFKA_SERVICE.sysconfig >  "$SYSCONFIG_PATH/$KAFKA_SERVICE.sysconfig"

  echo "> $KAFKA_SYSCONFIG"
  sudo cp $SYSCONFIG_PATH/$KAFKA_SERVICE.sysconfig $KAFKA_SYSCONFIG
fi

ZOOKEEPER_SYSCONFIG=/etc/sysconfig/$ZOOKEEPER_SERVICE
is_overwrite=$(is_overwrite_file_with_sudo $ZOOKEEPER_SYSCONFIG)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  ##
  SYSCONFIG_PATH=$SERVICE_SRC_SYSCONFIG_PATH/sysconfig
  [ ! -d $SYSCONFIG_PATH ] && { mkdir -p $SYSCONFIG_PATH; echo "create new $SYSCONFIG_PATH"; }
  ###
  JAVA_HOME=$JAVA_HOME \
    envsubst< $SCRIPT_DIR/kafka/$ZOOKEEPER_SERVICE.sysconfig >  "$SYSCONFIG_PATH/$ZOOKEEPER_SERVICE.sysconfig"

  echo "> $ZOOKEEPER_SYSCONFIG"
  sudo cp $SYSCONFIG_PATH/$ZOOKEEPER_SERVICE.sysconfig $ZOOKEEPER_SYSCONFIG
fi


###################################
# SystemD Service
###################################
is_overwrite=$(is_overwrite_file_with_sudo /etc/systemd/system/$KAFKA_SERVICE.service)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  ##
  SYSTEMD_PATH=$SERVICE_SRC_SYSCONFIG_PATH/systemd/system
  [ ! -d $SYSTEMD_PATH ] && { mkdir -p $SYSTEMD_PATH; echo "create new $SYSTEMD_PATH"; }
  ###
  export SERVICE_USER=$USER; \
  export SERVICE_GROUP=$USER; \
  export KAFKA_SYSCONFIG=$KAFKA_SYSCONFIG; \
  export KAFKA_SERVER_START=$KAFKA_SERVER_START; \
  export KAFKA_SERVER_STOP=$KAFKA_SERVER_STOP; \
  export KAFKA_SERVER_CONFIG_FILE=$KAFKA_CONFIG_FILE; \
  export KAFKA_TEMP=$KAFKA_TEMP; \
    cat $SCRIPT_DIR/kafka/kafka.service | envsubst '$SERVICE_USER ${SERVICE_GROUP} ${KAFKA_SYSCONFIG} ${KAFKA_SERVER_START} ${KAFKA_SERVER_STOP} ${KAFKA_SERVER_CONFIG_FILE} ${KAFKA_TEMP}' > "$SYSTEMD_PATH/$KAFKA_SERVICE.service"

  echo "> /etc/systemd/system/$KAFKA_SERVICE.service"
  sudo cp $SYSTEMD_PATH/$KAFKA_SERVICE.service /etc/systemd/system/$KAFKA_SERVICE.service

  echo "> Enable $KAFKA_SERVICE.service"
  sudo systemctl enable $KAFKA_SERVICE.service
fi

is_overwrite=$(is_overwrite_file_with_sudo /etc/systemd/system/$ZOOKEEPER_SERVICE.service)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  ##
  SYSTEMD_PATH=$SERVICE_SRC_SYSCONFIG_PATH/systemd/system
  [ ! -d $SYSTEMD_PATH ] && { mkdir -p $SYSTEMD_PATH; echo "create new $SYSTEMD_PATH"; }
  ###
  export SERVICE_USER=$USER; \
  export SERVICE_GROUP=$USER; \
  export ZOOKEEPER_SYSCONFIG=$ZOOKEEPER_SYSCONFIG; \
  export ZOOKEEPER_SERVER_START=$ZOOKEEPER_SERVER_START; \
  export ZOOKEEPER_SERVER_STOP=$ZOOKEEPER_SERVER_STOP; \
  export ZOOKEEPER_SERVER_CONFIG_FILE=$ZOOKEEPER_CONFIG_FILE; \
  export ZOOKEEPER_TEMP=$KAFKA_TEMP; \
    cat $SCRIPT_DIR/kafka/zookeeper.service | envsubst '$SERVICE_USER ${SERVICE_GROUP}  ${ZOOKEEPER_SYSCONFIG} ${ZOOKEEPER_SERVER_START} ${ZOOKEEPER_SERVER_STOP} ${ZOOKEEPER_SERVER_CONFIG_FILE} ${KAFKA_TEMP}' > "$SYSTEMD_PATH/$ZOOKEEPER_SERVICE.service"

  echo "> /etc/systemd/system/$ZOOKEEPER_SERVICE.service"
  sudo cp $SYSTEMD_PATH/$ZOOKEEPER_SERVICE.service /etc/systemd/system/$ZOOKEEPER_SERVICE.service

  echo "> Enable $ZOOKEEPER_SERVICE.service"
  sudo systemctl enable $ZOOKEEPER_SERVICE.service
fi

###################################
# Sudoers Service
###################################
is_overwrite=$(is_overwrite_file_with_sudo /etc/sudoers.d/$KAFKA_SERVICE)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  SUDOERS_PATH=$SERVICE_SRC_SYSCONFIG_PATH/sudoers.d
  [ ! -d $SUDOERS_PATH ] && { mkdir -p $SUDOERS_PATH; echo "create new $SUDOERS_PATH"; }
  
  SERVICE_NAME=$KAFKA_SERVICE \
  SERVICE_GROUP=$USER \
    envsubst< $SCRIPT_DIR/kafka/kafka.sudoers >  $SUDOERS_PATH/$KAFKA_SERVICE
  echo "> /etc/sudoers.d/$KAFKA_SERVICE"
  sudo cp $SUDOERS_PATH/$KAFKA_SERVICE /etc/sudoers.d/$KAFKA_SERVICE
fi

is_overwrite=$(is_overwrite_file_with_sudo /etc/sudoers.d/$ZOOKEEPER_SERVICE)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  SUDOERS_PATH=$SERVICE_SRC_SYSCONFIG_PATH/sudoers.d
  [ ! -d $SUDOERS_PATH ] && { mkdir -p $SUDOERS_PATH; echo "create new $SUDOERS_PATH"; }
  
  SERVICE_NAME=$ZOOKEEPER_SERVICE \
  SERVICE_GROUP=$USER \
    envsubst< $SCRIPT_DIR/kafka/zookeeper.sudoers >  $SUDOERS_PATH/$ZOOKEEPER_SERVICE
  echo "> /etc/sudoers.d/$ZOOKEEPER_SERVICE"
  sudo cp $SUDOERS_PATH/$ZOOKEEPER_SERVICE /etc/sudoers.d/$ZOOKEEPER_SERVICE
fi
