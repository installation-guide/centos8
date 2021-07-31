#!/usr/bin/bash

# Define Constant
CONST_AS_ROOT=0
CONST_AS_NON_ROOT=1


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
    echo "${FUNCNAME}($@) - args $#: invalid input param, must be 2 param"
    echo "${FUNCNAME} <package_name> <package_path> <package_url> <temp> <output> <command_type>"
    return 1
  fi

  package_name=$1
  package_path=$2
  package_url=$3
  temp=$4
  output=$5
  command_type=$6
  echo "install_package_from_url()"
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
