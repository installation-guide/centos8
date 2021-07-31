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

## by pass 4 first line
START_LINE=4

###############
# Execute
###############
if [ $# -ne 2 ]; then
  echo "Usage $0 <action> <user file>"
  echo "<action>:"
  echo "  + password: update password the existed user in <user file>"
  echo "  + create: create new user if not existed"
  echo "<user file>: user information include: user, belong to groups, home dir, password"
  exit 1
fi
ACTION=$1
USER_FILE=$2
####
init_os_groups
case $ACTION in
  password)
    users_reset_password $START_LINE $USER_FILE
    ;;
  create)
    echo "args: $START_LINE $USER_FILE"
    init_os_users $START_LINE $USER_FILE
    ;;
  *)
  echo "not supported: $group, $group_type"
    ;;
  esac
