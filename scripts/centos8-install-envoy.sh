#!/usr/bin/bash

###############
# Load common
###############
SCRIPT_DIR=$(dirname $0)
source "$SCRIPT_DIR/centos8-common.sh"

###############
# Execute
###############
#if [ $# -ne 1 ]; then
#  echo "$0: invalid input parameters ($#)"
#  echo "Usage: $0 <envoy version>"
#  echo "<envoy version>: 1.18.3, 1.19.0 ..."
#  exit 1
#fi

ENVOY_VERSION=${ENVOY_VERSION:-1.19.0}
ENVOY_ADMIN_PORT=${ENVOY_ADMIN_PORT:-3888}

ENVOY_HOME="$HOME/v$ENVOY_VERSION"
ENVOY_CONF=$ENVOY_HOME/conf
ENVOY_LOGS=$ENVOY_HOME/logs
ENVOY_DATA=$ENVOY_HOME/data
ENVOY_PLUGGIN=$ENVOY_HOME/plugins
ENVOY_SERVER=$HOME/.func-e/versions/$ENVOY_VERSION/bin/envoy

SERVICE_NAME=envoy

user_check_sudo
if [ $? -ne 0 ]; then
  echo "please login user with sudo permission"
  return 1
fi

## Create new folder if not exist
[ ! -d $ENVOY_HOME ] && { mkdir -p $ENVOY_HOME; echo "create $ENVOY_HOME"; }
[ ! -d $ENVOY_CONF ] && { mkdir -p $ENVOY_CONF; echo "create $ENVOY_CONF"; }
[ ! -d $ENVOY_LOGS ] && { mkdir -p $ENVOY_LOGS; echo "create $ENVOY_LOGS"; }
[ ! -d $ENVOY_DATA ] && { mkdir -p $ENVOY_DATA; echo "create $ENVOY_DATA"; }
[ ! -d $ENVOY_PLUGGIN ] && { mkdir -p $ENVOY_PLUGGIN; echo "create $ENVOY_PLUGGIN"; }

####
## install 'func-e' if not exist
[ -f /usr/local/bin/func-e ] || { curl -L https://getenvoy.io/install.sh | sudo bash -s -- -b /usr/local/bin; }
func-e use $ENVOY_VERSION
if [ ! -f $ENVOY_SERVER ]; then
  echo "envoy $ENVOY_VERSION was not installed"
 echo "$ENVOY_APP"
  echo "please correct version, ex: 1.19.0, 1.18.3 ..."
  exit 1
fi

########################
# Envoy Sample Config
########################
SETUP_PATH=$HOME/setups
SERVICE_SRC_PATH=${SETUP_PATH}/envoy-v${ENVOY_VERSION}
SERVICE_SRC_SYSCONFIG_PATH=${SERVICE_SRC_PATH}/etc

[ ! -d $SERVICE_SRC_PATH ] && { mkdir -p $SERVICE_SRC_PATH; echo "create $SERVICE_SRC_PATH"; }
[ ! -d $SERVICE_SRC_SYSCONFIG_PATH ] && { mkdir -p $SERVICE_SRC_SYSCONFIG_PATH; echo "create $SERVICE_SRC_SYSCONFIG_PATH"; }

is_overwrite=$(is_overwrite_file $ENVOY_CONF/envoy.yaml)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then

    [ ! -d $SERVICE_SRC_SYSCONFIG_PATH/conf ] && { mkdir -p $SERVICE_SRC_SYSCONFIG_PATH/conf; echo "create $SERVICE_SRC_SYSCONFIG_PATH/conf"; }
    ENVOY_ADMIN_PORT=${ENVOY_ADMIN_PORT} \
    ENVOY_ADMIN_LOG_FILE=${ENVOY_LOGS}/admin_access.log \
    ENVOY_ADMIN_PROFILE=${ENVOY_DATA}/envoy.prof \
      envsubst< $SCRIPT_DIR/envoy/envoy.yaml >  $SERVICE_SRC_SYSCONFIG_PATH/conf/envoy.yaml
    [ -f $ENVOY_CONF/envoy.yaml ] && { cp $ENVOY_CONF/envoy.yaml $ENVOY_CONF/envoy-$(date +%s).yaml; }
    echo "Create/Overwrite $ENVOY_CONF/envoy.yaml"
    cp $SERVICE_SRC_SYSCONFIG_PATH/conf/envoy.yaml $ENVOY_CONF/envoy.yaml
fi

###################################
# Sysconfig Service
###################################
ENVOY_SYSCONFIG=/etc/sysconfig/$SERVICE_NAME
is_overwrite=$(is_overwrite_file_with_sudo $ENVOY_SYSCONFIG)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  ##
  SYSCONFIG_PATH=$SERVICE_SRC_SYSCONFIG_PATH/sysconfig
  [ ! -d $SYSCONFIG_PATH ] && { mkdir -p $SYSCONFIG_PATH; echo "create new $SYSTEMD_PATH"; }
  ###
  SERVICE_USER=$USER \
  SERVICE_GROUP=$USER \
  ENVOY_SERVER=$ENVOY_SERVER \
  ENVOY_HOME=$ENVOY_HOME \
  ENVOY_CONF=$ENVOY_CONF \
  ENVOY_LOGS=$ENVOY_LOGS \
  ENVOY_DATA=$ENVOY_DATA \
    envsubst< $SCRIPT_DIR/envoy/envoy.sysconfig >  "$SYSCONFIG_PATH/$SERVICE_NAME.service"

  echo "> $ENVOY_SYSCONFIG"
  sudo cp $SYSCONFIG_PATH/$SERVICE_NAME.service $ENVOY_SYSCONFIG
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
  export ENVOY_SERVER=$ENVOY_SERVER; \
  export ENVOY_SYSCONFIG=$ENVOY_SYSCONFIG; \
  export ENVOY_LOGS=$ENVOY_LOGS; \
  export SERVICE_WORKING_FOLDER=$ENVOY_HOME; \
    cat $SCRIPT_DIR/envoy/envoy.service | envsubst '$SERVICE_USER ${SERVICE_GROUP} ${ENVOY_SERVER} ${ENVOY_SYSCONFIG} ${ENVOY_LOGS} ${SERVICE_WORKING_FOLDER}' > "$SYSTEMD_PATH/$SERVICE_NAME.service"

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
    envsubst< $SCRIPT_DIR/envoy/envoy.sudoers >  $SUDOERS_PATH/$SERVICE_NAME
  echo "> /etc/sudoers.d/$SERVICE_NAME"
  sudo cp $SUDOERS_PATH/$SERVICE_NAME /etc/sudoers.d/$SERVICE_NAME
fi





