#!/usr/bin/bash

###############
# Load common
###############
SCRIPT_DIR=$(dirname $0)
source "$SCRIPT_DIR/centos8-common.sh"

SDK_GCC='gcc'
SDK_OPEN_JDK='open-jdk'
SDK_ORACLE_JDK='oracle-jdk'
SDK_VERTX='vertx'
SDK_GOLANG='golang'
SDK_NODEJS='nodejs'
SDK_MINICONDA3='miniconda3'

###############
# Execute
###############
if [ $# -ne 1 ]; then
  echo "$0: invalid input parameters ($#)"
  echo "Usage: $0 <sdk config file>"
  echo "Format File:"
  echo "   <sdk name>:<version>"
  echo "SDK Supported: $SDK_GCC, $SDK_OPEN_JDK, $SDK_ORACLE_JDK, $SDK_VERTX, $SDK_GOLANG, $SDK_NODEJS, $SDK_MINICONDA3"
  exit 1 
fi

SDK_CONFIG_FILE=$1


user_check_sudo
if [ $? -ne 0 ]; then
  echo "please login user with sudo permission"
  return 1
fi

line_start=$1
filename=$2
I=0
while IFS= read -r line; do
  if [ $((I++)) -lt $line_start ]; then
    continue
  fi
  fields=($(echo $line | tr ":" "\n"))
  if [ ${#fields[*]} -ge 2 ]; then
    sdk_name=${fields[0]}
    sdk_version=${fields[1]}
    case $sdk_name in
      $SDK_GCC)
        ;;
      $SDK_OPEN_JDK)
        ;;
      $SDK_ORACLE_JDK)
        ;;
      $SDK_VERTX)
        ;;
      $SDK_GOLANG)
        ;;
      $SDK_NODEJS)
        ;;
      $SDK_MINICONDA3)
        SETUP_PATH=$HOME/setups; \
        PACKAGE_VERSION="py39_4.10.3"; \
        PACKAGE_NAME="Miniconda3-${PACKAGE_VERSION}-Linux-x86_64.sh"; \
        PACKAGE_PATH=$SETUP_PATH/$PACKAGE_NAME; \
        PACKAGE_URL="https://repo.anaconda.com/miniconda/$PACKAGE_NAME"; \
        TEMP="null"; \
        OUTPUT="/opt/Miniconda3/conda-${PACKAGE_VERSION}"; \
        COMMAND_TYPE="miniconda3"; \
        $SETUP_PATH/centos8-install-url.sh $PACKAGE_NAME $PACKAGE_PATH $PACKAGE_URL $TEMP $OUTPUT $COMMAND_TYPE
        ;;
      *)
      echo "not supported: $sdk_name, $sdk_version"
        ;;
      esac
    #echo "[$I] $line"
    #echo "[$I] ${fields[0]} - ${fields[1]} - ${fields[2]} - ${fields[3]}"
  fi
done < "$filename"
