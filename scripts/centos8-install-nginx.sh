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
#  echo "Usage: $0 <nginx version>"
#  echo "<nginx version>: 1.18.0 , 1.20.1  ..."
#  exit 1
#fi

NGINX_VERSION=${NGINX_VERSION:-1.20.1}

NGINX_HOME="$HOME/v$NGINX_VERSION"
NGINX_SBIN=$NGINX_HOME/sbin
NGINX_CONF=$NGINX_HOME/conf
NGINX_LOGS=$NGINX_HOME/logs

SERVICE_NAME=nginx
SERVICE_CONF_FILE=$NGINX_CONF/nginx-multi-sites.conf

user_check_sudo
if [ $? -ne 0 ]; then
  echo "please login user with sudo permission"
  return 1
fi

###################################
# Download & Build Nginx Source
###################################
SETUP_PATH=$HOME/setups
[ ! -d $SETUP_PATH ] && { mkdir -p $SETUP_PATH; echo "create $SETUP_PATH"; }


## check process running
pgrep -x nginx >/dev/null && { echo "nginx is Running, please stop service before re-install"; exit; }

################################
# Build Dependency Package
# 
#################################
install_package_from_repo pcre-devel zlib-devel openssl-devel pm2 brotli brotli-devel

#OpenSSL_VERSION="1.1.1d"
OPENSSL_VERSION="1.1.1l"
OPENSSL_SRC_FILE="openssl-${OPENSSL_VERSION}.tar.gz"
OPENSSL_URL="https://www.openssl.org/source/${OPENSSL_SRC_FILE}"
OPENSSL_SRC="$SETUP_PATH/openssl-${OPENSSL_VERSION}"
is_overwrite=$(is_overwrite_file $OPENSSL_SRC)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  ## Download source
  download_and_extract_package_from_url $SETUP_PATH/$OPENSSL_SRC_FILE $OPENSSL_URL $SETUP_PATH "tar-extract"
fi

######
NGX_BROTLI_GIT_URL="https://github.com/google/ngx_brotli.git"
NGX_BROTLI_GIT_VERSION="vlatest"
NGX_BROTLI_SRC="$SETUP_PATH/ngx_brotli-$NGX_BROTLI_GIT_VERSION"
is_overwrite=$(is_overwrite_file $NGX_BROTLI_SRC)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  [ ! -d $SETUP_PATH ] && { mkdir -p $SETUP_PATH; echo "create $SETUP_PATH"; }
  ## Download source
  [ ! -d $NGX_BROTLI_SRC ] && { \
      mkdir -p $NGX_BROTLI_SRC; \
      [ $NGX_BROTLI_GIT_VERSION == "v$CONST_VERSION_LATEST" ] \
        && { git clone --recursive $NGX_BROTLI_GIT_URL $NGX_BROTLI_SRC; } \
        || { git clone --recursive $NGX_BROTLI_GIT_URL -b $NGX_BROTLI_GIT_VERSION $NGX_BROTLI_SRC; } \
    }
fi


######
SERVICE_SRC_FILE="nginx-${NGINX_VERSION}.tar.gz"
SERVICE_SRC_URL=" http://nginx.org/download/$SERVICE_SRC_FILE"
SERVICE_SRC_PATH="$SETUP_PATH/nginx-$NGINX_VERSION"

is_overwrite=$(is_overwrite_file $SERVICE_SRC_PATH)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  ## Download source
  if [ ! -f $SERVICE_SRC_PATH ]; then
    download_and_extract_package_from_url $SETUP_PATH/$SERVICE_SRC_FILE $SERVICE_SRC_URL $SETUP_PATH "tar-extract"
  fi
  ### Build Service from source
  [ ! -d $SERVICE_SRC_PATH ] && { echo "Service Source path not exist"; exit 1; }

  echo "Starting install Nginx from source: $SERVICE_SRC_PATH"
  cd $SERVICE_SRC_PATH && $SERVICE_SRC_PATH/configure --prefix=${NGINX_HOME} --with-http_ssl_module --with-stream --with-http_v2_module --with-http_realip_module --with-http_gzip_static_module --with-file-aio --with-threads --with-http_stub_status_module --with-mail=dynamic --with-openssl=${OPENSSL_SRC} --add-module=${NGX_BROTLI_SRC}
make -j$(nproc) && make install
fi


###################################
# Sysconfig Service
###################################
SERVICE_SRC_SYSCONFIG_PATH=$SERVICE_SRC_PATH/etc
[ ! -d $SERVICE_SRC_SYSCONFIG_PATH ] && { mkdir -p $SERVICE_SRC_SYSCONFIG_PATH; echo "create new $SERVICE_SRC_SYSCONFIG_PATH"; }

SERVICE_SYSCONFIG=/etc/sysconfig/$SERVICE_NAME
is_overwrite=$(is_overwrite_file_with_sudo $SERVICE_SYSCONFIG)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  ##
  SYSCONFIG_PATH=$SERVICE_SRC_SYSCONFIG_PATH/sysconfig
  [ ! -d $SYSCONFIG_PATH ] && { mkdir -p $SYSCONFIG_PATH; echo "create new $SYSCONFIG_PATH"; }
  ###
  NGINX_HOME=$NGINX_HOME \
  SERVICE_CONF_FILE=$SERVICE_CONF_FILE \
    envsubst< $SCRIPT_DIR/nginx/$SERVICE_NAME.sysconfig '$NGINX_HOME $SERVICE_CONF_FILE'>  "$SYSCONFIG_PATH/$SERVICE_NAME.sysconfig"

  echo "> $SERVICE_SYSCONFIG"
  sudo cp $SYSCONFIG_PATH/$SERVICE_NAME.sysconfig $SERVICE_SYSCONFIG
fi
###################################
# SystemD Service
###################################
SERIVICE_SYSTEMD=/etc/systemd/system/$SERVICE_NAME.service
is_overwrite=$(is_overwrite_file_with_sudo $SERIVICE_SYSTEMD)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  ##
  SYSTEMD_PATH=$SERVICE_SRC_SYSCONFIG_PATH/systemd/system
  [ ! -d $SYSTEMD_PATH ] && { mkdir -p $SYSTEMD_PATH; echo "create new $SYSTEMD_PATH"; }
  ###
  export SERVICE_USER="root"; \
  export SERVICE_GROUP=$USER; \
  export SERVICE_SYSCONFIG=$SERVICE_SYSCONFIG; \
  export SERVICE_SERVER=$NGINX_SBIN/nginx; \
  export SERVICE_WORKING_FOLDER=$NGINX_HOME; \
  export SERVICE_PIDFILE=$NGINX_LOGS/nginx.pid;\
    cat $SCRIPT_DIR/nginx/$SERVICE_NAME.service | envsubst '$SERVICE_USER ${SERVICE_GROUP} ${SERVICE_SYSCONFIG} ${SERVICE_SERVER} ${SERVICE_WORKING_FOLDER} ${SERVICE_PIDFILE}' > "$SYSTEMD_PATH/$SERVICE_NAME.service"

  echo "> /etc/systemd/system/$SERVICE_NAME.service"
  sudo cp $SYSTEMD_PATH/$SERVICE_NAME.service $SERIVICE_SYSTEMD

  echo "> Enable $SERVICE_NAME.service"
  sudo systemctl enable $SERVICE_NAME.service
fi

###################################
# Sudoers Service
###################################
SERVICE_SUDOER=/etc/sudoers.d/$SERVICE_NAME
is_overwrite=$(is_overwrite_file_with_sudo $SERVICE_SUDOER)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  SUDOERS_PATH=$SERVICE_SRC_SYSCONFIG_PATH/sudoers.d
  [ ! -d $SUDOERS_PATH ] && { mkdir -p $SUDOERS_PATH; echo "create new $SUDOERS_PATH"; }
  
  SERVICE_NAME=$SERVICE_NAME \
  SERVICE_GROUP=$USER \
    envsubst< $SCRIPT_DIR/nginx/$SERVICE_NAME.sudoers >  $SUDOERS_PATH/$SERVICE_NAME.sudoers
  echo "> /etc/sudoers.d/$SERVICE_SUDOER"
  sudo cp $SUDOERS_PATH/$SERVICE_NAME.sudoers $SERVICE_SUDOER
fi

###################################
# Configuration Service
###################################
[ ! -d ${NGINX_CONF}/sites-enabled ] && { mkdir -p ${NGINX_CONF}/sites-enabled; echo "create new ${NGINX_CONF}/sites-enabled"; }
[ ! -d ${NGINX_CONF}/sites-availables ] && { mkdir -p ${NGINX_CONF}/sites-availables; echo "create new ${NGINX_CONF}/sites-availables"; }

is_overwrite=$(is_overwrite_file $SERVICE_CONF_FILE)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  CONF_PATH=$SERVICE_SRC_SYSCONFIG_PATH
  [ ! -d $CONF_PATH ] && { mkdir -p $CONF_PATH; echo "create new $CONF_PATH"; }
  
  export SERVICE_NAME=$SERVICE_NAME; \
  export SERVICE_USER=$USER; \
  export SERVICE_GROUP=$USER; \
  export SERVICE_HOME=${NGINX_HOME}; \
    envsubst< $SCRIPT_DIR/nginx/$SERVICE_NAME.conf '${SERVICE_USER} ${SERVICE_HOME}'>  $CONF_PATH/$SERVICE_NAME.conf
  echo "> /$SERVICE_CONF_FILE"
  cp $CONF_PATH/$SERVICE_NAME.conf $SERVICE_CONF_FILE
fi

exit 1






