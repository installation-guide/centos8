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
REDIS_VERSION=$1
REDIS_HOME="$HOME/v$REDIS_VERSION"
REDIS_CONF=$REDIS_HOME/conf
REDIS_LOGS=$REDIS_HOME/logs
REDIS_DATA=$REDIS_HOME/data
REDIS_PLUGGIN=$REDIS_HOME/plugins
REDIS_APP=$HOME/.func-e/versions/$REDIS_VERSION/bin/envoy

SERVICE_NAME=envoy

user_check_sudo
if [ $? -ne 0 ]; then
  echo "please login user with sudo permission"
  return 1
fi

## install 'func-e' if not exist
[ -f /usr/local/bin/func-e ] || { curl -L https://getenvoy.io/install.sh | sudo bash -s -- -b /usr/local/bin; }

## Create new folder if not exist
[ ! -d $REDIS_HOME ] && { mkdir -p $REDIS_HOME; echo "create $REDIS_HOME"; }
[ ! -d $REDIS_CONF ] && { mkdir -p $REDIS_CONF; echo "create $REDIS_CONF"; }
[ ! -d $REDIS_LOGS ] && { mkdir -p $REDIS_LOGS; echo "create $REDIS_LOGS"; }
[ ! -d $REDIS_DATA ] && { mkdir -p $REDIS_DATA; echo "create $REDIS_DATA"; }
[ ! -d $REDIS_PLUGGIN ] && { mkdir -p $REDIS_PLUGGIN; echo "create $REDIS_PLUGGIN"; }

####
func-e use $REDIS_VERSION
if [ ! -f $REDIS_APP ]; then
  echo "envoy $REDIS_VERSION was not installed"
  echo "$REDIS_APP"
  echo "please correct version, ex: 1.19.0, 1.18.3 ..."
  exit 1
fi

########################
# Envoy Sample Config
########################
IS_OVERWRITE='Y'
if [ -f $REDIS_CONF/envoy.yaml ]; then
  read -p "do you overwrite '$REDIS_CONF/envoy.yaml' [Y/N]?" overwrite
  if [[ $overwrite == "Y" || $overwrite == "y" ]]; then
    IS_OVERWRITE='Y'
  else
    IS_OVERWRITE='N'
  fi
fi

if [[ $IS_OVERWRITE == "Y" || $IS_OVERWRITE == "y" ]]; then
tee $REDIS_CONF/envoy.yaml > /dev/null <<'EOF'
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
ENOVY_HOME_DIR=VAR_REDIS_HOME
\nREDIS_CONF_DIR=VAR_REDIS_CONF
\nREDIS_LOG_DIR=VAR_REDIS_LOGS
\nREDIS_DATA_DIR=VAR_REDIS_DATA
\nREDIS_CONFIG_FILE=VAR_REDIS_CONF/envoy.yaml
\nREDIS_LOGGING_ACCESS_FILE=VAR_REDIS_LOG_DIR/REDIS_main.log
EOF

  VAR=${VAR//VAR_REDIS_HOME/${REDIS_HOME}}
  VAR=${VAR//VAR_REDIS_CONF/${REDIS_CONF}}
  VAR=${VAR//VAR_REDIS_LOGS/${REDIS_LOGS}}
  VAR=${VAR//VAR_REDIS_DATA/${REDIS_DATA}}
  VAR=${VAR//VAR_REDIS_LOG_DIR/${REDIS_LOGS}}
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
\nConditionPathExists=$REDIS_LOG_DIR
\nConditionPathExists=$REDIS_DATA_DIR
\n
\n[Service]
\nType=simple
\nUser=root
\nGroup=envoy
\nEnvironmentFile=/etc/sysconfig/envoy
\nExecStart=VAR_REDIS_APP -c $REDIS_CONFIG_FILE --log-path $REDIS_LOGGING_ACCESS_FILE
\n#Restart=on-failure
\nExecStartPre=/usr/bin/touch $REDIS_LOGGING_ACCESS_FILE
\n[Install]
\nWantedBy=multi-user.target
EOF

  VAR=${VAR//VAR_REDIS_APP/${REDIS_APP}}
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

