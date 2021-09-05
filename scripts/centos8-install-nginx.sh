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
OpenSSL_VERSION="1.1.1l"
OpenSSL_SRC_FILE="openssl-${OpenSSL_VERSION}.tar.gz"
OpenSSL_URL="https://www.openssl.org/source/${OpenSSL_SRC_FILE}"
OpenSSL_SRC="$SETUP_PATH/openssl-${OpenSSL_VERSION}"
is_overwrite=$(is_overwrite_file $OpenSSL_SRC)
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  ## Download source
  download_and_extract_package_from_url $SETUP_PATH/$OpenSSL_SRC_FILE $OpenSSL_URL $SETUP_PATH "tar-extract"
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

if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  ## Download source
  download_and_extract_package_from_url $SETUP_PATH/$OpenSSL_SRC_FILE $OpenSSL_URL $SETUP_PATH "tar-extract"
fi


###################################
# Sysconfig Service
###################################
SERVICE_SRC_SYSCONFIG_PATH=$SERVICE_SRC_PATH/etc
[ ! -d $SERVICE_SRC_CONFIG_PATH ] && { mkdir -p $SERVICE_SRC_CONFIG_PATH; echo "create new $SERVICE_SRC_CONFIG_PATH"; }

exit 1






