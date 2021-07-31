# CentOS 8 - Cài đặt Envoy Proxy

Tài liệu này hướng dẫn việc cài đặt Envoy Proxy và các Plugin nếu có.

## 1. Các bước chuẩn bị
Các điều kiện bắt buộc phải có trước khi thực hiện cài đặt
* user envoy phải thuộc nhóm wheel để có thể thực hiện được các lệnh sudo
```bash
id envoy
## output:
## uid=1002(envoy) gid=1003(envoy) groups=1003(envoy),10(wheel),990(operations) context=unconfined_u:unconfined_r:unconfined_t:s0-s0:c0.c1023
##
```
* Kiểm tra quyền sudo với user envoy
```bash
sudo date
```
> Trường hợp, sau khi nhập password của envoy mà lệnh không được phép thực hiện thì enable sudo trong file /etc/sudoers


## 2. Cài đặt Envoy

Thiết lập Script cài đặt Envoy
```bash
```
```bash
SETUP_PATH=$HOME/setups; \
ENVOY_VERSION="1.19.0"; \
ENVOY_HOME=$HOME/v$ENVOY_VERSION;\

```

Cài đặt Envoy
```bash
SETUP_PATH=$HOME/setups; \
PACKAGE_VERSION="1.19.0"; \
PACKAGE_NAME="Miniconda3-${PACKAGE_VERSION}-Linux-x86_64.sh"; \
PACKAGE_PATH=$SETUP_PATH/$PACKAGE_NAME; \
PACKAGE_URL="https://repo.anaconda.com/miniconda/$PACKAGE_NAME"; \
TEMP="null"; \
OUTPUT="/opt/Miniconda3/conda-${PACKAGE_VERSION}"; \
COMMAND_TYPE="miniconda3"; \
$SETUP_PATH/centos8-install-url.sh $PACKAGE_NAME $PACKAGE_PATH $PACKAGE_URL $TEMP $OUTPUT $COMMAND_TYPE
```

## 3. Cấu hình Envoy




---
> Biên soạn bởi Đinh Văn Phương <phuongdvk47@gmail.com>
<!--stackedit_data:
eyJoaXN0b3J5IjpbMjQ3NjkyNTQ3LC03MjEzNTY2NTcsMTAzNz
AwNjYwMiwxMjcwNzY0MTc1LC0xMDM3MDI2MTExXX0=
-->