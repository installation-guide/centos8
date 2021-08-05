#!/usr/bin/bash

###############
# Load common
###############
SCRIPT_DIR=$(dirname $0)
source "$SCRIPT_DIR/centos8-common.sh"

###############
# Execute
###############
REDIS_VERSION=${REDIS_VERSION:-6.2.5}
REDIS_AUTH=${REDIS_AUTH:-}
REDIS_PORT=${REDIS_PORT:-6379}
REDIS_EXPORTER_PORT=${REDIS_EXPORTER_PORT:-3888}
REDIS_HTTP_PROXY=${REDIS_HTTP_PROXY:-}
REDIS_HTTPS_PROXY=${REDIS_HTTPS_PROXY:-}
REDIS_NO_PROXY=${REDIS_NO_PROXY:-}

REDIS_HOME="$HOME/v$REDIS_VERSION"
REDIS_BIN=$REDIS_HOME/bin
REDIS_CONF=$REDIS_HOME/conf
REDIS_LOGS=$REDIS_HOME/log
REDIS_DATA=$REDIS_HOME/data
REDIS_RUN=$REDIS_HOME/run
REDIS_PLUGGINS=$REDIS_HOME/modules

SERVICE_NAME=redis
REDIS_SERVER=$REDIS_HOME/bin/redis-server
REDIS_CONF_FILE=$REDIS_HOME/conf/redis.conf


## Create new folder if not exist
[ ! -d $REDIS_HOME ] && { mkdir -p $REDIS_HOME; echo "create $REDIS_HOME"; }
[ ! -d $REDIS_BIN ] && { mkdir -p $REDIS_BIN; echo "create $REDIS_BIN"; }
[ ! -d $REDIS_CONF ] && { mkdir -p $REDIS_CONF; echo "create $REDIS_CONF"; }
[ ! -d $REDIS_LOGS ] && { mkdir -p $REDIS_LOGS; echo "create $REDIS_LOGS"; }
[ ! -d $REDIS_DATA ] && { mkdir -p $REDIS_DATA; echo "create $REDIS_DATA"; }
[ ! -d $REDIS_RUN ] && { mkdir -p $REDIS_RUN; echo "create $REDIS_RUN"; }
[ ! -d $REDIS_PLUGGINS ] && { mkdir -p $REDIS_PLUGGINS; echo "create $REDIS_PLUGGINS"; }


###################################
# Download & Build Redis Source
###################################
SETUP_PATH=$HOME/setups
REDIS_SRC_FILE="redis-$REDIS_VERSION.tar.gz"
REDIS_SRC_URL="https://download.redis.io/releases/$REDIS_SRC_FILE"
REDIS_SRC_PATH="$SETUP_PATH/redis-$REDIS_VERSION"
[ ! -d $SETUP_PATH ] && { mkdir -p $SETUP_PATH; echo "create $SETUP_PATH"; }

## check process running
pgrep -x redis-server >/dev/null && { echo "redis-server is Running, please stop service before re-install"; exit; }


is_overwrite=$(is_overwrite_file $REDIS_SERVER)
if [[ $is_overwrite == "Y" && $is_overwrite == "y" ]]; then
  echo "Redis Server's existed in $REDIS_SERVER"
  if [ ! -f $SETUP_PATH/$REDIS_SRC_FILE ]; then
    ## param: redis path,redis url, output path, command type
    download_and_extract_package_from_url $SETUP_PATH/$REDIS_SRC_FILE $REDIS_SRC_URL $SETUP_PATH "tar-extract"
  fi

  [ ! -d $REDIS_SRC_PATH ] && { echo "Redis source path not exist"; exit 1; }

  echo "Starting install Redis from source: $REDIS_SRC_PATH"

  cd $REDIS_SRC_PATH && make -j$(nproc)

  copy_file_from_to $REDIS_SRC_PATH/src/redis-cli $REDIS_BIN/redis-cli
  copy_file_from_to $REDIS_SRC_PATH/src/redis-check-aof $REDIS_BIN
  copy_file_from_to $REDIS_SRC_PATH/src/redis-sentinel $REDIS_BIN
  copy_file_from_to $REDIS_SRC_PATH/src/redis-server $REDIS_BIN
  copy_file_from_to $REDIS_SRC_PATH/src/redis-benchmark $REDIS_BIN
  copy_file_from_to $REDIS_SRC_PATH/redis.conf $REDIS_CONF
  copy_file_from_to $REDIS_SRC_PATH/sentinel.conf $REDIS_CONF

  ###################################
  # Sysconfig Redis
  ###################################
  is_overwrite=$(is_overwrite_file_with_sudo '/etc/sysconfig/$SERVICE_NAME')
  echo "Sysconfig: $is_overwrite"
  if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then

IFS='' read -r -d '' VAR <<"EOF"
REDISCLI_AUTH=VAR_REDIS_AUTH
\nEXPORTER_REDIS_ADDR=redis://localhost:VAR_REDIS_PORT
\nEXPORTER_REDIS_NAMESPACE=redis
\nEXPORTER_REDIS_LOG_FORMAT=txt
\nEXPORTER_LISTEN_ADDRESS=:VAR_REDIS_EXPORTER_PORT
\nHTTP_PROXY=VAR_REDIS_HTTP_PROXY
\nHTTPS_PROXY=VAR_REDIS_HTTPS_PROXY
\nNO_PROXY=VAR_REDIS_NO_PROXY
EOF

  VAR=${VAR//VAR_REDIS_AUTH/${REDIS_AUTH}}
  VAR=${VAR//VAR_REDIS_PORT/${REDIS_PORT}}
  VAR=${VAR//VAR_REDIS_EXPORTER_PORT/${REDIS_EXPORTER_PORT}}
  VAR=${VAR//VAR_ENVOY_DATA/${ENVOY_DATA}}
  VAR=${VAR//VAR_REDIS_HTTP_PROXY/${REDIS_HTTP_PROXY}}
  VAR=${VAR//VAR_REDIS_HTTPS_PROXY/${REDIS_HTTPS_PROXY}}
  VAR=${VAR//VAR_REDIS_NO_PROXY/${REDIS_NO_PROXY}}
  echo "> /etc/sysconfig/redis"
  echo -e $VAR | sudo tee /etc/sysconfig/$SERVICE_NAME > /dev/null
  #echo $(cat < /etc/sysconfig/redis)
fi

###################################
# SystemD Redis
###################################
is_overwrite=$(is_overwrite_file_with_sudo '/etc/systemd/system/$SERVICE_NAME.service')
echo "systemd: $is_overwrite"
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then

REDIS_SERVER=$REDIS_HOME/bin/redis-server
REDIS_CONF_FILE=$REDIS_HOME/conf/redis.conf


IFS='' read -r -d '' VAR <<"EOF"
[Unit]
\nDescription=Redis data structure server
\nAfter=rsyslog.service network.target remote-fs.target nss-lookup.target
\n
\n[Service]
\nEnvironmentFile=/etc/sysconfig/redis
\nExecStart=VAR_REDIS_SERVER VAR_REDIS_CONF_FILE
\nRestart=on-failure
\nLimitNOFILE=10032
\nNoNewPrivileges=yes
\nType=simple
\nUMask=0077
\nUser=redis
\nGroup=redis
\nWorkingDirectory=VAR_REDIS_HOME
\nExecStartPre=/bin/mkdir -p VAR_REDIS_RUN
\nExecStartPre=/bin/mkdir -p VAR_REDIS_DATA
\nExecStartPre=/bin/mkdir -p VAR_REDIS_LOGS
\n
\n[Install]
\nWantedBy=multi-user.target
\n
EOF

  VAR=${VAR//VAR_REDIS_SERVER/${REDIS_SERVER}}
  VAR=${VAR//VAR_REDIS_CONF_FILE/${REDIS_CONF_FILE}}
  VAR=${VAR//VAR_REDIS_HOME/${REDIS_HOME}}
  VAR=${VAR//VAR_REDIS_RUN/${REDIS_RUN}}
  VAR=${VAR//VAR_REDIS_DATA/${REDIS_DATA}}
  VAR=${VAR//VAR_REDIS_LOGS/${REDIS_LOGS}}
  echo "> /etc/systemd/system/$SERVICE_NAME.service"
  echo -e $VAR | sudo tee /etc/systemd/system/$SERVICE_NAME.service > /dev/null

  echo "> Enable $SERVICE_NAME.service"
  sudo systemctl enable $SERVICE_NAME.service
fi

###################################
# Sudoers Redis
###################################
is_overwrite=$(is_overwrite_file_with_sudo '/etc/sudoers.d/$SERVICE_NAME')
echo "Sudoers: $is_overwrite"
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
IFS='' read -r -d '' VAR <<"EOF"
%redis ALL=(root) /usr/sbin/reboot
\n%redis ALL=(root) NOPASSWD: /bin/journalctl -xe
\n%redis ALL=(root) NOPASSWD: /bin/systemctl stop VAR_SERVICE_NAME.service,/bin/systemctl start VAR_SERVICE_NAME.service,/bin/systemctl restart VAR_SERVICE_NAME.service,/bin/systemctl status VAR_SERVICE_NAME.service
\n%redis ALL=(root) NOPASSWD: /bin/systemctl stop VAR_SERVICE_NAME,/bin/systemctl start VAR_SERVICE_NAME,/bin/systemctl restart VAR_SERVICE_NAME,/bin/systemctl status VAR_SERVICE_NAME
EOF

  VAR=${VAR//VAR_SERVICE_NAME/${SERVICE_NAME}}
  echo "> /etc/sudoers.d/$SERVICE_NAME"
  echo -e $VAR | sudo tee /etc/sudoers.d/$SERVICE_NAME  > /dev/null
fi

fi




###################################
# Redis Module Officially
#   + RediSearch
#   + RedisJSON
#   + RedisTimeSerie
#   + RedisGraph
#   + RedisAI
#   + RedisGears
###################################
EVENT_TIME=$(date +'%Y_%m_%d_%H_%M_%S')
REDIS_MODULE_SEARCH=${REDIS_MODULE_SEARCH:-}
REDIS_MODULE_JSON=${REDIS_MODULE_JSON:-}
REDIS_MODULE_TIMESERIES=${REDIS_MODULE_TIMESERIES:-}
REDIS_MODULE_GRAPH=${REDIS_MODULE_GRAPH:-}
REDIS_MODULE_AI=${REDIS_MODULE_AI:-}
REDIS_MODULE_GEAR=${REDIS_MODULE_GEAR:-}

if [ ${#REDIS_MODULE_SEARCH} -gt 0 ]; then
  echo "Installing Module RedisSearch version $REDIS_MODULE_SEARCH"
  SETUP_PATH=$HOME/setups
  REDIS_MODULE_GIT_URL="https://github.com/RediSearch/RediSearch.git"
  REDIS_MODULE_GIT_VERSION="v$REDIS_MODULE_SEARCH"
  REDIS_MODULE_SRC="$SETUP_PATH/RediSearch-$REDIS_MODULE_GIT_VERSION"
  REDIS_MODULE_PATH=$REDIS_PLUGGINS/rs
  REDIS_MODULE_LIB=$REDIS_MODULE_PATH/redisearch-${REDIS_MODULE_GIT_VERSION}.so
  is_overwrite=$(is_overwrite_file $REDIS_MODULE_LIB)
  if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
    [ ! -d $SETUP_PATH ] && { mkdir -p $SETUP_PATH; echo "create $SETUP_PATH"; }
    ## Download source
    [ ! -d $REDIS_MODULE_SRC ] && { \
        mkdir -p $REDIS_MODULE_SRC; \
        [ $REDIS_MODULE_GIT_VERSION == "v$CONST_VERSION_LATEST" ] \
          && { git clone --recursive $REDIS_MODULE_GIT_URL $REDIS_MODULE_SRC; } \
          || { git clone --recursive $REDIS_MODULE_GIT_URL -b $REDIS_MODULE_GIT_VERSION $REDIS_MODULE_SRC; } \
      }
    ## buil source
    cd $REDIS_MODULE_SRC && make -j$(nproc)
    ##
    if [ -f $REDIS_MODULE_SRC/build/redisearch.so ]; then
      [ ! -d $REDIS_MODULE_PATH ] && { mkdir -p $REDIS_MODULE_PATH; echo "create new folder $REDIS_MODULE_PATH"; }
      cp $REDIS_MODULE_SRC/build/redisearch.so $$REDIS_MODULE_LIB
      [ -f $REDIS_PLUGGINS/redisearch.so ] && { rm -f $REDIS_PLUGGINS/redisearch.so; }
      ln -s $REDIS_MODULE_LIB $REDIS_PLUGGINS/redisearch.so
      echo "Installed $(ls -lt $REDIS_PLUGGINS/redisearch.so)";
    else
      echo "Redis Search module is not exist"
    fi
  fi
fi

if [ ${#REDIS_MODULE_JSON} -gt 0 ]; then
  echo "Installing Module RedisJSON version $REDIS_MODULE_JSON"
  SETUP_PATH=$HOME/setups
  REDIS_MODULE_GIT_URL="https://github.com/RedisJSON/RedisJSON.git"
  REDIS_MODULE_GIT_VERSION="v$REDIS_MODULE_JSON"
  REDIS_MODULE_SRC="$SETUP_PATH/RedisJSON-$REDIS_MODULE_GIT_VERSION"
  REDIS_MODULE_PATH=$REDIS_PLUGGINS/rjson
  REDIS_MODULE_LIB=$REDIS_MODULE_PATH/rejson-${REDIS_MODULE_GIT_VERSION}.so
  is_overwrite=$(is_overwrite_file $REDIS_MODULE_LIB)
  if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
    [ ! -d $SETUP_PATH ] && { mkdir -p $SETUP_PATH; echo "create $SETUP_PATH"; }
    ## Download source
    [ ! -d $REDIS_MODULE_SRC ] && { \
        mkdir -p $REDIS_MODULE_SRC; \
        [ $REDIS_MODULE_GIT_VERSION == "v$CONST_VERSION_LATEST" ] \
          && { git clone --recursive $REDIS_MODULE_GIT_URL $REDIS_MODULE_SRC; } \
          || { git clone --recursive $REDIS_MODULE_GIT_URL -b $REDIS_MODULE_GIT_VERSION $REDIS_MODULE_SRC; } \
      }
    ## buil source
    cd $REDIS_MODULE_SRC && make -j$(nproc)
    ##
    if [ -f $REDIS_MODULE_SRC/src/rejson.so ]; then
      [ ! -d $REDIS_MODULE_PATH ] && { mkdir -p $REDIS_MODULE_PATH; echo "create new folder $REDIS_MODULE_PATH"; }
      cp $REDIS_MODULE_SRC/src/rejson.so $REDIS_MODULE_LIB
      [ -f $REDIS_PLUGGINS/rejson.so ] && { rm -f $REDIS_PLUGGINS/rejson.so; }
      ln -s $REDIS_MODULE_LIB $REDIS_PLUGGINS/rejson.so
      echo "Installed $(ls -lt $REDIS_PLUGGINS/rejson.so)";
    fi
  fi
fi

if [ ${#REDIS_MODULE_TIMESERIES} -gt 0 ]; then
  echo "Installing Module RedisTimeSerie version $REDIS_MODULE_TIMESERIES"
  SETUP_PATH=$HOME/setups
  REDIS_MODULE_GIT_URL="https://github.com/RedisTimeSeries/RedisTimeSeries.git"
  REDIS_MODULE_GIT_VERSION="v$REDIS_MODULE_TIMESERIES"
  REDIS_MODULE_SRC="$SETUP_PATH/RedisTimeseries-$REDIS_MODULE_GIT_VERSION"
  REDIS_MODULE_PATH=$REDIS_PLUGGINS/rts
  REDIS_MODULE_LIB=$REDIS_MODULE_PATH/redistimeseries-${REDIS_MODULE_GIT_VERSION}.so
  is_overwrite=$(is_overwrite_file $REDIS_MODULE_LIB)
  if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
    [ ! -d $SETUP_PATH ] && { mkdir -p $SETUP_PATH; echo "create $SETUP_PATH"; }
    ## Download source
    [ ! -d $REDIS_MODULE_SRC ] && { \
        mkdir -p $REDIS_MODULE_SRC; \
        [ $REDIS_MODULE_GIT_VERSION == "v$CONST_VERSION_LATEST" ] \
          && { git clone --recursive $REDIS_MODULE_GIT_URL $REDIS_MODULE_SRC; } \
          || { git clone --recursive $REDIS_MODULE_GIT_URL -b $REDIS_MODULE_GIT_VERSION $REDIS_MODULE_SRC; } \
      }
    ## buil source
    cd $REDIS_MODULE_SRC && make -j$(nproc)
    ##
    if [ -f $REDIS_MODULE_SRC//bin/linux-x64-release/redistimeseries.so ]; then
      [ ! -d $REDIS_MODULE_PATH ] && { mkdir -p $REDIS_MODULE_PATH; echo "create new folder $REDIS_MODULE_PATH"; }
      cp $REDIS_MODULE_SRC/bin/linux-x64-release/redistimeseries.so $REDIS_MODULE_LIB
      [ -f $REDIS_PLUGGINS/redistimeseries.so ] && { rm -f $REDIS_PLUGGINS/redistimeseries.so; }
      ln -s $REDIS_MODULE_LIB $REDIS_PLUGGINS/redistimeseries.so
      echo "Installed $(ls -lt $REDIS_PLUGGINS/redistimeseries.so)";
    fi
  fi

fi

if [ ${#REDIS_MODULE_GRAPH} -gt 0 ]; then
  echo "Installing Module RedisGraph version $REDIS_MODULE_GRAPH"
    if [ ! -f /usr/local/bin/peg ]; then
    SETUP_PATH=$HOME/setups
    PEG_FILE=$SETUP_PATH/peg-0.1.18.tar.gz
    PEG_URL="https://www.piumarta.com/software/peg/peg-0.1.18.tar.gz"
    PEG_SOURCE="$SETUP_PATH/peg-0.1.18"
    install_source_from_url_with_sudo "tar-extract" $PEG_FILE $PEG_URL $PEG_SOURCE
    if [ ! -f /usr/local/bin/peg ]; then
      echo "peg is not installed, please install peg-0.1.18"
      return 1
    fi
  fi
  SETUP_PATH=$HOME/setups
  REDIS_MODULE_GIT_URL="https://github.com/RedisGraph/RedisGraph.git"
  REDIS_MODULE_GIT_VERSION="v$REDIS_MODULE_GRAPH"
  REDIS_MODULE_SRC="$SETUP_PATH/RedisGraph-$REDIS_MODULE_GRAPH"
  REDIS_MODULE_PATH=$REDIS_PLUGGINS/rgraph
  REDIS_MODULE_LIB=$REDIS_MODULE_PATH/redisgraph-${REDIS_MODULE_GIT_VERSION}.so
  is_overwrite=$(is_overwrite_file $REDIS_MODULE_LIB)
  if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
    [ ! -d $SETUP_PATH ] && { mkdir -p $SETUP_PATH; echo "create $SETUP_PATH"; }
    ## Download source
    [ ! -d $REDIS_MODULE_SRC ] && { \
        mkdir -p $REDIS_MODULE_SRC; \
        [ $REDIS_MODULE_GIT_VERSION == "v$CONST_VERSION_LATEST" ] \
          && { git clone --recursive $REDIS_MODULE_GIT_URL $REDIS_MODULE_SRC; } \
          || { git clone --recursive $REDIS_MODULE_GIT_URL -b $REDIS_MODULE_GIT_VERSION $REDIS_MODULE_SRC; } \
      }
    ## buil source
    cd $REDIS_MODULE_SRC && make

    if [ -f $REDIS_MODULE_SRC/src/redisgraph.so ]; then
      [ ! -d $REDIS_MODULE_PATH ] && { mkdir -p $REDIS_MODULE_PATH; echo "create new folder $REDIS_MODULE_PATH"; }
      cp $REDIS_MODULE_SRC/src/redisgraph.so $REDIS_MODULE_LIB
      [ -f $REDIS_PLUGGINS/redisgraph.so ] && { rm -f $REDIS_PLUGGINS/redisgraph.so; }
      ln -s $REDIS_MODULE_LIB $REDIS_PLUGGINS/redisgraph.so
      echo "Installed $(ls -lt $REDIS_PLUGGINS/redisgraph.so)";
    fi
  fi
fi

if [ ${#REDIS_MODULE_AI} -gt 0 ]; then
  echo "Installing Module RedisAI version $REDIS_MODULE_AI"
  SETUP_PATH=$HOME/setups
  REDIS_MODULE_GIT_URL="https://github.com/RedisAI/RedisAI.git"
  REDIS_MODULE_GIT_VERSION="v$REDIS_MODULE_AI"
  REDIS_MODULE_SRC="$SETUP_PATH/RedisAI-$REDIS_MODULE_AI"
  REDIS_MODULE_PATH=$REDIS_PLUGGINS/rai
  REDIS_MODULE_LIB=$REDIS_MODULE_PATH/install-cpu-$REDIS_MODULE_AI/redisai.so
  is_overwrite=$(is_overwrite_file $REDIS_MODULE_LIB)
  if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
    [ ! -d $SETUP_PATH ] && { mkdir -p $SETUP_PATH; echo "create $SETUP_PATH"; }
    ## Download source
    [ ! -d $REDIS_MODULE_SRC ] && { \
        mkdir -p $REDIS_MODULE_SRC; \
        [ $REDIS_MODULE_GIT_VERSION == "v$CONST_VERSION_LATEST" ] \
          && { git clone --recursive $REDIS_MODULE_GIT_URL $REDIS_MODULE_SRC; } \
          || { git clone --recursive $REDIS_MODULE_GIT_URL -b $REDIS_MODULE_GIT_VERSION $REDIS_MODULE_SRC; } \
      }
    ## buil source
    cd $REDIS_MODULE_SRC && $REDIS_MODULE_SRC/get_deps.sh cpu && ALL=1 make -C opt clean build

    if [ -f $REDIS_MODULE_SRC/bin/linux-x64-release/install-cpu/redisai.so ]; then
      [ ! -d $REDIS_MODULE_PATH ] && { mkdir -p $REDIS_MODULE_PATH; echo "create new folder $REDIS_MODULE_PATH"; }
      cp -R $REDIS_MODULE_SRC/bin/linux-x64-release/install-cpu $REDIS_MODULE_PATH/install-cpu-${REDIS_MODULE_AI}
      [ -f $REDIS_PLUGGINS/redisai.so ] && { rm -f $REDIS_PLUGGINS/redisai.so; }
      ln -s $REDIS_MODULE_LIB $REDIS_PLUGGINS/redisai.so
      echo "Installed $(ls -lt $REDIS_PLUGGINS/redisai.so)";
    fi
  fi

fi

if [ ${#REDIS_MODULE_GEAR} -gt 0 ]; then
  echo "Installing Module RedisGears version $REDIS_MODULE_GEAR"
fi



