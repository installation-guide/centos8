#!/usr/bin/bash
SETUP_PATH=$HOME/setups
[ ! -d $SETUP_PATH ] && { mkdir -p $SETUP_PATH; echo "just created $SETUP_PATH"; }

if [ ! -f "$SETUP_PATH/centos8-common.sh" ]; then
  echo "not existed $SETUP_PATH/centos8-common.sh"
  exit 1
fi
###############
# Load common
###############
source "$SETUP_PATH/centos8-common.sh"

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
