#!/usr/bin/bash

# Define Constant
CONST_AS_ROOT=0
CONST_AS_NON_ROOT=1

CONST_VERSION_LATEST="latest"

# Define a variable map
GROUP_TYPE_SYSTEM="system"
GROUP_TYPE_NON_SYSTEM="non-system"

declare -A DEFAULT_GROUPS=(['operations']='system' ['ssh-users']='non-system')

############################################################
# user_check_sudo: kiem tra co quyen sudo khong?
# return
#  + 0: as root (sudo)
#  + 1: as non root (not sudo)
#
############################################################
function user_check_sudo() {
  IS_ROOT=$CONST_AS_NON_ROOT
  sudo date 1>&2 > /dev/null
  if [ $? -eq 0 ]; then
    IS_ROOT=$CONST_AS_ROOT
  #else
  #  IS_ROOT=$CONST_AS_ROOT
    #read -s -p "Enter Password for sudo: " sudoPW
    #echo $sudoPW | sudo -S date 1>&2 > /dev/null
    #if [ $? -eq 0 ]; then
    #  IS_ROOT=$CONST_AS_ROOT
    #else
    # echo "Incorrect password"
    #fi
  fi
  return $IS_ROOT
}

function init_os_groups() {
  user_check_sudo
  if [ $? -ne 0 ]; then
    echo "please login user with sudo permission"
    return 1
  fi
  for group in ${!DEFAULT_GROUPS[@]}; do
    group_type=${DEFAULT_GROUPS[$group]}
    case $group_type in
      $GROUP_TYPE_SYSTEM)
        grep -qw ^$group /etc/group || { sudo groupadd --system $group; echo "Just created system group $group"; }
        ;;
      $GROUP_TYPE_NON_SYSTEM)
        grep -qw ^$group /etc/group || { sudo groupadd $group; echo "Just created group $group"; }
        ;;
      *)
      echo "not supported: $group, $group_type"
        ;;
      esac
  done
}

function init_os_users() {
  if [ $# -ne 2 ]; then
    echo "${FUNCNAME}($@) - args $#: invalid input param, must be 2 param"
    echo "${FUNCNAME} <line start> <file name>"
    return 1
  fi
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
    if [ ${#fields[*]} -ge 4 ]; then
      username=${fields[0]}
      belong_groups=${fields[1]}
      home_dir=${fields[2]}
      password=${fields[3]}
      #echo "[$I] $line"
      #echo "[$I] ${fields[0]} - ${fields[1]} - ${fields[2]} - ${fields[3]}"
      grep -qw ^$username /etc/passwd 
      if [ $? -ne 0 ]; then
        sudo adduser --group $belong_groups  --home-dir $home_dir $username && sudo echo $password|sudo passwd $username --stdin; echo "created user: $username"; 
        #echo echo "[$I] create --group $belong_groups  --home-dir $home_dir $username"
      else 
        echo "$username existed"
      fi
    fi
  done < "$filename"
}

function users_update_groups() {
  if [ $# -ne 2 ]; then
    echo "${FUNCNAME}($@) - args $#: invalid input param, must be 2 param"
    echo "${FUNCNAME} <line start> <file name>"
    return 1
  fi
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
    if [ ${#fields[*]} -ge 4 ]; then
      username=${fields[0]}
      belong_groups=${fields[1]}
      home_dir=${fields[2]}
      password=${fields[3]}
      #echo "[$I] $line"
      #echo "[$I] ${fields[0]} - ${fields[1]} - ${fields[2]} - ${fields[3]}"
      grep -qw ^$username /etc/passwd 
      if [ $? -eq 0 ]; then
        sudo usermod -G $belong_groups $username
        #echo echo "[$I] create --group $belong_groups  --home-dir $home_dir $username"
      else 
        echo "$username not existed"
      fi
    fi
  done < "$filename"
}


function users_reset_password() {
  if [ $# -ne 2 ]; then
    echo "${FUNCNAME}($@) - args $#: invalid input param, must be 2 param"
    echo "${FUNCNAME} <line start> <file name>"
    return 1
  fi

  user_check_sudo
  if [ $? -ne 0 ]; then
    echo "please login user with sudo permission"
    return 1
  fi
  LINE_START=$1
  FILENAME=$2
  I=0
  while IFS= read -r line; do
    if [ $((I++)) -lt $LINE_START ]; then
      continue
    fi
    fields=($(echo $line | tr ":" "\n"))
    if [ ${#fields[*]} -ge 4 ]; then
      USER=${fields[0]}
      GROUPS=${fields[1]}
      HOMEDIR=${fields[2]}
      PASSWORD=${fields[3]}
      grep -qw ^$USER /etc/passwd
      if [ $? -eq 0 ]; then
        sudo echo $PASSWORD|sudo passwd $USER --stdin
      else
        echo "$USER not existed"
      fi
    fi
  done < "$FILENAME"
}

install_package_from_url() {
  if [ $# -lt 6 ]; then
    echo "$0: Invalid input parameters, must be 6 params"
    return $#
  fi
  
  if [ $# -ne 6 ]; then
    echo "${FUNCNAME}($@) - args $#: invalid input param"
    echo "${FUNCNAME} <package_name> <package_path> <package_url> <temp> <output> <command_type>"
    return 1
  fi

  package_name=$1
  package_path=$2
  package_url=$3
  temp=$4
  output=$5
  command_type=$6
  echo "${FUNCNAME}($@)"
  echo "Package name = $package_name"
  echo "Package path = $package_path"
  echo "Package url = $package_url"
  echo "Temp = $temp"
  echo "Output = $output"
  echo "Comand Type = $command_type"
  echo ""
  if [[ ! -f $package_path && $package_url != "null" ]]; then
    echo "Not existed $package_path, download Package"
    curl -L $package_url --output $package_path
  fi
  if [ -f $package_path ]; then
    if [ -d $output ]; then
      echo "package $package_name installed at $output "
    else
      echo "Installing $package_name"
      user_check_sudo
      if [ $? -eq 0 ]; then
        OUTPUT_BASEDIR=$(dirname $output);
        [ ! -d $OUTPUT_BASEDIR ] && { sudo mkdir -p $OUTPUT_BASEDIR; echo "just created $OUTPUT_BASEDIR";}
        case $command_type in
          tar-extract)
            sudo tar -xvf $package_path -C /tmp && sudo mv $temp $output
            ;;
          miniconda3)
            sudo bash $package_path -b -u -p $output
            ;;
          *)
            echo "Sorry, I don't understand command_type $command_type"
            ;;
          esac
      fi
    fi
  else
    echo "$package_path is not existed"
  fi
}

download_and_extract_package_from_url() {
  if [ $# -ne 4 ]; then
    echo "${FUNCNAME}($@) - args $#: invalid input param"
    echo "${FUNCNAME} <package_path> <package_url> <output> <command_type>"
    return 1
  fi
  echo "${FUNCNAME}($@)"
  package_path=$1
  package_url=$2
  output=$3
  command_type=$4
  if [[ ! -f $package_path && $package_url != "null" ]]; then
    echo "Not existed $package_path, download Package"
    curl -L $package_url --output $package_path
  fi
  [ ! -d $output ] && { mkdir -p $output; }
  if [ -f $package_path ]; then
    case $command_type in
      tar-extract)
        tar -xvf $package_path -C $output
        ;;
      *)
        echo "Sorry, I don't understand command_type $command_type"
        ;;
      esac
  fi
}

install_source_from_url_with_sudo() {
  if [ $# -lt 4 ]; then
    echo "${FUNCNAME}($@) - args $#: invalid input param"
    echo "${FUNCNAME} <package_path> <package_url> <package prefix>"
    return 1
  fi
  echo "${FUNCNAME}($@)"
  command_type=$1
  package_path=$2
  package_url=$3
  package_source=$4
  package_prefix=$5
  
  if [[ ! -f $package_path && $package_url != "null" ]]; then
    echo "Not existed $package_path, download Package"
    curl -L $package_url --output $package_path
  fi
  if [ -f $package_path ]; then
    TEMP_BASEDIR=$(dirname $package_source);
    [ ! -d $TEMP_BASEDIR ] && { mkdir -p $TEMP_BASEDIR; echo "just created $TEMP_BASEDIR";}
    case $command_type in
      tar-extract)
        tar -xvf $package_path -C $TEMP_BASEDIR
        ;;
      *)
        echo "Sorry, I don't understand command_type $command_type"
        ;;
      esac
  fi
  
  if [ -d $package_source ]; then
    echo "Installing $package_name"
    user_check_sudo
    if [ $? -eq 0 ]; then
      cd $package_source && make -j$(nproc) &&  sudo make install 
    fi
  fi
}

YUM_CMD=$(which yum) &> /dev/null
DNF_CMD=$(which dnf) &> /dev/null
APT_GET_CMD=$(command -v apt-get &> /dev/null)

install_package_from_repo() {
  if [ $# -eq 0 ]; then
    echo "${FUNCNAME}($@) - args $#: invalid input param"
    echo "${FUNCNAME} <package 1> <package 2> .."
    return 1
  fi
  echo "${FUNCNAME}($@)"
  list_packages=$@
  for package_name in $list_packages 
  do
    echo "Package name : $package_name";
    if [[ ! -z $DNF_CMD ]]; then
        sudo dnf install -y $package_name
     elif [[ ! -z $YUM_CMD ]]; then
        sudo yum install -y $package_name
     elif [ -x $APT_GET_CMD ]; then
        sudo apt-get $package_name
     else
        echo "error can't install package $PACKAGE"
        return 1;
     fi
  done
  return 0
}

copy_file_from_to() {
  if [ $# -ne 2 ]; then
    echo "${FUNCNAME}($@) - args $#: invalid input param"
    echo "${FUNCNAME} <source file> <destination path>"
    return 1
  fi
  SOURCE_FILE=$1
  TARGET_PATH=$2
  if [ -f $SOURCE_FILE ]; then
    echo "copy $SOURCE_FILE to $TARGET_PATH"
    cp $SOURCE_FILE $TARGET_PATH
    return 0
  else 
    echo "Source file ($SOURCE_FILE) is not exist"
    return 1
  fi
}

##########
## is_overwrite_file()
## return 
##   Y - yes overwrite, N - no overwrite
##   E - error
is_overwrite_file() {
  local IS_OVERWRITE='E'
  if [ $# -ne 1 ]; then
    echo "${FUNCNAME}($@) - args $#: invalid input param"
    echo "${FUNCNAME} <source file>"
    echo $IS_OVERWRITE
    return 1
  fi
  source_path=$1
  if [ -f $source_path -o -d $source_path ]; then
    read -p "do you overwrite '$source_path' [Y/N]? " overwrite
    if [[ $overwrite == "Y" || $overwrite == "y" ]]; then
      IS_OVERWRITE='Y'
    else
      IS_OVERWRITE='N'
    fi
  else 
    IS_OVERWRITE='Y'
  fi
  echo $IS_OVERWRITE
  return 0
}

is_overwrite_file_with_sudo() {
  local IS_OVERWRITE='E'
  if [ $# -ne 1 ]; then
    echo "${FUNCNAME}($@) - args $#: invalid input param"
    echo "${FUNCNAME} <source file>"
    echo $IS_OVERWRITE
    return 1
  fi
  source_file=$1
  sudo test -f $source_file
  if [ $? -eq 0 ]; then
    read -p "do you overwrite '$source_file' [Y/N]? " overwrite
    if [[ $overwrite == "Y" || $overwrite == "y" ]]; then
      IS_OVERWRITE='Y'
    else
      IS_OVERWRITE='N'
    fi
  else 
    IS_OVERWRITE='Y'
  fi
  echo $IS_OVERWRITE
  return 0
}

##########
## 
##########
fw_reload_service() {
  sudo firewall-cmd --reload
}

fw_permanent_add_tcp_port() {
  if [ $# -eq 0 ]; then
    echo "${FUNCNAME}($@) - args $#: invalid input param"
    return 1
  fi
  list_ports=$@
  for port in $list_ports
  do
    sudo firewall-cmd --zone=public --add-port=$port/tcp --permanent
  done
  return 0
}

fw_permanent_remove_tcp_port() {
  if [ $# -eq 0 ]; then
    echo "${FUNCNAME}($@) - args $#: invalid input param"
    return 1
  fi
  list_ports=$@
  for port in $list_ports 
  do
    sudo firewall-cmd --zone=public --remove-port=$port/tcp --permanent
  done

  return 0
}