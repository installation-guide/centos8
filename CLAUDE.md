# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a CentOS 8 server infrastructure setup repository — a collection of Bash scripts and configuration templates for deploying and managing services on CentOS 8 servers. The documentation (`docs/`) is written in Vietnamese. There are no build steps, test suites, or package managers; the scripts are run directly on target servers.

## Running Scripts

All install scripts must be run as a user with `sudo` access. They self-check via `user_check_sudo()` and exit early if permissions are insufficient.

```bash
# Set up the shared working directory first
export SETUP_PATH=$HOME/setups
mkdir -p $SETUP_PATH

# Copy scripts to the target server, then run the desired install script
bash scripts/centos8-yum-basic.sh          # Install base system packages
bash scripts/centos8-install-redis.sh      # Install Redis
bash scripts/centos8-install-kafka.sh      # Install Kafka + Zookeeper
bash scripts/centos8-install-nginx.sh      # Build and install Nginx from source
bash scripts/centos8-install-envoy.sh      # Install Envoy via func-e

# User management
bash scripts/centos8-install-users.sh create   <user-file>    # Create OS users
bash scripts/centos8-install-users.sh password <user-file>    # Reset passwords

# Service skeleton (creates standard directory layout for a new service)
SERVICE_NAME=my-service SERVICE_BASE_DIR=/app bash scripts/centos8-install-service-skeloton.sh
```

Version and port overrides are passed as environment variables before the script:

```bash
REDIS_VERSION=6.2.5 REDIS_PORT=6379 bash scripts/centos8-install-redis.sh
KAFKA_VERSION=2.5.0 SCALA_VERSION=2.12 KAFKA_PORT=9092 bash scripts/centos8-install-kafka.sh
NGINX_VERSION=1.20.1 bash scripts/centos8-install-nginx.sh
ENVOY_VERSION=1.19.0 ENVOY_ADMIN_PORT=3888 bash scripts/centos8-install-envoy.sh
```

## Architecture

### Shared Library: `scripts/centos8-common.sh`

Every install script starts with:
```bash
SCRIPT_DIR=$(dirname $0)
source "$SCRIPT_DIR/centos8-common.sh"
```

Key functions provided:
- `user_check_sudo` — checks sudo access (returns 0 if ok)
- `install_package_from_repo <pkg...>` — wraps dnf/yum/apt-get
- `download_and_extract_package_from_url <path> <url> <output> <type>` — downloads and extracts tarballs
- `install_package_from_url <name> <path> <url> <temp> <output> <type>` — full install with sudo (used for system-wide installs)
- `install_source_from_url_with_sudo` — download + `make && sudo make install`
- `is_overwrite_file` / `is_overwrite_file_with_sudo` — interactive prompts before overwriting existing files; returns `Y`, `N`, or `E`
- `copy_file_from_to` — safe file copy with existence check
- `init_os_groups` / `init_os_users` / `users_reset_password` / `users_update_groups` — OS user/group management
- `fw_permanent_add_tcp_port` / `fw_permanent_remove_tcp_port` / `fw_reload_service` — firewalld helpers

### Configuration Templating

Config files and systemd units are generated using `envsubst`. Template files live in `scripts/<service>/` and contain shell variable placeholders. The install script exports the relevant variables, pipes the template through `envsubst`, writes the result to `$SETUP_PATH/<service>/etc/`, then `sudo cp`s it to the system path.

Example targets:
- `/etc/sysconfig/<service>` — environment variables sourced by systemd
- `/etc/systemd/system/<service>.service` — unit file
- `/etc/sudoers.d/<service>` — sudoers rules

### Service Directory Layout

Each service is installed under `$HOME/v<VERSION>/` with a consistent structure:

```
$HOME/v<VERSION>/
  bin/          # Binaries (or symlinks for gRPC services)
  conf/         # Runtime configuration
  logs/         # Log files
  data/         # Persistent data
  run/          # PID files
  modules/      # Loadable plugins (Redis only)
```

gRPC services additionally have:
```
  app/          # Versioned binary drops (e.g. event-service-linux-amd64-0.8.4)
  shells/       # Deployment scripts (deploy_service.sh)
```

The gRPC `deploy_service.sh` script atomically deploys a new binary by stopping the service, replacing the `bin/<service>` symlink to point to the new binary in `app/`, and restarting via systemd.

### Service Categories

| Directory | Services |
|-----------|----------|
| `scripts/envoy/` | Envoy proxy (via `func-e` tool) |
| `scripts/kafka/` | Kafka broker + Zookeeper |
| `scripts/redis/` | Redis server + optional modules (RediSearch, RedisJSON, RedisTimeSeries, RedisGraph, RedisAI, RedisGears) |
| `scripts/nginx/` | Nginx built from source with brotli and custom OpenSSL |
| `scripts/mosquitto/` | MQTT broker |
| `scripts/grpc/` | Multiple gRPC microservices (events, notify, publish, watchlist, forwarder, bgv2) |
| `scripts/ics/` | ICS Support service |
| `scripts/nav/` | Navigation structure services |
| `scripts/tradingview/` | TradingView chart save service |
| `scripts/wealth_management/` | Market API service |

### OS-Level Prerequisites

Before running any service install script, `docs/CentOS8-Base.md` establishes:
1. **SELinux must be disabled** — systemd cannot access user home directories with SELinux enforcing
2. **EPEL repo** — `sudo dnf --enablerepo=extras install -y epel-release`
3. **Base packages** — run `scripts/centos8-yum-basic.sh`
4. **Default OS groups**: `operations` (system group) and `ssh-users`
5. **User file format**: `username:groups:home_dir:password` (4 colon-separated fields, header lines skipped)

### Proxy Support

Scripts respect standard `http_proxy` / `https_proxy` environment variables. If the target server is behind a corporate proxy, set these before running any script:

```bash
export http_proxy=http://<proxy-host>:<port>
export https_proxy=http://<proxy-host>:<port>
```
