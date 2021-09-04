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



