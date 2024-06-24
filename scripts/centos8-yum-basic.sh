#!/usr/bin/bash

###############
# Load common
###############
SCRIPT_DIR=$(dirname $0)
source "$SCRIPT_DIR/centos8-common.sh"

###############
# Execute
###############
user_check_sudo
if [ $? -ne 0 ]; then
  echo "please login user with sudo permission"
  return 1
fi

sudo -E dnf --enablerepo=extras install -y epel-release
sudo -E dnf install -y kernel-headers kernel-devel systemd-devel
sudo -E dnf install -y libmpc mpfr gmp mpfr-devel gmp-devel expat-devel gdbm-devel ncurses-devel tk-devel xz-devel
sudo -E dnf install -y readline readline-devel openssl-devel libnl3-devel net-snmp-devel ipset-libs ipvsadm pcre-devel logrotate sqlite-devel
sudo -E dnf install -y tar zlib zlib-devel zip unzip bzip2-devel wget telnet sysstat psmisc tcpdump lsof socat net-tools
sudo -E dnf install -y git lm_sensors vim-common
sudo -E dnf install -y python2 python3 htop bmon vnstat iptraf