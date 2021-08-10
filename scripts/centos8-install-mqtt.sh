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
MOSQUITTO_VERSION=$1
MOSQUITTO_HOME="$HOME/v$MOSQUITTO_VERSION"
MOSQUITTO_CONF=$MOSQUITTO_HOME/conf
MOSQUITTO_LOGS=$MOSQUITTO_HOME/logs
MOSQUITTO_DATA=$MOSQUITTO_HOME/data
MOSQUITTO_PLUGGIN=$MOSQUITTO_HOME/plugins
MOSQUITTO_APP=$MOSQUITTO_HOME/bin/envoy

SERVICE_NAME=mqtt

user_check_sudo
if [ $? -ne 0 ]; then
  echo "please login user with sudo permission"
  return 1
fi

## Create new folder if not exist
[ ! -d $MOSQUITTO_HOME ] && { mkdir -p $MOSQUITTO_HOME; echo "create $MOSQUITTO_HOME"; }
[ ! -d $MOSQUITTO_CONF ] && { mkdir -p $MOSQUITTO_CONF; echo "create $MOSQUITTO_CONF"; }
[ ! -d $MOSQUITTO_LOGS ] && { mkdir -p $MOSQUITTO_LOGS; echo "create $MOSQUITTO_LOGS"; }
[ ! -d $MOSQUITTO_DATA ] && { mkdir -p $MOSQUITTO_DATA; echo "create $MOSQUITTO_DATA"; }
[ ! -d $MOSQUITTO_PLUGGIN ] && { mkdir -p $MOSQUITTO_PLUGGIN; echo "create $MOSQUITTO_PLUGGIN"; }

####
## install 'func-e' if not exist
[ -f /usr/local/bin/func-e ] || { curl -L https://getenvoy.io/install.sh | sudo bash -s -- -b /usr/local/bin; }
func-e use $MOSQUITTO_VERSION
if [ ! -f $MOSQUITTO_APP ]; then
  echo "envoy $MOSQUITTO_VERSION was not installed"
  echo "$MOSQUITTO_APP"
  echo "please correct version, ex: 1.19.0, 1.18.3 ..."
  exit 1
fi

########################
# Envoy Sample Config
########################
IS_OVERWRITE='Y'
if [ -f $MOSQUITTO_CONF/envoy.yaml ]; then
  read -p "do you overwrite '$MOSQUITTO_CONF/envoy.yaml' [Y/N]?" overwrite
  if [[ $overwrite == "Y" || $overwrite == "y" ]]; then
    IS_OVERWRITE='Y'
  else
    IS_OVERWRITE='N'
  fi
fi

if [[ $IS_OVERWRITE == "Y" || $IS_OVERWRITE == "y" ]]; then
tee $MOSQUITTO_CONF/envoy.yaml > /dev/null <<'EOF'
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
ENOVY_HOME_DIR=VAR_MOSQUITTO_HOME
\nMOSQUITTO_CONF_DIR=VAR_MOSQUITTO_CONF
\nMOSQUITTO_LOG_DIR=VAR_MOSQUITTO_LOGS
\nMOSQUITTO_DATA_DIR=VAR_MOSQUITTO_DATA
\nMOSQUITTO_CONFIG_FILE=VAR_MOSQUITTO_CONF/envoy.yaml
\nMOSQUITTO_LOGGING_ACCESS_FILE=VAR_MOSQUITTO_LOG_DIR/MOSQUITTO_main.log
EOF

  VAR=${VAR//VAR_MOSQUITTO_HOME/${MOSQUITTO_HOME}}
  VAR=${VAR//VAR_MOSQUITTO_CONF/${MOSQUITTO_CONF}}
  VAR=${VAR//VAR_MOSQUITTO_LOGS/${MOSQUITTO_LOGS}}
  VAR=${VAR//VAR_MOSQUITTO_DATA/${MOSQUITTO_DATA}}
  VAR=${VAR//VAR_MOSQUITTO_LOG_DIR/${MOSQUITTO_LOGS}}
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
\nConditionPathExists=$MOSQUITTO_LOG_DIR
\nConditionPathExists=$MOSQUITTO_DATA_DIR
\n
\n[Service]
\nType=simple
\nUser=root
\nGroup=envoy
\nEnvironmentFile=/etc/sysconfig/envoy
\nExecStart=VAR_MOSQUITTO_APP -c $MOSQUITTO_CONFIG_FILE --log-path $MOSQUITTO_LOGGING_ACCESS_FILE
\n#Restart=on-failure
\nExecStartPre=/usr/bin/touch $MOSQUITTO_LOGGING_ACCESS_FILE
\n[Install]
\nWantedBy=multi-user.target
EOF

  VAR=${VAR//VAR_MOSQUITTO_APP/${MOSQUITTO_APP}}
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

