#!/usr/bin/bash

###############
# Load common
###############
SCRIPT_DIR=$(dirname $0)
source "$SCRIPT_DIR/centos8-common.sh"

###############
# Execute
###############
if [ $# -ne 1 ]; then
  echo "$0: invalid input parameters ($#)"
  echo "Usage: $0 <envoy version>"
  echo "<envoy version>: 1.18.3, 1.19.0 ..."
  exit 1
fi
ENVOY_VERSION=$1
ENVOY_HOME="$HOME/v$ENVOY_VERSION"
ENVOY_CONF=$ENVOY_HOME/conf
ENVOY_LOGS=$ENVOY_HOME/logs
ENVOY_DATA=$ENVOY_HOME/data
ENVOY_PLUGGIN=$ENVOY_HOME/plugins
ENVOY_APP=$HOME/.func-e/versions/$ENVOY_VERSION/bin/envoy

SERVICE_NAME=envoy

user_check_sudo
if [ $? -ne 0 ]; then
  echo "please login user with sudo permission"
  return 1
fi

## install 'func-e' if not exist
[ -f /usr/local/bin/func-e ] || { curl -L https://getenvoy.io/install.sh | sudo bash -s -- -b /usr/local/bin; }

## Create new folder if not exist
[ ! -d $ENVOY_HOME ] && { mkdir -p $ENVOY_HOME; echo "create $ENVOY_HOME"; }
[ ! -d $ENVOY_CONF ] && { mkdir -p $ENVOY_CONF; echo "create $ENVOY_CONF"; }
[ ! -d $ENVOY_LOGS ] && { mkdir -p $ENVOY_LOGS; echo "create $ENVOY_LOGS"; }
[ ! -d $ENVOY_DATA ] && { mkdir -p $ENVOY_DATA; echo "create $ENVOY_DATA"; }
[ ! -d $ENVOY_PLUGGIN ] && { mkdir -p $ENVOY_PLUGGIN; echo "create $ENVOY_PLUGGIN"; }

####
func-e use $ENVOY_VERSION
if [ ! -f $ENVOY_APP ]; then
  echo "envoy $ENVOY_VERSION was not installed"
  echo "$ENVOY_APP"
  echo "please correct version, ex: 1.19.0, 1.18.3 ..."
  exit 1
fi

########################
# Envoy Sample Config
########################
IS_OVERWRITE='Y'
if [ -f $ENVOY_CONF/envoy.yaml ]; then
  read -p "do you overwrite '$ENVOY_CONF/envoy.yaml' [Y/N]?" overwrite
  if [[ $overwrite == "Y" || $overwrite == "y" ]]; then
    IS_OVERWRITE='Y'
  else
    IS_OVERWRITE='N'
  fi
fi

if [[ $IS_OVERWRITE == "Y" || $IS_OVERWRITE == "y" ]]; then
tee $ENVOY_CONF/envoy.yaml > /dev/null <<'EOF'
admin:
  address:
    socket_address: { address: 127.0.0.1, port_value: 9901 }
EOF
fi

########################
# System Config
########################
IS_OVERWRITE='Y'
if [ -f /etc/sysconfig/envoy ]; then
  read -p "do you overwrite '/etc/sysconfig/envoy' [Y/N]?" overwrite
  if [[ $overwrite == "Y" || $overwrite == "y" ]]; then
    IS_OVERWRITE='Y'
  else
    IS_OVERWRITE='N'
  fi
fi

if [[ $IS_OVERWRITE == "Y" || $IS_OVERWRITE == "y" ]]; then

IFS='' read -r -d '' VAR <<"EOF"
ENOVY_HOME_DIR=VAR_ENVOY_HOME
\nENVOY_CONF_DIR=VAR_ENVOY_CONF
\nENVOY_LOG_DIR=VAR_ENVOY_LOGS
\nENVOY_DATA_DIR=VAR_ENVOY_DATA
\nENVOY_CONFIG_FILE=VAR_ENVOY_CONF/envoy.yaml
\nENVOY_LOGGING_ACCESS_FILE=VAR_ENVOY_LOG_DIR/envoy_main.log
EOF

  VAR=${VAR//VAR_ENVOY_HOME/${ENVOY_HOME}}
  VAR=${VAR//VAR_ENVOY_CONF/${ENVOY_CONF}}
  VAR=${VAR//VAR_ENVOY_LOGS/${ENVOY_LOGS}}
  VAR=${VAR//VAR_ENVOY_DATA/${ENVOY_DATA}}
  VAR=${VAR//VAR_ENVOY_LOG_DIR/${ENVOY_LOGS}}
  echo "> /etc/sysconfig/envoy"
  echo -e $VAR | sudo tee /etc/sysconfig/envoy > /dev/null

fi


########################
# SystemD Service
########################
IS_OVERWRITE='Y'
if [ -f /etc/systemd/system/$SERVICE_NAME.service ]; then
  read  -p "do you overwrite '/etc/systemd/system/$SERVICE_NAME.service' [Y/N]?" overwrite
  if [[ $overwrite == "Y" || $overwrite == "y" ]]; then
    IS_OVERWRITE='Y'
  else
    IS_OVERWRITE='N'
  fi
fi


if [[ $IS_OVERWRITE == "Y" || $IS_OVERWRITE == "y" ]]; then

IFS='' read -r -d '' VAR <<"EOF"
[Unit]
\nDescription= Cloud-native high-performance edge/middle/service proxy (Envoy)
\nDocumentation=https://www.envoyproxy.io
\nRequires=network.target remote-fs.target
\nAfter=network.target remote-fs.target
\nConditionPathExists=$ENOVY_HOME_DIR
\nConditionPathExists=$ENVOY_LOG_DIR
\nConditionPathExists=$ENVOY_DATA_DIR
\n
\n[Service]
\nType=simple
\nUser=root
\nGroup=envoy
\nEnvironmentFile=/etc/sysconfig/envoy
\nExecStart=VAR_ENVOY_APP -c $ENVOY_CONFIG_FILE --log-path $ENVOY_LOGGING_ACCESS_FILE
\n#Restart=on-failure
\nExecStartPre=/usr/bin/touch $ENVOY_LOGGING_ACCESS_FILE
\n[Install]
\nWantedBy=multi-user.target
EOF

  VAR=${VAR//VAR_ENVOY_APP/${ENVOY_APP}}
  echo "> /etc/systemd/system/$SERVICE_NAME.service"
  echo -e $VAR | sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null

  echo "> Enable $SERVICE_NAME.service"
  sudo systemctl enable $SERVICE_NAME.service
fi


########################
# Sudoer Service
########################
IS_OVERWRITE='Y'
if sudo test -f /etc/sudoers.d/$SERVICE_NAME; then
  read -p "do you overwrite '/etc/sudoers.d/$SERVICE_NAME ' [Y/N]?" overwrite
  if [[ $overwrite == "Y" || $overwrite == "y" ]]; then
    IS_OVERWRITE='Y'
  else
    IS_OVERWRITE='N'
  fi
fi

if [[ $IS_OVERWRITE == "Y" || $IS_OVERWRITE == "y" ]]; then
IFS='' read -r -d '' VAR <<"EOF"
%envoy ALL=(root) /usr/sbin/reboot
\n%envoy ALL=(root) NOPASSWD: /bin/journalctl -xe
\n%envoy ALL=(root) NOPASSWD: /bin/systemctl stop VAR_SERVICE_NAME.service,/bin/systemctl start VAR_SERVICE_NAME.service,/bin/systemctl restart VAR_SERVICE_NAME.service,/bin/systemctl status VAR_SERVICE_NAME.service
\n%envoy ALL=(root) NOPASSWD: /bin/systemctl stop VAR_SERVICE_NAME,/bin/systemctl start VAR_SERVICE_NAME,/bin/systemctl restart VAR_SERVICE_NAME,/bin/systemctl status VAR_SERVICE_NAME
EOF

  VAR=${VAR//VAR_SERVICE_NAME/${SERVICE_NAME}}
  echo "> /etc/sudoers.d/$SERVICE_NAME"
  echo -e $VAR | sudo tee /etc/sudoers.d/$SERVICE_NAME  > /dev/null
fi

