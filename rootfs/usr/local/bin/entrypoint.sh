#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202210201909-git
# @@Author           :  Jason Hempstead
# @@Contact          :  jason@casjaysdev.pro
# @@License          :  LICENSE.md
# @@ReadME           :  entrypoint.sh --help
# @@Copyright        :  Copyright: (c) 2022 Jason Hempstead, Casjays Developments
# @@Created          :  Thursday, Oct 20, 2022 19:09 EDT
# @@File             :  entrypoint.sh
# @@Description      :  entrypoint point for ddns
# @@Changelog        :  New script
# @@TODO             :  Better documentation
# @@Other            :
# @@Resource         :
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  other/docker-entrypoint
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set bash options
[ -n "$DEBUG" ] && set -x
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set functions
__exec_command() {
  local exitCode=0
  local cmd="${*:-bash -l}"
  echo "${exec_message:-Executing command: $cmd}"
  $cmd || exitCode=1
  [ "$exitCode" = 0 ] || exitCode=10
  return ${exitCode:-$?}
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__pcheck() { [ -n "$(which pgrep 2>/dev/null)" ] && pgrep -x "$1" || return 1; }
__find() { find "$1" -mindepth 1 -type ${2:-f,d} 2>/dev/null | grep '^' || return 10; }
__curl() { curl -q -LSsf -o /dev/null -s -w "200" "$@" 2>/dev/null || return 10; }
__pgrep() { __pcheck "${1:-$SERVICE_NAME}" || ps aux 2>/dev/null | grep -Fw " ${1:-$SERVICE_NAME}" | grep -qv ' grep' || return 10; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__certbot() {
  [ -n "$DOMANNAME" ] && [ -n "$CERT_BOT_MAIL" ] || { echo "The variables DOMANNAME and CERT_BOT_MAIL are set" && exit 1; }
  [ "$SSL_CERT_BOT" = "true" ] && type -P certbot &>/dev/null || { export SSL_CERT_BOT="" && return 10; }
  certbot $1 --agree-tos -m $CERT_BOT_MAIL certonly --webroot -w "${WWW_ROOT_DIR:-/data/htdocs/www}" -d $DOMAINNAME -d $DOMAINNAME \
    --put-all-related-files-into "$SSL_DIR" -key-path "$SSL_KEY" -fullchain-path "$SSL_CERT"
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__heath_check() {
  status=0 health="Good"
  __pgrep ${1:-} || status=$((status + 1))
  #__curl "https://1.1.1.1" || status=$((status + 1))
  #__curl "http://localhost:$HTTP_PORT/server-health" || status=$((status + 1))
  [ "$status" -eq 0 ] || health="Errors reported see docker logs --follow $CONTAINER_NAME"
  echo "$(uname -s) $(uname -m) is running and the health is: $health"
  return ${status:-$?}
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__start_all_services() {
  echo "$service_message"
  start-ddns.sh
  return $?
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Additional functions

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# export functions
export -f __exec_command __pcheck __pgrep __find __curl __heath_check __certbot __start_all_services
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Define default variables - do not change these - redefine with -e or set under Additional
DISPLAY="${DISPLAY:-}"
LANG="${LANG:-C.UTF-8}"
DOMAINNAME="${DOMAINNAME:-}"
TZ="${TZ:-America/New_York}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-}"
SERVICE_PORT="${SERVICE_PORT:-}"
SERVICE_NAME="${CONTAINER_NAME:-}"
HOSTNAME="${HOSTNAME:-casjaysdev-ddns}"
HOSTADMIN="${HOSTADMIN:-root@${DOMAINNAME:-$HOSTNAME}}"
CERT_BOT_MAIL="${CERT_BOT_MAIL:-certbot-mail@casjay.pro}"
SSL_CERT_BOT="${SSL_CERT_BOT:-false}"
SSL_ENABLED="${SSL_ENABLED:-false}"
SSL_DIR="${SSL_DIR:-/config/ssl}"
SSL_CA="${SSL_CA:-$SSL_DIR/ca.crt}"
SSL_KEY="${SSL_KEY:-$SSL_DIR/server.key}"
SSL_CERT="${SSL_CERT:-$SSL_DIR/server.crt}"
SSL_CONTAINER_DIR="${SSL_CONTAINER_DIR:-/etc/ssl/CA}"
WWW_ROOT_DIR="${WWW_ROOT_DIR:-/data/htdocs}"
LOCAL_BIN_DIR="${LOCAL_BIN_DIR:-/usr/local/bin}"
DEFAULT_DATA_DIR="${DEFAULT_DATA_DIR:-/usr/local/share/template-files/data}"
DEFAULT_CONF_DIR="${DEFAULT_CONF_DIR:-/usr/local/share/template-files/config}"
DEFAULT_TEMPLATE_DIR="${DEFAULT_TEMPLATE_DIR:-/usr/local/share/template-files/defaults}"
CONTAINER_IP_ADDRESS="$(ip a 2>/dev/null | grep 'inet' | grep -v '127.0.0.1' | awk '{print $2}' | sed 's|/.*||g')"
[ -n "$HTTP_PORT" ] || [ -n "$HTTPS_PORT" ] || HTTP_PORT="$SERVICE_PORT"
[ "$HTTPS_PORT" = "443" ] && HTTP_PORT="$HTTPS_PORT" && SSL_ENABLED="true"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Additional variables and variable overrides
#SERVICE_NAME=""
export service_message="Starting $CONTAINER_NAME"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
DATE="$(date +%Y%m%d)01"
OLD_DATE="${OLD_DATE:-2018020901}"
NETDEV="$(ip route 2>/dev/null | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//" | awk '{print $1}')"
IPV4_ADDR="$(ifconfig $NETDEV 2>/dev/null | grep -E "venet|inet" | grep -v "127.0.0." | grep 'inet' | grep -v inet6 | awk '{print $2}' | sed s/addr://g | head -n1 | grep '^' || echo '')"
IPV6_ADDR="$(ifconfig "$NETDEV" 2>/dev/null | grep -E "venet|inet" | grep 'inet6' | grep -i global | awk '{print $2}' | head -n1 | grep '^' || echo '')"
IPV4_ADDR_GATEWAY="$(ip route show default | awk '/default/ {print $3}' | head -n1 | grep '^' || echo '')"
HOSTNAME="$(hostname -s).${DOMAIN_NAME}"
export IPV4_ADDR="${IPV4_ADDR:-10.0.0.2}"
export IPV4_ADDR_SUBNET="${IPV4_ADDR_SUBNET:-10.0.0.0}"
export IPV4_ADDR_START="${IPV4_ADDR_START:-10.0.100.1}"
export IPV4_ADDR_END="${IPV4_ADDR_END:-10.0.100.254}"
export IPV4_ADDR_NETMASK="${IPV4_ADDR_NETMASK:-255.255.0.0}"
export IPV4_ADDR_GATEWAY="${IPV4_ADDR_GATEWAY:-10.0.0.1}"
export IPV6_ADDR="${IP6_ADDR:-2001:0db8:edfa:1234::2}"
export IPV6_ADDR_SUBNET="${IPV6_ADDR_SUBNET:-2001:0db8:edfa:1234::}"
export IPV6_ADDR_START="${IPV6_ADDR_START:-2001:0db8:edfa:1234:5678::1}"
export IPV6_ADDR_END="${IPV6_ADDR_END:-2001:0db8:edfa:1234:5678::ffff}"
export IPV6_ADDR_NETMASK="${IPV6_ADDR_NETMASK:-64}"
export IPV6_ADDR_GATEWAY="${IPV6_ADDR_GATEWAY:-2001:0db8:edfa:1234::1}"
export DOMAIN_NAME="${DOMAIN_NAME:-test}"
[ "$DOMAIN_NAME" == "local" ] && DOMAIN_NAME="test"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check if this is a new container
[ -f "/data/.docker_has_run" ] && DATA_DIR_INITIALIZED="true" || DATA_DIR_INITIALIZED="false"
[ -f "/config/.docker_has_run" ] && CONFIG_DIR_INITIALIZED="true" || CONFIG_DIR_INITIALIZED="false"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# export variables
export DATE OLD_DATE NETDEV IPV4_ADDR IPV6_ADDR IPV4_ADDR_GATEWAY DOMAIN_NAME
export LANG TZ DOMAINNAME HOSTNAME HOSTADMIN SSL_ENABLED SSL_DIR SSL_CA SSL_KEY SERVICE_NAME
export SSL_DIR HTTP_PORT HTTPS_PORT LOCAL_BIN_DIR DEFAULT_CONF_DIR CONTAINER_IP_ADDRESS
export SSL_CONTAINER_DIR SSL_CERT_BOT DISPLAY CONFIG_DIR_INITIALIZED DATA_DIR_INITIALIZED
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# import variables from file
[ -f "/root/env.sh" ] && . "/root/env.sh"
[ -f "/config/env.sh" ] && "/config/env.sh"
[ -f "/config/.env.sh" ] && . "/config/.env.sh"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set timezone
[ -n "$TZ" ] && echo "$TZ" >"/etc/timezone"
[ -f "/usr/share/zoneinfo/$TZ" ] && ln -sf "/usr/share/zoneinfo/$TZ" "/etc/localtime"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set hostname
if [ -n "$HOSTNAME" ]; then
  echo "$HOSTNAME" >"/etc/hostname"
  echo "127.0.0.1 $HOSTNAME localhost $HOSTNAME.local" >"/etc/hosts"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Add domain to hosts file
if [ -n "$DOMAINNAME" ]; then
  echo "$HOSTNAME.${DOMAINNAME:-local}" >"/etc/hostname"
  echo "127.0.0.1 $HOSTNAME localhost $HOSTNAME.local" >"/etc/hosts"
  echo "${CONTAINER_IP_ADDRESS:-127.0.0.1} $HOSTNAME.$DOMAINNAME" >>"/etc/hosts"
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Delete any gitkeep files
[ -d "/data" ] && rm -Rf "/data/.gitkeep" "/data"/*/*.gitkeep
[ -d "/config" ] && rm -Rf "/config/.gitkeep" "/data"/*/*.gitkeep
[ -f "/usr/local/bin/.gitkeep" ] && rm -Rf "/usr/local/bin/.gitkeep"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create directories
[ -d "/data/log" ] || mkdir -p "/data/log"
[ -d "/etc/ssl" ] || mkdir -p "$SSL_CONTAINER_DIR"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create files

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create symlinks

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
if [ "$SSL_ENABLED" = "true" ] || [ "$SSL_ENABLED" = "yes" ]; then
  if [ -f "/config/ssl/server.crt" ] && [ -f "/config/ssl/server.key" ]; then
    export SSL_ENABLED="true"
    if [ -n "$SSL_CA" ] && [ -f "$SSL_CA" ]; then
      mkdir -p "$SSL_CONTAINER_DIR/certs"
      cat "$SSL_CA" >>"/etc/ssl/certs/ca-certificates.crt"
      cp -Rf "/config/ssl/." "$SSL_CONTAINER_DIR/"
    fi
  else
    [ -d "$SSL_DIR" ] || mkdir -p "$SSL_DIR"
    create-ssl-cert
  fi
  type update-ca-certificates &>/dev/null && update-ca-certificates
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[ -f "$SSL_CA" ] && cp -Rfv "$SSL_CA" "$SSL_CONTAINER_DIR/ca.crt"
[ -f "$SSL_KEY" ] && cp -Rfv "$SSL_KEY" "$SSL_CONTAINER_DIR/server.key"
[ -f "$SSL_CERT" ] && cp -Rfv "$SSL_CERT" "$SSL_CONTAINER_DIR/server.crt"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Setup bin directory
SET_USR_BIN=""
[ -d "/data/bin" ] && SET_USR_BIN+="$(__find /data/bin f) "
[ -d "/config/bin" ] && SET_USR_BIN+="$(__find /config/bin f) "
if [ -n "$SET_USR_BIN" ]; then
  echo "Setting up bin"
  for create_bin in $SET_USR_BIN; do
    create_bin_name="$(basename "$create_bin")"
    ln -sf "$create_bin" "$LOCAL_BIN_DIR/$create_bin_name"
  done
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create default config
if [ "$CONFIG_DIR_INITIALIZED" = "false" ] && [ -d "/config" ]; then
  echo "Copying default config files"
  if [ -n "$DEFAULT_TEMPLATE_DIR" ] && [ -d "$DEFAULT_TEMPLATE_DIR" ]; then
    for create_template in "$DEFAULT_TEMPLATE_DIR"/*; do
      create_template_name="$(basename "$create_template")"
      cp -Rf "$create_template" "/config/$create_template_name" 2>/dev/null
    done
  fi
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Copy custom config files
if [ "$CONFIG_DIR_INITIALIZED" = "false" ] && [ -d "/config" ]; then
  echo "Copying custom config files"
  for create_config in "$DEFAULT_CONF_DIR"/*; do
    create_config_name="$(basename "$create_config")"
    cp -Rf "$create_config" "/config/$create_config_name" 2>/dev/null
  done
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Copy custom data files
if [ "$DATA_DIR_INITIALIZED" = "false" ] && [ -d "/data" ]; then
  echo "Copying data files"
  for create_data in "$DEFAULT_DATA_DIR"/*; do
    create_data_name="$(basename "$create_data")"
    cp -Rf "$create_data" "/data/$create_data_name" 2>/dev/null
  done
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Copy /config to /etc
if [ -d "/config" ]; then
  echo "Copying /config to /etc"
  for create_conf in /config/*; do
    if [ -n "$create_conf" ]; then
      create_conf_name="$(basename "$create_conf")"
      if [ -e "/etc/$create_conf_name" ]; then
        if [ -d "/etc/$create_conf_name" ]; then
          cp -Rf "$create_conf/." "/etc/$create_conf_name/" 2>/dev/null
        else
          cp -Rf "$create_conf" "/etc/$create_conf_name" 2>/dev/null
        fi
      fi
    fi
  done
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Unset unneeded variables
unset SET_USR_BIN create_bin create_bin_name create_template create_template_name
unset create_data create_data_name create_config create_config_name create_conf create_conf_name
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[ -f "/data/.docker_has_run" ] || { [ -d "/data" ] && echo "Initialized on: $(date)" >"/data/.docker_has_run"; }
[ -f "/config/.docker_has_run" ] || { [ -d "/config" ] && echo "Initialized on: $(date)" >"/config/.docker_has_run"; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Additional commands
if [ ! -f "/config/env" ]; then
  echo "Creating file: /config/env" &>>/data/log/entrypoint.log
  cat <<EOF >/config/env
export RNDC_KEY="${RNDC_KEY:-}"
export OLD_DATE="${OLD_DATE:-2018020901}"
export NETDEV="$(ip route 2>/dev/null | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//" | awk '{print $1}')"
export IPV4_ADDR="$(ifconfig $NETDEV 2>/dev/null | grep -E "venet|inet" | grep -v "127.0.0." | grep 'inet' | grep -v inet6 | awk '{print $2}' | sed s/addr://g | head -n1 | grep '^' || echo '')"
export IPV6_ADDR="$(ifconfig "$NETDEV" 2>/dev/null | grep -E "venet|inet" | grep 'inet6' | grep -i global | awk '{print $2}' | head -n1 | grep '^' || echo '')"
export IPV4_ADDR="${IPV4_ADDR:-10.0.0.2}"
export IPV4_ADDR_SUBNET="${IPV4_ADDR_SUBNET:-10.0.0.0}"
export IPV4_ADDR_START="${IPV4_ADDR_START:-10.0.100.1}"
export IPV4_ADDR_END="${IPV4_ADDR_END:-10.0.100.254}"
export IPV4_ADDR_NETMASK="${IPV4_ADDR_NETMASK:-255.255.0.0}"
export IPV4_ADDR_GATEWAY="${IPV4_ADDR_GATEWAY:-10.0.0.1}"
export IPV6_ADDR="${IP6_ADDR:-2001:0db8:edfa:1234::2}"
export IPV6_ADDR_SUBNET="${IPV6_ADDR_SUBNET:-2001:0db8:edfa:1234::}"
export IPV6_ADDR_START="${IPV6_ADDR_START:-2001:0db8:edfa:1234:5678::1}"
export IPV6_ADDR_END="${IPV6_ADDR_END:-2001:0db8:edfa:1234:5678::ffff}"
export IPV6_ADDR_NETMASK="${IPV6_ADDR_NETMASK:-64}"
export IPV6_ADDR_GATEWAY="${IPV6_ADDR_GATEWAY:-2001:0db8:edfa:1234::1}"

EOF
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
[ -f "/root/.bashrc" ] || printf "source /etc/profile\ncd %s\n" "$HOME" >"/root/.bashrc"
[ -f "/root/.bashrc" ] && source "/root/.bashrc"
[ -f "/config/env" ] && source "/config/env"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Show message
echo "Container ip address is: $CONTAINER_IP_ADDRESS"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
case "$1" in
--help) # Help message
  echo 'Docker container for '$APPNAME''
  echo "Usage: $APPNAME [healthcheck, bash, command]"
  echo "Failed command will have exit code 10"
  echo ""
  exit ${exitCode:-$?}
  ;;

healthcheck) # Docker healthcheck
  __heath_check "${1:-$SERVICE_NAME}" || exitCode=10
  exit ${exitCode:-$?}
  ;;

*/bin/sh | */bin/bash | bash | shell | sh) # Launch shell
  shift 1
  __exec_command "${@:-/bin/bash}"
  exit ${exitCode:-$?}
  ;;

certbot)
  shift 1
  SSL_CERT_BOT="true"
  if [ "$1" = "create" ]; then
    shift 1
    __certbot
  elif [ "$1" = "renew" ]; then
    shift 1
    __certbot "renew certonly --force-renew"
  else
    __exec_command "certbot" "$@"
  fi
  ;;

*) # Execute primary command
  if [ $# -eq 0 ]; then
    __start_all_services
    exit ${exitCode:-$?}
  else
    __exec_command "$@"
    exitCode=$?
  fi
  ;;
esac
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# end of entrypoint
exit ${exitCode:-$?}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
