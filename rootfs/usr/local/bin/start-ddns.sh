#!/usr/bin/env bash
# shellcheck shell=bash
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
##@Version           :  202210201909-git
# @@Author           :  Jason Hempstead
# @@Contact          :  jason@casjaysdev.pro
# @@License          :  LICENSE.md
# @@ReadME           :  start-ddns.sh --help
# @@Copyright        :  Copyright: (c) 2022 Jason Hempstead, Casjays Developments
# @@Created          :  Thursday, Oct 20, 2022 19:09 EDT
# @@File             :  start-ddns.sh
# @@Description      :  script to start ddns
# @@Changelog        :  New script
# @@TODO             :  Better documentation
# @@Other            :
# @@Resource         :
# @@Terminal App     :  no
# @@sudo/root        :  no
# @@Template         :  other/start-service
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set functions
__pcheck() { [ -n "$(which pgrep 2>/dev/null)" ] && pgrep -x "$1" || return 1; }
__find() { find "$1" -mindepth 1 -type ${2:-f,d} 2>/dev/null | grep '^' || return 10; }
__curl() { curl -q -LSsf -o /dev/null -s -w "200" "$@" 2>/dev/null || return 10; }
__pgrep() { __pcheck "$1" || ps aux 2>/dev/null | grep -Fw " $1" | grep -qv ' grep' || return 10; }
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
  for proc in named tor tftp named dhcp radvd nginx; do
    ps aux | __pgrep "$proc" && echo "$proc" || status=$((status + 1))
  done
  #__curl "http://localhost:$HTTP_PORT/server-health" || status=$((status + 1))
  [ "$status" -eq 0 ] || health="Errors reported see docker logs --follow $CONTAINER_NAME"
  echo "$(uname -s) $(uname -m) is running and the health is: $health"
  return ${status:-$?}
}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
__run_dns() { named-checkconf -z /etc/named.conf && named -c /etc/named.conf || return 1; }
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set variables
DISPLAY="${DISPLAY:-}"
LANG="${LANG:-C.UTF-8}"
DOMAINNAME="${DOMAINNAME:-}"
TZ="${TZ:-America/New_York}"
HTTP_PORT="${HTTP_PORT:-80}"
HTTPS_PORT="${HTTPS_PORT:-}"
SERVICE_PORT="${SERVICE_PORT:-$HTTP_PORT}"
SERVICE_NAME="${CONTAINER_NAME:-}"
HOSTNAME="${HOSTNAME:-casjaysdev-ddns}"
HOSTADMIN="${HOSTADMIN:-root@${DOMAINNAME:-$HOSTNAME}}"
SSL_CERT_BOT="${SSL_CERT_BOT:-false}"
SSL_ENABLED="${SSL_ENABLED:-false}"
SSL_DIR="${SSL_DIR:-/config/ssl}"
SSL_CA="${SSL_CA:-$SSL_DIR/ca.crt}"
SSL_KEY="${SSL_KEY:-$SSL_DIR/server.key}"
SSL_CERT="${SSL_CERT:-$SSL_DIR/server.crt}"
SSL_CONTAINER_DIR="${SSL_CONTAINER_DIR:-/etc/ssl/CA}"
WWW_ROOT_DIR="${WWW_ROOT_DIR:-/data/htdocs}"
LOCAL_BIN_DIR="${LOCAL_BIN_DIR:-/usr/local/bin}"
DATA_DIR_INITIALIZED="${DATA_DIR_INITIALIZED:-}"
CONFIG_DIR_INITIALIZED="${CONFIG_DIR_INITIALIZED:-}"
DEFAULT_DATA_DIR="${DEFAULT_DATA_DIR:-/usr/local/share/template-files/data}"
DEFAULT_CONF_DIR="${DEFAULT_CONF_DIR:-/usr/local/share/template-files/config}"
DEFAULT_TEMPLATE_DIR="${DEFAULT_TEMPLATE_DIR:-/usr/local/share/template-files/defaults}"
CONTAINER_IP_ADDRESS="$(ip a 2>/dev/null | grep 'inet' | grep -v '127.0.0.1' | awk '{print $2}' | sed 's|/.*||g')"
[ -n "$HTTP_PORT" ] || [ -n "$HTTPS_PORT" ] || HTTP_PORT="$SERVICE_PORT"
[ "$HTTPS_PORT" = "443" ] && HTTP_PORT="$HTTPS_PORT" && SSL_ENABLED="true"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Overwrite variables
#SERVICE_PORT=""
SERVICE_NAME="ddns"
SERVICE_COMMAND="$SERVICE_NAME"
export exec_message="Starting $SERVICE_NAME on $CONTAINER_IP_ADDRESS:$SERVICE_PORT"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Pre copy commands

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Check if this is a new container
[ -z "$DATA_DIR_INITIALIZED" ] && [ -f "/data/.docker_has_run" ] && DATA_DIR_INITIALIZED="true"
[ -z "$CONFIG_DIR_INITIALIZED" ] && [ -f "/config/.docker_has_run" ] && CONFIG_DIR_INITIALIZED="true"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Create default config
if [ "$CONFIG_DIR_INITIALIZED" = "false" ] && [ -n "$DEFAULT_TEMPLATE_DIR" ]; then
  [ -d "/config" ] && cp -Rf "$DEFAULT_TEMPLATE_DIR/." "/config/" 2>/dev/null
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Copy custom config files
if [ "$CONFIG_DIR_INITIALIZED" = "false" ] && [ -n "$DEFAULT_CONF_DIR" ]; then
  [ -d "/config" ] && cp -Rf "$DEFAULT_CONF_DIR/." "/config/" 2>/dev/null
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Copy custom data files
if [ "$DATA_DIR_INITIALIZED" = "false" ] && [ -n "$DEFAULT_DATA_DIR" ]; then
  [ -d "/data" ] && cp -Rf "$DEFAULT_DATA_DIR/." "/data/" 2>/dev/null
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Copy html files
if [ "$DATA_DIR_INITIALIZED" = "false" ] && [ -d "$DEFAULT_DATA_DIR/data/htdocs" ]; then
  [ -d "/data" ] && cp -Rf "$DEFAULT_DATA_DIR/data/htdocs/." "$WWW_ROOT_DIR/" 2>/dev/null
fi
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Post copy commands

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Initialized
[ -d "/data" ] && touch "/data/.docker_has_run"
[ -d "/config" ] && touch "/config/.docker_has_run"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# APP Variables overrides
[ -f "/root/env.sh" ] && . "/root/env.sh"
[ -f "/config/env.sh" ] && "/config/env.sh"
[ -f "/config/.env.sh" ] && . "/config/.env.sh"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Actions based on env

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# begin main app
case "$1" in
healthcheck)
  shift 1
  __heath_check "${SERVICE_NAME:-bash}"
  exit $?
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

*)
  if __pgrep "$SERVICE_NAME" && [ ! -f "/tmp/$SERVICE_NAME.pid" ]; then
    echo "$SERVICE_NAME is running"
  else
    touch "/tmp/$SERVICE_NAME.pid"
    {
      echo 'Starting dynamic DNS server...'
      date '+%Y-%m-%d %H:%M'
      echo "Setting hostname to $HOSTNAME"
    } &>/data/log/entrypoint.log
    [ -d "/data/log" ] && rm -Rf /data/log/* || mkdir -p "/data/log"
    [ -f "/etc/profile" ] && [ ! -f "/root/.profile" ] && cp -Rf "/etc/profile" "/root/.profile"

    if [ -f "/config/rndc.key" ]; then
      RNDC_KEY="$(cat /config/rndc.key | grep secret | awk '{print $2}' | sed 's|;||g;s|"||g')"
    else
      rndc-confgen -a -c /etc/rndc.key &>>/data/log/named.log
      RNDC_KEY="$(cat /etc/rndc.key | grep secret | awk '{print $2}' | sed 's|;||g;s|"||g')"
      [ -f "/config/rndc.key" ] || cp -Rf "/etc/rndc.key" "/config/rndc.key" &>>/data/log/entrypoint.log
      [ -f "/config/rndc.conf" ] || { [ -f "/etc/rndc.conf" ] && cp -Rf "/etc/rndc.conf" "/config/rndc.conf" &>>/data/log/entrypoint.log; }
    fi
    [ -d "/run/tor" ] || mkdir -p "/run/tor" &>>/data/log/entrypoint.log
    [ -d "/etc/dhcp" ] || mkdir -p "/etc/dhcp" &>>/data/log/entrypoint.log
    [ -d "/run/dhcp" ] || mkdir -p "/run/dhcp" &>>/data/log/entrypoint.log
    [ -d "/var/tftpboot" ] && [ ! -d "/data/tftp" ] && mv -f "/var/tftpboot" "/data/tftp" &>>/data/log/entrypoint.log
    [ -d "/var/lib/dhcp" ] || mkdir -p "/var/lib/dhcp" &>>/data/log/entrypoint.log
    [ -d "/data/tor" ] || cp -Rf "/var/lib/tor" "/data/tor" &>>/data/log/entrypoint.log
    [ -d "/data/htdocs/www" ] || cp -Rf "/var/lib/ddns/data/htdocs/www" "/data/htdocs/www" &>>/data/log/entrypoint.log
    [ -d "/data/named" ] || cp -Rf "/var/lib/ddns/data/named" "/data/named" &>>/data/log/entrypoint.log
    [ -d "/config/tor" ] || cp -Rf "/var/lib/ddns/config/tor" "/config/tor" &>>/data/log/entrypoint.log
    [ -d "/config/dhcp" ] || cp -Rf "/var/lib/ddns/config/dhcp" "/config/dhcp" &>>/data/log/entrypoint.log
    [ -d "/config/named" ] || cp -Rf "/var/lib/ddns/config/named" "/config/named" &>>/data/log/entrypoint.log
    [ -f "/config/radvd.conf" ] || cp -Rf "/var/lib/ddns/config/radvd.conf" "/config/radvd.conf" &>>/data/log/entrypoint.log
    [ -f "/config/named.conf" ] || cp -Rf "/var/lib/ddns/config/named.conf" "/config/named.conf" &>>/data/log/entrypoint.log
    # - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
    find "/config" "/data" -type f -exec sed -i 's|'${OLD_DATE:-2018020901}'|'$DATE'|g' {} \;
    find "/config" "/data" -type f -exec sed -i 's|REPLACE_DOMAIN|'$DOMAIN_NAME'|g' {} \;
    find "/config" "/data" -type f -exec sed -i 's|REPLACE_WITH_RNDC_KEY|'$RNDC_KEY'|g' {} \;
    find "/config" "/data" -type f -exec sed -i 's|REPLACE_IPV4_ADDRESS|'$IPV4_ADDR'|g' {} \;
    find "/config" "/data" -type f -exec sed -i 's|REPLACE_IPV4_ADDR_START|'$IPV4_ADDR_START'|g' {} \;
    find "/config" "/data" -type f -exec sed -i 's|REPLACE_IPV4_ADDR_END|'$IPV4_ADDR_END'|g' {} \;
    find "/config" "/data" -type f -exec sed -i 's|REPLACE_IPV4_SUBNET|'$IPV4_ADDR_SUBNET'|g' {} \;
    find "/config" "/data" -type f -exec sed -i 's|REPLACE_IPV4_NETMASK|'$IPV4_ADDR_NETMASK'|g' {} \;
    find "/config" "/data" -type f -exec sed -i 's|REPLACE_IPV4_GATEWAY|'$IPV4_ADDR_GATEWAY'|g' {} \;
    find "/config" "/data" -type f -exec sed -i 's|REPLACE_IPV6_ADDRESS|'$IPV6_ADDR'|g' {} \;
    find "/config" "/data" -type f -exec sed -i 's|REPLACE_IPV6_ADDR_START|'$IPV6_ADDR_START'|g' {} \;
    find "/config" "/data" -type f -exec sed -i 's|REPLACE_IPV6_ADDR_END|'$IPV6_ADDR_END'|g' {} \;
    find "/config" "/data" -type f -exec sed -i 's|REPLACE_IPV6_SUBNET|'$IPV6_ADDR_SUBNET'|g' {} \;
    find "/config" "/data" -type f -exec sed -i 's|REPLACE_IPV6_NETMASK|'$IPV6_ADDR_NETMASK'|g' {} \;
    find "/config" "/data" -type f -exec sed -i 's|REPLACE_IPV6_GATEWAY|'$IPV6_ADDR_GATEWAY'|g' {} \;

    if [ -f "/config/named.conf" ]; then
      echo "Initializing named" &>>/data/log/entrypoint.log
      rm -R /data/log/dns/* &>>/data/log/entrypoint.log
      cp -Rf "/config/named.conf" "/etc/named.conf"
      [ -d "/data/log/dns" ] || mkdir -p "/data/log/dns"
      [ -d "/data/named" ] && cp -Rf "/data/named" "/var/named"
      [ -d "/config/named" ] && cp -Rf "/config/named" "/etc/named"
      [ -f "/config/rndc.key" ] && cp -Rf "/config/rndc.key" "/etc/rndc.key"
      [ -f "/config/rndc.conf" ] && cp -Rf "/config/rndc.conf" "/etc/rndc.conf"
      chmod -f 777 "/data/log/dns"
      __run_dns &>>/data/log/named.log &
      sleep .5
    fi

    if [ -n "$IP6_ADDR" ]; then
      if [ -f "/config/dhcp/dhcpd6.conf" ]; then
        echo "Initializing dhcpd6" &>>/data/log/entrypoint.log
        cp -Rf "/config/dhcp/dhcpd6.conf" "/etc/dhcp/dhcpd6.conf"
        touch /var/lib/dhcp/dhcpd6.leases
        dhcpd -6 -cf /etc/dhcp/dhcpd6.conf &>>/data/log/dhcpd6.log &
        sleep .5
      fi
      if [ -f "/config/radvd.conf" ]; then
        echo "Initializing radvd" &>>/data/log/entrypoint.log
        cp -Rf "/config/radvd.conf" "/etc/radvd.conf"
        radvd -C /etc/radvd.conf &>>/data/log/radvd.log &
        sleep .5
      fi
    fi

    if [ -f "/config/dhcp/dhcpd4.conf" ]; then
      echo "Initializing dhcpd4" &>>/data/log/entrypoint.log
      cp -Rf "/config/dhcp/dhcpd4.conf" "/etc/dhcp/dhcpd4.conf"
      touch /var/lib/dhcp/dhcpd.leases
      dhcpd -4 -cf /etc/dhcp/dhcpd4.conf &>>/data/log/dhcpd4.log &
      sleep .5
    fi

    if [ -d "/config/tor" ]; then
      echo "Initializing tor" &>>/data/log/entrypoint.log
      [ -d "/config/tor" ] && cp -Rf "/config/tor" "/etc/tor"
      chown -Rf root:root "/var/lib/tor"
      chmod 700 "/run/tor"
      tor -f "/etc/tor/torrc" &>>/data/log/tor.log &
    fi
    if [ -d "/data/tftp" ]; then
      echo "Initializing tftp" &>>/data/log/entrypoint.log
      rm -Rf "/var/tftpboot"
      ln -sf "/data/tftp" "/var/tftpboot"
      in.tftpd -vv -L /var/tftpboot &>/data/log/tftpd.log &
    fi
    if [ -f "/data/htdocs/www/index.php" ]; then
      echo "Initializing web on $IP_ADDR" &>>/data/log/entrypoint.log
      nginx -c "/etc/nginx/nginx.conf" &>>/data/log/php.log &
      sleep .5
    fi
    sleep 5
    date +'%Y-%m-%d %H:%M' >/data/log/entrypoint.log
    echo "Initializing completed" &>>/data/log/entrypoint.log
    tail -n 1000 -f /data/log/*.log
  fi
  ;;
esac
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# Set exit code
exitCode="${exitCode:-$?}"
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# End application
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# lets exit with code
exit ${exitCode:-$?}
# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
# end
