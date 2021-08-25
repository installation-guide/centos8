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
if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
  echo "Redis Server's existed in $REDIS_SERVER"
  if [ ! -f $REDIS_SRC_PATH ]; then
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
  is_overwrite=$(is_overwrite_file_with_sudo /etc/sysconfig/$SERVICE_NAME)
  if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
    SYSCONFIG_PATH=$REDIS_SRC_PATH/etc/sysconfig
    [ ! -d $SYSCONFIG_PATH ] && { mkdir -p $SYSCONFIG_PATH; echo "create new $SYSCONFIG_PATH"; }
    
    REDIS_AUTH=$REDIS_AUTH \
      REDIS_PORT=$REDIS_PORT \
      REDIS_EXPORTER_PORT=$REDIS_EXPORTER_PORT \
      REDIS_HTTP_PROXY=$REDIS_HTTP_PROXY \
      REDIS_HTTPS_PROXY=$REDIS_HTTPS_PROXY \
      REDIS_NO_PROXY=$REDIS_NO_PROXY \
      envsubst< $SCRIPT_DIR/redis/redis.sysconfig >  $SYSCONFIG_PATH/$SERVICE_NAME
      
    echo "> /etc/sysconfig/$SERVICE_NAME"
    sudo cp $SYSCONFIG_PATH/$SERVICE_NAME /etc/sysconfig/$SERVICE_NAME
  fi

  ###################################
  # SystemD Redis
  ###################################
  is_overwrite=$(is_overwrite_file_with_sudo /etc/systemd/system/$SERVICE_NAME.service)
  if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
    ##
    SYSTEMD_PATH=$REDIS_SRC_PATH/etc/systemd/system
    [ ! -d $SYSTEMD_PATH ] && { mkdir -p $SYSTEMD_PATH; echo "create new $SYSTEMD_PATH"; }
    ###
    REDIS_SERVER=$REDIS_SERVER \
    REDIS_CONF_FILE=$REDIS_CONF_FILE \
    REDIS_HOME=$REDIS_HOME \
    REDIS_RUN=$REDIS_RUN \
    REDIS_DATA=$REDIS_DATA \
    REDIS_LOGS=$REDIS_LOGS \
      envsubst< $SCRIPT_DIR/redis/redis.service >  "$SYSTEMD_PATH/$SERVICE_NAME.service"

    echo "> /etc/systemd/system/$SERVICE_NAME.service"
    sudo cp $SYSTEMD_PATH/$SERVICE_NAME.service /etc/systemd/system/$SERVICE_NAME.service

    echo "> Enable $SERVICE_NAME.service"
    sudo systemctl enable $SERVICE_NAME.service
  fi

  ###################################
  # Sudoers Redis
  ###################################
  is_overwrite=$(is_overwrite_file_with_sudo /etc/sudoers.d/$SERVICE_NAME)
  if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
    SUDOERS_PATH=$REDIS_SRC_PATH/etc/sudoers.d
    [ ! -d $SUDOERS_PATH ] && { mkdir -p $SUDOERS_PATH; echo "create new $SUDOERS_PATH"; }
    
    SERVICE_NAME=$SERVICE_NAME \
      envsubst< $SCRIPT_DIR/redis/redis.sudoers >  $SUDOERS_PATH/$SERVICE_NAME
    echo "> /etc/sudoers.d/$SERVICE_NAME"
    sudo cp $SUDOERS_PATH/$SERVICE_NAME /etc/sudoers.d/$SERVICE_NAME
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
      cp $REDIS_MODULE_SRC/build/redisearch.so $REDIS_MODULE_LIB
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
  SETUP_PATH=$HOME/setups
  REDIS_MODULE_GIT_URL="https://github.com/RedisGears/RedisGears.git"
  REDIS_MODULE_GIT_VERSION="v$REDIS_MODULE_GEAR"
  REDIS_MODULE_SRC="$SETUP_PATH/RedisGears-$REDIS_MODULE_GEAR"
  REDIS_MODULE_PATH=$REDIS_PLUGGINS/rg
  REDIS_MODULE_LIB=$REDIS_MODULE_PATH/redisgears-$REDIS_MODULE_GEAR.so
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
    [ ! -d $REDIS_MODULE_SRC/tmp ] && { mkdir -p $REDIS_MODULE_SRC/tmp; }
    export CPYTHON_PREFIX=$REDIS_MODULE_PATH/python3_$REDIS_MODULE_GEAR
    sudo dnf --enablerepo=powertools install -y tix-devel
    cd $REDIS_MODULE_SRC && { \
      sudo $REDIS_MODULE_SRC/system-setup.py; \
      TMPDIR=$REDIS_MODULE_SRC/tmp make; }
    ##
    if [ -f $REDIS_MODULE_SRC/bin/linux-x64-release/redisgears.so ]; then
      [ ! -d $REDIS_MODULE_PATH ] && { mkdir -p $REDIS_MODULE_PATH; echo "create new folder $REDIS_MODULE_PATH"; }
      echo "install python3_$REDIS_MODULE_GEAR"
      [ -d $REDIS_MODULE_PATH/python3_$REDIS_MODULE_GEAR ] && { rm -rf $REDIS_MODULE_PATH/python3_$REDIS_MODULE_GEAR; echo "existed, just remove $REDIS_MODULE_PATH/python3_$REDIS_MODULE_GEAR"; }
      cp -R $REDIS_MODULE_SRC/bin/linux-x64-release/python3_$REDIS_MODULE_GEAR $REDIS_MODULE_PATH/python3_$REDIS_MODULE_GEAR

      python_interpreter='#!'${REDIS_MODULE_PATH}/python3_$REDIS_MODULE_GEAR/bin/python3.7
      export python_path="${REDIS_MODULE_PATH}/python3_$REDIS_MODULE_GEAR"  
      echo "*** ${python_interpreter}"
      echo "*** ${python_path}"
      sed -i "/^#!.*/c ${python_interpreter}" "$python_path/bin/2to3-3.7"
      sed -i "/^#!.*/c ${python_interpreter}" "$python_path/bin/easy_install-3.7"
      sed -i "/^#!.*/c ${python_interpreter}" "$python_path/bin/idle3.7"
      sed -i "/^#!.*/c ${python_interpreter}" "$python_path/bin/pip"
      sed -i "/^#!.*/c ${python_interpreter}" "$python_path/bin/pip3"
      sed -i "/^#!.*/c ${python_interpreter}" "$python_path/bin/pip3.7"
      sed -i "/^#!.*/c ${python_interpreter}" "$python_path/bin/pydoc3.7"
      sed -i "/^#!.*/c ${python_interpreter}" "$python_path/bin/pyvenv-3.7"
      sed -i "/^#!.*/c ${python_interpreter}" "$python_path/bin/virtualenv"
      sed -i "/^#!.*/c ${python_interpreter}" "$python_path/bin/wheel"

      sed -i "/^prefix=.*/c prefix=\"${python_path}\"" "$python_path/bin/python3.7m-config"
      sed -i "/^prefix=.*/c prefix=\"${python_path}\"" "$python_path/lib/pkgconfig/python-3.7.pc"

      cp $REDIS_MODULE_SRC/bin/linux-x64-release/redisgears.so $REDIS_MODULE_PATH/redisgears-${REDIS_MODULE_GEAR}.so
      [ -f $REDIS_PLUGGINS/redisgears.so ] && { rm -f $REDIS_PLUGGINS/redisgears.so; }
      ln -s $REDIS_MODULE_LIB $REDIS_PLUGGINS/redisgears.so
      echo "Installed $(ls -lt $REDIS_PLUGGINS/redisgears.so)";
    fi

  fi
fi


###################################
# Redis Configuration
###################################
requirepass=$(grep REDISCLI_AUTH $"/etc/sysconfig/$SERVICE_NAME" | awk -F= '{print $2}')
redismem=$(($(getconf _PHYS_PAGES) * $(getconf PAGE_SIZE) * 7 / (1024 * 1024 * 10)))

  ###################################
  # ACL FILE
  ###################################
  is_overwrite=$(is_overwrite_file $REDIS_CONF/$SERVICE_NAME.acl)
  if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
    REDIS_CONFIG_PATH=$REDIS_SRC_PATH/etc/rconf
    [ ! -d $REDIS_CONFIG_PATH ] && { mkdir -p $REDIS_CONFIG_PATH; echo "create new $REDIS_CONFIG_PATH"; }
    
    REDIS_AUTH_DEFAULT=$requirepass \
    REDIS_AUTH_ADMIN=${REDIS_AUTH_ADMIN:-$(cat /dev/urandom | tr -dc a-zA-Z0-9 | fold -w 32 | head -n 1)} \
    REDIS_AUTH_SERVICE=${REDIS_AUTH_ADMIN:-$(cat /dev/urandom | tr -dc a-zA-Z0-9 | fold -w 24 | head -n 1)} \
      envsubst< $SCRIPT_DIR/redis/redis.acl >  $REDIS_CONFIG_PATH/$SERVICE_NAME.acl
    echo "> $REDIS_CONF/$SERVICE_NAME.acl"
    cp $REDIS_CONFIG_PATH/$SERVICE_NAME.acl $REDIS_CONF/$SERVICE_NAME.acl
  fi

  ###################################
  # LOCAL CONFIG FILE
  ###################################
  REDIS_CONF_MODULE_REJSON=
  REDIS_CONF_MODULE_RSEARCH=
  REDIS_CONF_MODULE_RTIMESERIES=
  REDIS_CONF_MODULE_RGRAPH=
  REDIS_CONF_MODULE_RAI=
  REDIS_CONF_MODULE_RGEARS=
  [ -f $REDIS_PLUGGINS/redisearch.so ] && { REDIS_CONF_MODULE_RSEARCH="loadmodule $REDIS_PLUGGINS/redisearch.so"; }
  [ -f $REDIS_PLUGGINS/rejson.so ] && { REDIS_CONF_MODULE_REJSON="loadmodule $REDIS_PLUGGINS/rejson.so"; }
  [ -f $REDIS_PLUGGINS/redistimeseries.so ] && { REDIS_CONF_MODULE_RTIMESERIES="loadmodule $REDIS_PLUGGINS/redistimeseries.so"; }
  [ -f $REDIS_PLUGGINS/redisgraph.so ] && { REDIS_CONF_MODULE_RGRAPH="loadmodule $REDIS_PLUGGINS/redisgraph.so"; }
  [ -f $REDIS_PLUGGINS/redisai.so ] && { REDIS_CONF_MODULE_RAI="loadmodule $REDIS_PLUGGINS/redisai.so"; }
  [ -f $REDIS_PLUGGINS/redisgears.so ] && { REDIS_CONF_MODULE_RGEARS="loadmodule $REDIS_PLUGGINS/redisgears.so PythonInstallationDir $REDIS_PLUGGINS/rg DownloadDeps 0 CreateVenv 1 ExecutionThreads 32"; }
  
  is_overwrite=$(is_overwrite_file $REDIS_CONF/local_${SERVICE_NAME}.conf)
  if [[ $is_overwrite == "Y" || $is_overwrite == "y" ]]; then
    REDIS_CONFIG_PATH=$REDIS_SRC_PATH/etc/rconf
    [ ! -d $REDIS_CONFIG_PATH ] && { mkdir -p $REDIS_CONFIG_PATH; echo "create new $REDIS_CONFIG_PATH"; }
    
    SERVICE_NAME=$SERVICE_NAME \
    REDIS_CONF_MODULE_REJSON=$REDIS_CONF_MODULE_REJSON \
    REDIS_CONF_MODULE_RSEARCH=$REDIS_CONF_MODULE_RSEARCH \
    REDIS_CONF_MODULE_RTIMESERIES=$REDIS_CONF_MODULE_RTIMESERIES \
    REDIS_CONF_MODULE_RGRAPH=$REDIS_CONF_MODULE_RGRAPH \
    REDIS_CONF_MODULE_RAI=$REDIS_CONF_MODULE_RAI \
    REDIS_CONF_MODULE_RGEARS=$REDIS_CONF_MODULE_RGEARS \
    REDIS_PORT=$REDIS_PORT \
    REDIS_RUN=$REDIS_RUN \
    REDIS_CONF_PIDFILE="$REDIS_RUN/${SERVICE_NAME}_${REDIS_PORT}.pid" \
    REDIS_CONF_LOGFILE="$REDIS_LOGS/${SERVICE_NAME}_${REDIS_PORT}.log" \
    REDIS_DATA="$REDIS_DATA" \
    REDIS_CONF_DATAFILE="${SERVICE_NAME}_${REDIS_PORT}.dump" \
    REDIS_CONF_ACLFILE="$REDIS_CONF/$SERVICE_NAME.acl" \
    REDIS_AUTH=$requirepass \
    REDIS_CONF_MAX_MEMORY="${redismem}mb" \
      envsubst< $SCRIPT_DIR/redis/local.conf > $REDIS_CONFIG_PATH/local.conf
    echo "> $REDIS_CONF/local_${SERVICE_NAME}.conf"
    cp $REDIS_CONFIG_PATH/local.conf $REDIS_CONF/local_${SERVICE_NAME}.conf
  fi


echo
echo "Please update information bellow in Redis Configuration"
echo "================== vi $REDIS_CONF_FILE =================="
echo "include $REDIS_CONF/local_${SERVICE_NAME}.conf"
echo "========================================================="
echo 
echo
