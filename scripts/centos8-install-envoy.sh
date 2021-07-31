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
ENVOY_VERSION=$1
ENVOY_HOME=$2
ENVOY_CONF=$ENVOY_HOME/conf
ENVOY_LOGS=$ENVOY_HOME/logs
ENVOY_DATA=$ENVOY_HOME/data
ENVOY_PLUGGIN=$ENVOY_HOME/plugins
ENVOY_APP=$HOME/.func-e/versions/$ENVOY_VERSION/bin/envoy

ENOVY_SERVICE_NAME=envoy


## Create new folder if not exist
[ ! -d $ENVOY_HOME ] && {mkdir -p $ENVOY_HOME; echo "create $ENVOY_HOME";}
[ ! -d $ENVOY_CONF ] && {mkdir -p $ENVOY_CONF; echo "create $ENVOY_CONF";}
[ ! -d $ENVOY_LOGS ] && {mkdir -p $ENVOY_LOGS; echo "create $ENVOY_LOGS";}
[ ! -d $ENVOY_DATA ] && {mkdir -p $ENVOY_DATA; echo "create $ENVOY_DATA";}
[ ! -d $ENVOY_PLUGGIN ] && {mkdir -p $ENVOY_PLUGGIN; echo "create $ENVOY_PLUGGIN";}

####
func-e use $ENVOY_VERSION
if [ -f $ENVOY_APP ]; then
  echo "envoy $ENVOY_VERSION was not installed"
  echo "please correct version, ex: 1.19.0, 1.18.3 ..."
  exit 1
fi

user_check_sudo
if [ $? -ne 0 ]; then
  echo "please login user with sudo permission"
  return 1
fi

sudo sudo tee /etc/sysconfig/envoy > /dev/null <<'EOF'
ENOVY_HOME_DIR=$ENVOY_HOME
ENVOY_CONF_DIR=$ENVOY_CONF
ENVOY_LOG_DIR=$ENVOY_LOGS
ENVOY_DATA_DIR=/$ENVOY_DATA
ENVOY_CONFIG_FILE=$ENVOY_CONF/envoy.yaml
ENVOY_LOGGING_ACCESS_FILE=$ENVOY_LOG_DIR/envoy_main.log
EOF

if [ ! -f /etc/sysconfig/envoy ]; then
  echo "envoy sysconfig not existed"
  exit 1
fi

sudo tee /etc/systemd/system/envoy.service > /dev/null <<'EOF'
[Unit]
Description= Cloud-native high-performance edge/middle/service proxy (Envoy)
Documentation=https://www.envoyproxy.io
Requires=network.target remote-fs.target
After=network.target remote-fs.target
ConditionPathExists=$ENOVY_HOME_DIR
ConditionPathExists=$ENVOY_LOG_DIR
ConditionPathExists=$ENVOY_DATA_DIR

[Service]
Type=simple
User=root
Group=envoy
EnvironmentFile=/etc/sysconfig/envoy
ExecStart=$$ENVOY_APP -c $ENVOY_CONFIG --log-path $ENVOY_LOGGING_ACCESS_FILE
#Restart=on-failure
ExecStartPre=/usr/bin/touch $ENVOY_LOGGING_ACCESS_FILE
[Install]
WantedBy=multi-user.target
EOF

if [ ! -f /etc/systemd/system/envoy.service ]; then
  echo "envoy systemd not existed"
  exit 1
fi


sudo tee /etc/sudoers.d/$ENOVY_SERVICE_NAME > /dev/null <<'EOF'
%envoy ALL=(root) /usr/sbin/reboot
%envoy ALL=(root) NOPASSWD: /bin/journalctl -xe
%envoy ALL=(root) NOPASSWD: /bin/systemctl stop ${ENOVY_SERVICE_NAME}.service,/bin/systemctl start ${ENOVY_SERVICE_NAME}.service,/bin/systemctl restart ${ENOVY_SERVICE_NAME}.service,/bin/systemctl status ${ENOVY_SERVICE_NAME}.service
%envoy ALL=(root) NOPASSWD: /bin/systemctl stop ${ENOVY_SERVICE_NAME},/bin/systemctl start ${ENOVY_SERVICE_NAME},/bin/systemctl restart ${ENOVY_SERVICE_NAME},/bin/systemctl status ${ENOVY_SERVICE_NAME}
EOF

if [ ! -f /etc/sudoers.d/$ENOVY_SERVICE_NAME ]; then
  echo "envoy systemd not existed"
  exit 1
fi

