#!/usr/bin/bash

###############
# Load common
###############
SCRIPT_DIR=$(dirname $0)
source "$SCRIPT_DIR/centos8-common.sh"

SERVICE_NAME=${SERVICE_NAME:-}
SERVICE_BASE_DIR=${SERVICE_BASE_DIR:-}

if [ ${#SERVICE_NAME} -eq 0 ]; then
  echo "Service name is not empty"
  exit 1;
fi


if [ ${#SERVICE_BASE_DIR} -eq 0 ]; then
  echo "Service home dir is not empty"
  exit 1;
fi

SERVICE_HOME=${SERVICE_BASE_DIR}/${SERVICE_NAME}
SERVICE_BIN=$SERVICE_HOME/bin
SERVICE_APP=$SERVICE_HOME/app
SERVICE_LIBS=$SERVICE_HOME/libs
SERVICE_CONF=$SERVICE_HOME/config
SERVICE_DATA=$SERVICE_HOME/data
SERVICE_LOGS=$SERVICE_HOME/logs
SERVICE_SCRIPTS=$SERVICE_HOME/shells

[ ! -d $SERVICE_HOME ] && { mkdir -p $SERVICE_HOME; echo "Just create $SERVICE_HOME"; }
[ ! -d $SERVICE_BIN ] && { mkdir -p $SERVICE_BIN; echo "Just create $SERVICE_BIN"; }
[ ! -d $SERVICE_APP ] && { mkdir -p $SERVICE_APP; echo "Just create $SERVICE_APP"; }
[ ! -d $SERVICE_LIBS ] && { mkdir -p $SERVICE_LIBS; echo "Just create $SERVICE_LIBS"; }
[ ! -d $SERVICE_CONF ] && { mkdir -p $SERVICE_LIBS; echo "Just create $SERVICE_CONF"; }
[ ! -d $SERVICE_DATA ] && { mkdir -p $SERVICE_DATA; echo "Just create $SERVICE_DATA"; }
[ ! -d $SERVICE_LOGS ] && { mkdir -p $SERVICE_LOGS; echo "Just create $SERVICE_LOGS"; }
[ ! -d $SERVICE_SCRIPTS ] && { mkdir -p $SERVICE_SCRIPTS; echo "Just create $SERVICE_SCRIPTS"; }

SETUP_PATH=$HOME/setups
SERVICE_SRC_PATH=${SETUP_PATH}/${SERVICE_NAME}
SERVICE_SRC_ETC_PATH=${SERVICE_SRC_PATH}/etc

SERVICE_DEPLOY_SCRIPT=$SERVICE_SCRIPTS/deploy_service.sh
is_overwrite=$(is_overwrite_file $SERVICE_DEPLOY_SCRIPT)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  SERVICE_SRC_DEPLOY_SCRIPT_PATH=$SERVICE_SRC_ETC_PATH/scripts
  [ ! -d $SERVICE_SRC_DEPLOY_SCRIPT_PATH ] && { mkdir -p $SERVICE_SRC_DEPLOY_SCRIPT_PATH; echo "create new $SERVICE_SRC_DEPLOY_SCRIPT_PATH"; }
  
  SERVICE_WORKING_DIR=$SERVICE_HOME \
  SERVICE_NAME=$SERVICE_NAME \
    envsubst< $SCRIPT_DIR/grpc/link_service.sh '${SERVICE_WORKING_DIR} ${SERVICE_NAME}' >  $SERVICE_SRC_DEPLOY_SCRIPT_PATH/deploy_service.sh
  echo "> $SERVICE_SRC_DEPLOY_SCRIPT_PATH"
  cp $SERVICE_SRC_DEPLOY_SCRIPT_PATH/deploy_service.sh $SERVICE_DEPLOY_SCRIPT && chmod +x $SERVICE_DEPLOY_SCRIPT 
fi

