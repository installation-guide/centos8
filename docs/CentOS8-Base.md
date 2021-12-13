# CentOS 8 - Cài đặt cơ bản

Tài liệu này hướng dẫn việc cài đặt các thư viện, công cụ, tiện ích và cũng như môi trường cho việc biên dịch source code khi triển khai hệ thống.

## 1. Các bước chuẩn bị
### 1.1 Cài đặt Proxy
Đối với một số máy **không thể kết nối trực tiếp ra ngoài Internet** mà cần kết nối thông qua Proxy của Tổ chức thì chúng ta sẽ cấu hình như bên dưới
Ví dụ, proxy server **10.91.0.70:8080**
#### 1.1.1  Cài đặt Global Proxy
```bash
sudo tee -a /etc/profile.d/http_proxy.sh > /dev/null <<'EOF'  
export http_proxy=http://10.91.0.70:8080
export https_proxy=http://10.91.0.70:8080
EOF
```
```bash
```
#### 1.1.2 Cài đặt User Proxy
Có thể thiết lập qua .bash_profile, hoặc .bashrc
```bash
sudo tee -a $HOME/.bash_profile > /dev/null <<'EOF'  
export http_proxy=http://10.91.0.70:8080
export https_proxy=http://10.91.0.70:8080
EOF
```

Hoặc:
```bash
sudo tee -a $HOME/.bashrc> /dev/null <<'EOF'  
export http_proxy=http://10.91.0.70:8080
export https_proxy=http://10.91.0.70:8080
EOF
```

### 1.2 Cài đặt Extra Repository
```bash
sudo dnf --enablerepo=extras install -y epel-release
```
### 1.3  SELinux Disable/Enable
Cho phép hoạt động tính năng SELinux
```bash
vi /etc/sysconfig/selinux
SELinux=enforcing
```
Khóa/Loại bỏ phép hoạt động tính năng SELinux
```bash
vi /etc/sysconfig/selinux
SELinux=disabled
```
Trên môi trường CentOS 8 SELinux không cho phép Systemd truy cập tới Folder của User, do vậy để các service có thể hoạt động trên Systemd cần disable SELinux
### 1.4 Firewall Disable/Enable
Tùy theo version của OS mà dịch vụ tường lửa sử dụng là: iptables, hoặc firewalld

Kiểm tra trạng thái hoạt động của Firewall
```bash
sudo systemctl status firewalld
```

Cho phép firewall hoạt động
```bash
sudo systemctl start firewalld
```
Khóa phép firewall hoạt động
```bash
sudo systemctl stop firewalld
```

### 1.5 Thiết lập function sử dụng chung
```bash
export SETUP_PATH=$HOME/setups
mkdir -p $SETUP_PATH && cd $SETUP_PATH

tee $SETUP_PATH/centos8-common.sh > /dev/null <<'EOF'
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
EOF
chmod +x $SETUP_PATH/1.centos8-common.sh
```

```bash
tee $SETUP_PATH/centos8-install-url.sh > /dev/null <<'EOF'
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
PACKAGE_NAME=$1
PACKAGE_PATH=$2
PACKAGE_URL=$3
TEMP=$4
OUTPUT=$5
COMMAND_TYPE=$6
####
install_package_from_url $PACKAGE_NAME $PACKAGE_PATH $PACKAGE_URL $TEMP $OUTPUT $COMMAND_TYPE
EOF

chmod +x $SETUP_PATH/centos8-install-url.sh
```

```bash
tee $SETUP_PATH/centos8-install-users.sh > /dev/null <<'EOF'
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
EOF

chmod +x $SETUP_PATH/centos8-install-url.sh
```

## 2. Cài đặt thư viện cơ bản
```bash
export SETUP_PATH=$HOME/setups
mkdir -p $SETUP_PATH && cd $SETUP_PATH
tee $SETUP_PATH/centos8-basic.sh > /dev/null <<'EOF'  
sudo dnf --enablerepo=extras install -y epel-release
sudo dnf install -y kernel-headers kernel-devel systemd-devel
sudo dnf install -y libmpc mpfr gmp mpfr-devel gmp-devel expat-devel gdbm-devel ncurses-devel tk-devel xz-devel
sudo dnf install -y readline readline-devel openssl-devel libnl3-devel net-snmp-devel ipset-libs ipvsadm pcre-devel logrotate sqlite-devel
sudo dnf install -y zlib zlib-devel zip unzip bzip2-devel wget telnet sysstat psmisc tcpdump lsof socat tar
sudo dnf install -y git htop lm_sensors
sudo dnf install -y python2 python3
EOF
chmod +x $SETUP_PATH/centos8-basic.sh && $SETUP_PATH/centos8-basic.sh
```
## 3. Cài đặt các trình biên dịch, sdk
### 3.1 Cài đặt trình biên dịch gcc, g++
Trên môi trường CentOS Version 8, trình biên dịch C/C++ được cài đặt theo câu lệnh bên dưới:
``` bash
dnf install -y gcc gcc-c++
```
Trong một số bộ source, sử dụng cmake để biên dịch. Thực hiện câu lênh dưới để cài đặt:
``` bash
dnf install -y cmake
```

### 3.2 Cài đặt môi trường Java (JDK)
Tùy theo yêu cầu mà chúng ta sẽ cài đặt phiên bản JDK cho phù hợp.
* [Open JDK](https://www.journaldev.com/39894/install-java-14-on-linux-ubuntu-centos) 
* [Oracle JDK](https://www.oracle.com/java/technologies/javase-jdk16-downloads.html)

> Để cài đặt môi trường, cần tạo các script tại bước **"1.5 Thiết lập function sử dụng chung"**

#### 3.2.1 Cài đặt Open JDK
```bash
export SETUP_PATH=$HOME/setups; \
PACKAGE_VERSION="14.0.1"; \
PACKAGE_NAME="openjdk-${PACKAGE_VERSION}_linux-x64_bin.tar.gz"; \
PACKAGE_PATH=$SETUP_PATH/$PACKAGE_NAME; \
PACKAGE_URL="https://download.java.net/java/GA/jdk${PACKAGE_VERSION}/664493ef4a6946b186ff29eb326336a2/7/GPL/openjdk-${PACKAGE_VERSION}_linux-x64_bin.tar.gz"; \
TEMP="/tmp/jdk-${PACKAGE_VERSION}"; \
OUTPUT="/opt/open-jdk-${PACKAGE_VERSION}"; \
COMMAND_TYPE="tar-extract"; \
$SETUP_PATH/centos8-install-url.sh $PACKAGE_NAME $PACKAGE_PATH $PACKAGE_URL $TEMP $OUTPUT $COMMAND_TYPE

```
#### 3.2.2 Cài đặt Oracle JDK
Tải bộ cài đặt [Oracle JDK](https://www.oracle.com/java/technologies/javase-jdk16-downloads.html)
```bash
export SETUP_PATH=$HOME/setups; \
PACKAGE_VERSION="16.0.2"; \
PACKAGE_NAME="jdk-${PACKAGE_VERSION}_linux-x64_bin.tar.gz"; \
PACKAGE_PATH=$SETUP_PATH/$PACKAGE_NAME; \
PACKAGE_URL="null"; \
TEMP="/tmp/jdk-${PACKAGE_VERSION}"; \
OUTPUT="/opt/oracle-jdk-${PACKAGE_VERSION}"; \
COMMAND_TYPE="tar-extract"; \
$SETUP_PATH/centos8-install-url.sh $PACKAGE_NAME $PACKAGE_PATH $PACKAGE_URL $TEMP $OUTPUT $COMMAND_TYPE
```
#### 3.2.3 Cài đặt Vert.X
Lựa chọn phiên bản Vert.X phù để cài đặt.
* Vert.X version 3.9.2
* Vert.X version 4.1.2

Cài đặt Vert.X version 4.1.2
```bash
export SETUP_PATH=$HOME/setups; \
PACKAGE_VERSION="4.1.2"; \
PACKAGE_NAME="vertx-stack-manager-${PACKAGE_VERSION}-full.tar.gz"; \
PACKAGE_PATH=$SETUP_PATH/$PACKAGE_NAME; \
PACKAGE_URL="https://repo1.maven.org/maven2/io/vertx/vertx-stack-manager/${PACKAGE_VERSION}/vertx-stack-manager-${PACKAGE_VERSION}-full.tar.gz"; \
TEMP="/tmp/vertx"; \
OUTPUT="/opt/vertx-${PACKAGE_VERSION}"; \
COMMAND_TYPE="tar-extract"; \
$SETUP_PATH/centos8-install-url.sh $PACKAGE_NAME $PACKAGE_PATH $PACKAGE_URL $TEMP $OUTPUT $COMMAND_TYPE
```

Cài đặt Vert.X version 3.9.8
```bash
export SETUP_PATH=$HOME/setups; \
PACKAGE_VERSION="3.9.8"; \
PACKAGE_NAME="vertx-stack-manager-${PACKAGE_VERSION}-full.tar.gz"; \
PACKAGE_PATH=$SETUP_PATH/$PACKAGE_NAME; \
PACKAGE_URL="https://repo1.maven.org/maven2/io/vertx/vertx-stack-manager/${PACKAGE_VERSION}/vertx-stack-manager-${PACKAGE_VERSION}-full.tar.gz"; \
TEMP="/tmp/vertx"; \
OUTPUT="/opt/vertx-${PACKAGE_VERSION}"; \
COMMAND_TYPE="tar-extract"; \
$SETUP_PATH/centos8-install-url.sh $PACKAGE_NAME $PACKAGE_PATH $PACKAGE_URL $TEMP $OUTPUT $COMMAND_TYPE
```
#### 3.2.4 Cài đặt các môi trường mặt định cho Java
Để thiết lập mội trường Java mặc định cho toàn bộ user, chúng ta thực hiện theo các bước bên dưới:
```bash
sudo tee /etc/profile.d/jdk.sh > /dev/null <<'EOF'  
  export JAVA_HOME=/opt/open-jdk-14.0.1
  export CLASSPATH=${JAVA_HOME}/lib
  export PATH=$PATH:${JAVA_HOME}/bin
EOF
```

```bash
sudo tee /etc/profile.d/vertx.sh > /dev/null <<'EOF'  
  export VERTX_HOME=/opt/vertx-3.9.8
  export CLASSPATH=$CLASSPATH:${VERTX_HOME}/lib
  export PATH=$PATH:${VERTX_HOME}/bin
EOF
```
Kiểm tra môi trường đã thiết lập
```bash
## đăng nhập bằng session mới, và thực hiện lệnh bên dưới
java --version
```


### 3.3 Cài đặt môi trường Golang
Tùy theo yêu cầu mà chúng ta sẽ cài đặt phiên bản Golang cho phù hợp.
* [Tải golang tại đây](https://golang.org/dl/)

> Để cài đặt môi trường, cần tạo các script tại bước **"1.5 Thiết lập function sử dụng chung"**

#### 3.3.1 Cài đặt golang version 1.16.6
```bash
export SETUP_PATH=$HOME/setups; \
PACKAGE_VERSION="1.16.6"; \
PACKAGE_NAME="go${PACKAGE_VERSION}.linux-amd64.tar.gz"; \
PACKAGE_PATH=$SETUP_PATH/$PACKAGE_NAME; \
PACKAGE_URL="https://golang.org/dl/$PACKAGE_NAME"; \
TEMP="/tmp/go"; \
OUTPUT="/opt/go/sdk-${PACKAGE_VERSION}"; \
COMMAND_TYPE="tar-extract"; \
$SETUP_PATH/centos8-install-url.sh $PACKAGE_NAME $PACKAGE_PATH $PACKAGE_URL $TEMP $OUTPUT $COMMAND_TYPE
```
#### 3.3.2 Cài đặt các môi trường mặt định cho Golang
Để thiết lập mội trường Golang mặc định cho toàn bộ user, chúng ta thực hiện theo các bước bên dưới:
```bash
sudo tee /etc/profile.d/golang.sh > /dev/null <<'EOF'  
  export GOROOT=/opt/go/sdk-1.16.6
  export PATH=$PATH:${GOROOT}/bin
EOF
```
Kiểm tra môi trường đã thiết lập 
```bash
## đăng nhập bằng session mới, và thực hiện lệnh bên dưới
go version
```

### 3.4 Cài đặt môi trường NodeJS
Tùy theo yêu cầu mà chúng ta sẽ cài đặt phiên bản NodeJS cho phù hợp.
* [Tải nodejs tại đây](https://nodejs.org/dist)

> Để cài đặt môi trường, cần tạo các script tại bước **"1.5 Thiết lập function sử dụng chung"**

#### 3.4.1 Cài đặt NodeJS version 16.5.0
```bash
export SETUP_PATH=$HOME/setups; \
PACKAGE_VERSION="v16.5.0"; \
PACKAGE_NAME="node-${PACKAGE_VERSION}-linux-x64.tar.gz"; \
PACKAGE_PATH=$SETUP_PATH/$PACKAGE_NAME; \
PACKAGE_URL="https://nodejs.org/dist/${PACKAGE_VERSION}/$PACKAGE_NAME"; \
TEMP="/tmp/node-${PACKAGE_VERSION}-linux-x64"; \
OUTPUT="/opt/node/nodejs-${PACKAGE_VERSION}"; \
COMMAND_TYPE="tar-extract"; \
$SETUP_PATH/centos8-install-url.sh $PACKAGE_NAME $PACKAGE_PATH $PACKAGE_URL $TEMP $OUTPUT $COMMAND_TYPE
```
#### 3.4.2 Cài đặt các môi trường mặt định cho NodeJS
Để thiết lập mội trường NodeJS mặc định cho toàn bộ user, chúng ta thực hiện theo các bước bên dưới:
```bash
sudo tee /etc/profile.d/nodejs.sh > /dev/null <<'EOF'
  export NODEJS_VERSION="v16.5.0";
  export NODEJS_HOME=/opt/node/nodejs-$NODEJS_VERSION
  export PATH=$PATH:${NODEJS_HOME}/bin
EOF
```
Kiểm tra môi trường đã thiết lập 
```bash
## đăng nhập bằng session mới, và thực hiện lệnh bên dưới
node --version
```

### 3.5 Cài đặt môi trường Python (Miniconda3)
Tùy theo yêu cầu mà chúng ta sẽ cài đặt phiên bản ### Miniconda3 cho phù hợp.
* [Tải miniconda3 tại đây](https://docs.conda.io/en/latest/miniconda.html)

> Để cài đặt môi trường, cần tạo các script tại bước **"1.5 Thiết lập function sử dụng chung"**

#### 3.5.1 Cài đặt Miniconda3 - Version 4.10.3 for Python 3.9 
```bash
export SETUP_PATH=$HOME/setups; \
PACKAGE_VERSION="py39_4.10.3"; \
PACKAGE_NAME="Miniconda3-${PACKAGE_VERSION}-Linux-x86_64.sh"; \
PACKAGE_PATH=$SETUP_PATH/$PACKAGE_NAME; \
PACKAGE_URL="https://repo.anaconda.com/miniconda/$PACKAGE_NAME"; \
TEMP="null"; \
OUTPUT="/opt/Miniconda3/conda-${PACKAGE_VERSION}"; \
COMMAND_TYPE="miniconda3"; \
$SETUP_PATH/centos8-install-url.sh $PACKAGE_NAME $PACKAGE_PATH $PACKAGE_URL $TEMP $OUTPUT $COMMAND_TYPE
```
#### 3.5.2 Cài đặt các môi trường mặt định cho Miniconda3
Để thiết lập mội trường NodeJS mặc định cho toàn bộ user, chúng ta thực hiện theo các bước bên dưới:
```bash
sudo tee /etc/profile.d/minconda3.sh > /dev/null <<'EOF'
  export MINCONDA3_VERSION="py39_4.10.3";
  export MINCONDA3_HOME=/opt/Miniconda3/conda-${MINCONDA3_VERSION}
  export PATH=$PATH:${MINCONDA3_HOME}/bin
EOF
```
Kiểm tra môi trường đã thiết lập 
```bash
## đăng nhập bằng session mới, và thực hiện lệnh bên dưới
conda --version
```
Khởi tạo môi trường conda cho mỗi user, đăng nhập session mới với user cần thiết lập, và thực hiện cậu lệnh bên dưới: 
```bash
conda init
```
Để loại bỏ thiết lập mặc định môi trường conda mỗi khi SSH cho mỗi user, bằng cách:
* Đăng nhập session mới với user cần thiết lập
* Rem/Delete đoạn script bên dưới trong file $HOME/.bashrc
* Thoát ra và đăng nhập lại.
```bash
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/opt/Miniconda3/conda-py39_4.10.3/bin/conda' 'shell.bash' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/opt/Miniconda3/conda-py39_4.10.3/etc/profile.d/conda.sh" ]; then
        . "/opt/Miniconda3/conda-py39_4.10.3/etc/profile.d/conda.sh"
    else
        export PATH="/opt/Miniconda3/conda-py39_4.10.3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<
```

Để active môi trường conda, thực hiện lệnh
```bash
conda activate
```
Để deactive môi trường conda, thực hiện lệnh
```bash
conda deactivate
```

## 4. Thiết lập User
Phần này mô tả các bước để thiết lập, cập nhật thông tin user. Nhưng đây là Template,  nên chỉ mô phỏng các bước thực hiện, các thông tin cụ thể về từng Máy chủ thì xem ở tài liệu Hướng dẫn cài đặt cho máy chủ đó.

> Để cài đặt môi trường, cần tạo các script tại bước **"1.5 Thiết lập function sử dụng chung"**

* Bước 1:  Tạo User Info File
File chưa thông tin về User cần khởi tạo

> Nội dung file này sẽ thay đổi tùy theo cấu trúc của máy chủ muốn Cài đặt.

```bash
SETUP_PATH=$HOME/setups;\
tee $SETUP_PATH/sample-user-creation.txt > /dev/null <<'EOF'
## Pattern
##  <username>:<list groups>:<home dir>:password
## example
## 	envoy:operations,wheel:/app/envoy:mBs@2021
envoy:operations,wheel:/app/envoy:mBs@2021
mqtt:operations,wheel:/app/mqtt:mBs@2021
apigw:operations,wheel:/app/apigw:mBs@2021
EOF
```
* Bước 2: Khởi tạo User
```bash
SETUP_PATH=$HOME/setups; \
COMMAND_TYPE="create"; \
USER_FILE="$SETUP_PATH/sample-user-creation.txt";\
$SETUP_PATH/centos8-install-users.sh $COMMAND_TYPE $USER_FILE
```
* Bước 3: Cập nhật Password cho User
Sau khi hoàn thành quá trình cần thay đổi lại password trong user info file tại **bước 1**, và thực hiện câu lệnh sau để cập nhật lại.
```bash
SETUP_PATH=$HOME/setups; \
COMMAND_TYPE="password"; \
USER_FILE="$SETUP_PATH/sample-user-creation.txt";\
$SETUP_PATH/centos8-install-users.sh $COMMAND_TYPE $USER_FILE
```


## 5. Thiết lập Firewall

> Biên soạn bởi Đinh Văn Phương <phuongdvk47@gmail.com>
<!--stackedit_data:
eyJoaXN0b3J5IjpbLTgxNDA0MTc5NCwxMjYwNjUxMTM0LC01OD
QzNDkyMzIsLTY1MjU0NjU4OSwtNDU2NTg4OTQxLDcwMjU5MDI3
NywyMDc4MzkwMjA3LDE0MjI2NzA0MzAsMTI1NTk3NzQyMCwxNT
A4NDU3NjQ1LC00MjAxMzQ5MTgsNjM3NDU3MDYwLDE2NTM5MDk3
NjksMzYxODY4MTc0LC0yMDk5NDkyOTEsLTE4ODAxOTgwNzQsLT
E3Njg3MDg5MjEsLTE2MzQ2Mzk3MTEsMTIzNTcyNTUzOSwtMTc1
OTMyNjg4OF19
-->