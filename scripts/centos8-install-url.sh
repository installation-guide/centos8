#!/usr/bin/bash

###############
# Load common
###############
SCRIPT_DIR=$(dirname $0)
source "$SCRIPT_DIR/centos8-common.sh"

###############
# Execute
###############
if [ $# -ne 6 ]; then
  echo "$0: invalid input parameters ($#)"
  exit 1
fi
PACKAGE_NAME=$1
PACKAGE_PATH=$2
PACKAGE_URL=$3
TEMP=$4
OUTPUT=$5
COMMAND_TYPE=$6
####
install_package_from_url $PACKAGE_NAME $PACKAGE_PATH $PACKAGE_URL $TEMP $OUTPUT $COMMAND_TYPE
