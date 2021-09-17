#!/usr/bin/env bash
# https://github.com/complexorganizations/wireguard-manager

# Require script to be run as root
function super-user-check() {
  if [ "${EUID}" -ne 0 ]; then
    echo "You need to run this script as super user."
    exit
  fi
}

# Check for root
super-user-check

# Get the current system information
function system-information() {
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO=${ID}
    ALLOWED_DISTRO="debian"
    DISTRO_VERSION=${VERSION_ID}
    ALLOWED_DISTRO_VERSION="11"
    DISTRO_KERNEL_VERSION=$(uname -r | cut -d'.' -f1-2)
    ALLOWED_DISTRO_KERNEL_VERSION="5.10"
  fi
}

# Get the current system information
system-information

# Pre-Checks system requirements
function installing-system-requirements() {
  if { [ ! -x "$(command -v curl)" ] || [ ! -x "$(command -v cut)" ] || [ ! -x "$(command -v jq)" ] || [ ! -x "$(command -v ip)" ] || [ ! -x "$(command -v lsof)" ] || [ ! -x "$(command -v cron)" ] || [ ! -x "$(command -v awk)" ] || [ ! -x "$(command -v pgrep)" ] || [ ! -x "$(command -v grep)" ] || [ ! -x "$(command -v qrencode)" ] || [ ! -x "$(command -v sed)" ] || [ ! -x "$(command -v zip)" ] || [ ! -x "$(command -v unzip)" ] || [ ! -x "$(command -v openssl)" ] || [ ! -x "$(command -v ifupdown)" ] || [ ! -x "$(command -v nftables)" ]; }; then
    if { [ "${DISTRO}" == ${ALLOWED_DISTRO} ] && [ "${DISTRO_VERSION}" == ${ALLOWED_DISTRO_VERSION} ]; }; then
      apt-get update
      apt-get install curl coreutils jq iproute2 lsof cron gawk procps grep qrencode sed zip unzip openssl ifupdown nftables -y
    else
      echo "Error: ${DISTRO} is not supported."
      exit
    fi
  fi
}

# Run the function and check for requirements
installing-system-requirements

# Check for docker stuff
function docker-check() {
  if [ ! -f "/.dockerenv" ]; then
    echo "Error: Not running in docker."
    exit
  fi
}

# Docker Check
docker-check

# Lets check the kernel version
function kernel-check() {
  if [ "${DISTRO_KERNEL_VERSION}" != ${ALLOWED_DISTRO_KERNEL_VERSION} ]; then
    echo "Error: Kernel version is not ${DISTRO_KERNEL_VERSION}"
    exit
  fi
}

# Kernel Version
kernel-check

# Global variables
WIREGUARD_WEBSITE_URL="https://www.wireguard.com"
WIREGUARD_PATH="/etc/wireguard"
WIREGUARD_CLIENT_PATH="${WIREGUARD_PATH}/clients"
WIREGUARD_PUB_NIC="wg0"
WIREGUARD_CONFIG="${WIREGUARD_PATH}/${WIREGUARD_PUB_NIC}.conf"
WIREGUARD_ADD_PEER_CONFIG="${WIREGUARD_PATH}/${WIREGUARD_PUB_NIC}-add-peer.conf"
WIREGUARD_MANAGER_UPDATE="https://raw.githubusercontent.com/complexorganizations/wireguard-manager/main/wireguard-manager.sh"
SYSTEM_BACKUP_PATH="/var/backups"
WIREGUARD_CONFIG_BACKUP="${SYSTEM_BACKUP_PATH}/wireguard-manager.zip"
WIREGUARD_OLD_BACKUP="${SYSTEM_BACKUP_PATH}/OLD_WIREGUARD_FILES"
WIREGUARD_BACKUP_PASSWORD_PATH="${HOME}/.wireguard-manager"
WIREGUARD_IP_FORWARDING_CONFIG="/etc/sysctl.d/wireguard.conf"
RESOLV_CONFIG="/etc/resolv.conf"
RESOLV_CONFIG_OLD="${RESOLV_CONFIG}.old"
COREDNS_ROOT="/etc/coredns"
COREDNS_BUILD="${COREDNS_ROOT}/coredns"
COREDNS_CONFIG="${COREDNS_ROOT}/Corefile"
COREDNS_HOSTFILE="${COREDNS_ROOT}/hosts"
COREDNS_SERVICE_FILE="/etc/systemd/system/coredns.service"
CHECK_ARCHITECTURE="$(dpkg --print-architecture)"
if { [ "${CHECK_ARCHITECTURE}" == "arm" ] || [ "${CHECK_ARCHITECTURE}" == "arm64" ] || [ "${CHECK_ARCHITECTURE}" == "armhf" ]; }; then
  CHECK_ARCHITECTURE="arm"
fi
COREDNS_LATEST_RELEASE=$(curl -s 'https://api.github.com/repos/coredns/coredns/releases/latest' | jq -r '.tag_name')
COREDNS_LATEST_VERSION=$(echo "${COREDNS_LATEST_RELEASE}" | cut -d'v' -f2)
COREDNS_LATEST_RELEASE_URL="https://github.com/coredns/coredns/releases/download/${COREDNS_LATEST_RELEASE}/coredns_${COREDNS_LATEST_VERSION}_linux_${CHECK_ARCHITECTURE}.tgz"
COREDNS_TMP_PATH="/tmp/coredns.tgz"
CONTENT_BLOCKER_URL="https://raw.githubusercontent.com/complexorganizations/content-blocker/main/assets/hosts"

# Usage Guide
function usage-guide() {
  echo "usage: ./$(basename "$0") <command>"
  echo "  --install     Install WireGuard"
  echo "  --start       Start WireGuard"
  echo "  --stop        Stop WireGuard"
  echo "  --restart     Restart WireGuard"
  echo "  --list        Show WireGuard"
  echo "  --add         Add WireGuard Peer"
  echo "  --remove      Remove WireGuard Peer"
  echo "  --reinstall   Reinstall WireGuard"
  echo "  --uninstall   Uninstall WireGuard"
  echo "  --update      Update WireGuard Manager"
  echo "  --ddns        Update WireGuard IP Address"
  echo "  --backup      Backup WireGuard"
  echo "  --restore     Restore WireGuard"
  echo "  --purge       Purge WireGuard Peer(s)"
  echo "  --help        Show Usage Guide"
}

# The usage of the script
function usage() {
  while [ $# -ne 0 ]; do
    case ${1} in
    --install)
      shift
      HEADLESS_INSTALL=${HEADLESS_INSTALL:-y}
      ;;
    --start)
      shift
      WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-2}
      ;;
    --stop)
      shift
      WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-3}
      ;;
    --restart)
      shift
      WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-4}
      ;;
    --list)
      shift
      WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-1}
      ;;
    --add)
      shift
      WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-5}
      ;;
    --remove)
      shift
      WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-6}
      ;;
    --reinstall)
      shift
      WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-7}
      ;;
    --uninstall)
      shift
      WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-8}
      ;;
    --update)
      shift
      WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-9}
      ;;
    --backup)
      shift
      WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-10}
      ;;
    --restore)
      shift
      WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-11}
      ;;
    --notification)
      shift
      WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-12}
      ;;
    --ddns)
      shift
      WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-13}
      ;;
    --purge)
      shift
      WIREGUARD_OPTIONS=${WIREGUARD_OPTIONS:-15}
      ;;
    --help)
      shift
      usage-guide
      ;;
    *)
      echo "Invalid argument: ${1}"
      usage-guide
      exit
      ;;
    esac
  done
}

usage "$@"

# Skips all questions and just get a client conf after install.
function headless-install() {
  if [[ ${HEADLESS_INSTALL} =~ ^[Yy]$ ]]; then
    INTERFACE_OR_PEER=${INTERFACE_OR_PEER:-1}
    IPV4_SUBNET_SETTINGS=${IPV4_SUBNET_SETTINGS:-1}
    IPV6_SUBNET_SETTINGS=${IPV6_SUBNET_SETTINGS:-1}
    SERVER_HOST_V4_SETTINGS=${SERVER_HOST_V4_SETTINGS:-1}
    SERVER_HOST_V6_SETTINGS=${SERVER_HOST_V6_SETTINGS:-1}
    SERVER_PUB_NIC_SETTINGS=${SERVER_PUB_NIC_SETTINGS:-1}
    SERVER_PORT_SETTINGS=${SERVER_PORT_SETTINGS:-1}
    NAT_CHOICE_SETTINGS=${NAT_CHOICE_SETTINGS:-1}
    MTU_CHOICE_SETTINGS=${MTU_CHOICE_SETTINGS:-1}
    SERVER_HOST_SETTINGS=${SERVER_HOST_SETTINGS:-1}
    DISABLE_HOST_SETTINGS=${DISABLE_HOST_SETTINGS:-1}
    CLIENT_ALLOWED_IP_SETTINGS=${CLIENT_ALLOWED_IP_SETTINGS:-1}
    AUTOMATIC_UPDATES_SETTINGS=${AUTOMATIC_UPDATES_SETTINGS:-1}
    AUTOMATIC_BACKUP_SETTINGS=${AUTOMATIC_BACKUP_SETTINGS:-1}
    NOTIFICATIONS_PREFERENCE_SETTINGS=${NOTIFICATIONS_PREFERENCE_SETTINGS:-1}
    DNS_PROVIDER_SETTINGS=${DNS_PROVIDER_SETTINGS:-1}
    CONTENT_BLOCKER_SETTINGS=${CONTENT_BLOCKER_SETTINGS:-1}
    CLIENT_NAME=${CLIENT_NAME:-$(openssl rand -hex 50)}
    AUTOMATIC_CONFIG_REMOVER=${AUTOMATIC_CONFIG_REMOVER:-1}
  fi
}

# No GUI
headless-install

# Set up the wireguard, if config it isn't already there.
if [ ! -f "${WIREGUARD_CONFIG}" ]; then

  # Custom IPv4 subnet
  function set-ipv4-subnet() {
    echo "What IPv4 subnet do you want to use?"
    echo "  1) 10.0.0.0/8 (Recommended)"
    echo "  2) Custom (Advanced)"
    until [[ "${IPV4_SUBNET_SETTINGS}" =~ ^[1-2]$ ]]; do
      read -rp "Subnet Choice [1-2]:" -e -i 1 IPV4_SUBNET_SETTINGS
    done
    case ${IPV4_SUBNET_SETTINGS} in
    1)
      IPV4_SUBNET="10.0.0.0/8"
      ;;
    2)
      read -rp "Custom IPv4 Subnet:" IPV4_SUBNET
      if [ -z "${IPV4_SUBNET}" ]; then
        IPV4_SUBNET="10.0.0.0/8"
      fi
      ;;
    esac
  }

  # Custom IPv4 Subnet
  set-ipv4-subnet

  # Custom IPv6 subnet
  function set-ipv6-subnet() {
    echo "What IPv6 subnet do you want to use?"
    echo "  1) fd00:00:00::0/8 (Recommended)"
    echo "  2) Custom (Advanced)"
    until [[ "${IPV6_SUBNET_SETTINGS}" =~ ^[1-2]$ ]]; do
      read -rp "Subnet Choice [1-2]:" -e -i 1 IPV6_SUBNET_SETTINGS
    done
    case ${IPV6_SUBNET_SETTINGS} in
    1)
      IPV6_SUBNET="fd00:00:00::0/8"
      ;;
    2)
      read -rp "Custom IPv6 Subnet:" IPV6_SUBNET
      if [ -z "${IPV6_SUBNET}" ]; then
        IPV6_SUBNET="fd00:00:00::0/8"
      fi
      ;;
    esac
  }

  # Custom IPv6 Subnet
  set-ipv6-subnet

  # Private Subnet Ipv4
  PRIVATE_SUBNET_V4=${PRIVATE_SUBNET_V4:-"${IPV4_SUBNET}"}
  # Private Subnet Mask IPv4
  PRIVATE_SUBNET_MASK_V4=$(echo "${PRIVATE_SUBNET_V4}" | cut -d "/" -f 2)
  # IPv4 Getaway
  GATEWAY_ADDRESS_V4="${PRIVATE_SUBNET_V4::-3}1"
  # Private Subnet Ipv6
  PRIVATE_SUBNET_V6=${PRIVATE_SUBNET_V6:-"${IPV6_SUBNET}"}
  # Private Subnet Mask IPv6
  PRIVATE_SUBNET_MASK_V6=$(echo "${PRIVATE_SUBNET_V6}" | cut -d "/" -f 2)
  # IPv6 Getaway
  GATEWAY_ADDRESS_V6="${PRIVATE_SUBNET_V6::-3}1"

  # Get the IPv4
  function test-connectivity-v4() {
      echo "How would you like to detect IPv4?"
      echo "  1) Curl (Recommended)"
      echo "  2) Custom (Advanced)"
      until [[ "${SERVER_HOST_V4_SETTINGS}" =~ ^[1-2]$ ]]; do
        read -rp "IPv4 Choice [1-2]:" -e -i 1 SERVER_HOST_V4_SETTINGS
      done
      case ${SERVER_HOST_V4_SETTINGS} in
      1)
        SERVER_HOST_V4="$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
        if [ -z "${SERVER_HOST_V4}" ]; then
          SERVER_HOST_V4="$(curl -4 -s 'https://checkip.amazonaws.com')"
        fi
        ;;
      2)
        read -rp "Custom IPv4:" SERVER_HOST_V4
        if [ -z "${SERVER_HOST_V4}" ]; then
          SERVER_HOST_V4="$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
        fi
        if [ -z "${SERVER_HOST_V4}" ]; then
          SERVER_HOST_V4="$(curl -4 -s 'https://checkip.amazonaws.com')"
        fi
        ;;
      esac
  }

  # Get the IPv4
  test-connectivity-v4

  # Determine IPv6
  function test-connectivity-v6() {
      echo "How would you like to detect IPv6?"
      echo "  1) Curl (Recommended)"
      echo "  2) Custom (Advanced)"
      until [[ "${SERVER_HOST_V6_SETTINGS}" =~ ^[1-2]$ ]]; do
        read -rp "IPv6 Choice [1-2]:" -e -i 1 SERVER_HOST_V6_SETTINGS
      done
      case ${SERVER_HOST_V6_SETTINGS} in
      1)
        SERVER_HOST_V6="$(curl -6 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
        if [ -z "${SERVER_HOST_V6}" ]; then
          SERVER_HOST_V6="$(curl -6 -s 'https://checkip.amazonaws.com')"
        fi
        ;;
      2)
        read -rp "Custom IPv6:" SERVER_HOST_V6
        if [ -z "${SERVER_HOST_V6}" ]; then
          SERVER_HOST_V6="$(curl -6 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
        fi
        if [ -z "${SERVER_HOST_V6}" ]; then
          SERVER_HOST_V6="$(curl -6 -s 'https://checkip.amazonaws.com')"
        fi
        ;;
      esac
  }

  # Get the IPv6
  test-connectivity-v6

  # Determine public NIC
  function server-pub-nic() {
    echo "How would you like to detect NIC?"
    echo "  1) IP (Recommended)"
    echo "  2) Custom (Advanced)"
    until [[ "${SERVER_PUB_NIC_SETTINGS}" =~ ^[1-2]$ ]]; do
      read -rp "Nic Choice [1-2]:" -e -i 1 SERVER_PUB_NIC_SETTINGS
    done
    case ${SERVER_PUB_NIC_SETTINGS} in
    1)
      SERVER_PUB_NIC="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
      if [ -z "${SERVER_PUB_NIC}" ]; then
        echo "Error: Your server's public network interface could not be found."
      fi
      ;;
    2)
      read -rp "Custom NAT:" SERVER_PUB_NIC
      if [ -z "${SERVER_PUB_NIC}" ]; then
        SERVER_PUB_NIC="$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)"
      fi
      ;;
    esac
  }

  # Determine public NIC
  server-pub-nic

  # Determine host port
  function set-port() {
    echo "What port do you want WireGuard server to listen to?"
    echo "  1) 51820 (Recommended)"
    echo "  2) Custom (Advanced)"
    until [[ "${SERVER_PORT_SETTINGS}" =~ ^[1-2]$ ]]; do
      read -rp "Port Choice [1-2]:" -e -i 1 SERVER_PORT_SETTINGS
    done
    case ${SERVER_PORT_SETTINGS} in
    1)
      SERVER_PORT="51820"
      if [ "$(lsof -i UDP:"${SERVER_PORT}")" ]; then
        echo "Error: Please use a different port because ${SERVER_PORT} is already in use."
      fi
      ;;
    2)
      until [[ "${SERVER_PORT}" =~ ^[0-9]+$ ]] && [ "${SERVER_PORT}" -ge 1 ] && [ "${SERVER_PORT}" -le 65535 ]; do
        read -rp "Custom port [1-65535]:" SERVER_PORT
      done
      if [ "$(lsof -i UDP:"${SERVER_PORT}")" ]; then
        echo "Error: The port ${SERVER_PORT} is already used by a different application, please use a different port."
      fi
      ;;
    esac
  }

  # Set port
  set-port

  # Determine Keepalive interval.
  function nat-keepalive() {
    echo "What do you want your keepalive interval to be?"
    echo "  1) 25 (Default)"
    echo "  2) Custom (Advanced)"
    until [[ "${NAT_CHOICE_SETTINGS}" =~ ^[1-2]$ ]]; do
      read -rp "Nat Choice [1-2]:" -e -i 1 NAT_CHOICE_SETTINGS
    done
    case ${NAT_CHOICE_SETTINGS} in
    1)
      NAT_CHOICE="25"
      ;;
    2)
      until [[ "${NAT_CHOICE}" =~ ^[0-9]+$ ]] && [ "${NAT_CHOICE}" -ge 1 ] && [ "${NAT_CHOICE}" -le 65535 ]; do
        read -rp "Custom NAT [1-65535]:" NAT_CHOICE
      done
      ;;
    esac
  }

  # Keepalive
  nat-keepalive

  # Custom MTU or default settings
  function mtu-set() {
    echo "What MTU do you want to use?"
    echo "  1) 1280 (Recommended)"
    echo "  2) Custom (Advanced)"
    until [[ "${MTU_CHOICE_SETTINGS}" =~ ^[1-2]$ ]]; do
      read -rp "MTU Choice [1-2]:" -e -i 1 MTU_CHOICE_SETTINGS
    done
    case ${MTU_CHOICE_SETTINGS} in
    1)
      MTU_CHOICE="1280"
      ;;
    2)
      until [[ "${MTU_CHOICE}" =~ ^[0-9]+$ ]] && [ "${MTU_CHOICE}" -ge 1 ] && [ "${MTU_CHOICE}" -le 65535 ]; do
        read -rp "Custom MTU [1-65535]:" MTU_CHOICE
      done
      ;;
    esac
  }

  # Set MTU
  mtu-set

  # What IP version would you like to be available on this WireGuard server?
  function ipvx-select() {
    echo "What IPv do you want to use to connect to the WireGuard server?"
    echo "  1) IPv4 (Recommended)"
    echo "  2) IPv6"
    until [[ "${SERVER_HOST_SETTINGS}" =~ ^[1-2]$ ]]; do
      read -rp "IP Choice [1-2]:" -e -i 1 SERVER_HOST_SETTINGS
    done
    case ${SERVER_HOST_SETTINGS} in
    1)
      if [ -n "${SERVER_HOST_V4}" ]; then
        SERVER_HOST="${SERVER_HOST_V4}"
      else
        SERVER_HOST="[${SERVER_HOST_V6}]"
      fi
      ;;
    2)
      if [ -n "${SERVER_HOST_V6}" ]; then
        SERVER_HOST="[${SERVER_HOST_V6}]"
      else
        SERVER_HOST="${SERVER_HOST_V4}"
      fi
      ;;
    esac
  }

  # IPv4 or IPv6 Selector
  ipvx-select

  # Do you want to disable IPv4 or IPv6 or leave them both enabled?
  function disable-ipvx() {
    echo "Do you want to disable IPv4 or IPv6 on the server?"
    echo "  1) No (Recommended)"
    echo "  2) Disable IPv4"
    echo "  3) Disable IPv6"
    until [[ "${DISABLE_HOST_SETTINGS}" =~ ^[1-3]$ ]]; do
      read -rp "Disable Host Choice [1-3]:" -e -i 1 DISABLE_HOST_SETTINGS
    done
    case ${DISABLE_HOST_SETTINGS} in
    1)
      if [ -f "${WIREGUARD_IP_FORWARDING_CONFIG}" ]; then
        rm -f ${WIREGUARD_IP_FORWARDING_CONFIG}
      fi
      if [ ! -f "${WIREGUARD_IP_FORWARDING_CONFIG}" ]; then
        echo "net.ipv4.ip_forward=1" >>${WIREGUARD_IP_FORWARDING_CONFIG}
        echo "net.ipv6.conf.all.forwarding=1" >>${WIREGUARD_IP_FORWARDING_CONFIG}
        sysctl -p ${WIREGUARD_IP_FORWARDING_CONFIG}
      fi
      ;;
    2)
      if [ -f "${WIREGUARD_IP_FORWARDING_CONFIG}" ]; then
        rm -f ${WIREGUARD_IP_FORWARDING_CONFIG}
      fi
      if [ ! -f "${WIREGUARD_IP_FORWARDING_CONFIG}" ]; then
        echo "net.ipv6.conf.all.forwarding=1" >>${WIREGUARD_IP_FORWARDING_CONFIG}
        sysctl -p ${WIREGUARD_IP_FORWARDING_CONFIG}
      fi
      ;;
    3)
      if [ -f "${WIREGUARD_IP_FORWARDING_CONFIG}" ]; then
        rm -f ${WIREGUARD_IP_FORWARDING_CONFIG}
      fi
      if [ ! -f "${WIREGUARD_IP_FORWARDING_CONFIG}" ]; then
        echo "net.ipv4.ip_forward=1" >>${WIREGUARD_IP_FORWARDING_CONFIG}
        sysctl -p ${WIREGUARD_IP_FORWARDING_CONFIG}
      fi
      ;;
    esac
  }

  # Disable IPv4 or IPv6
  disable-ipvx

  # Would you like to allow connections to your LAN neighbors?
  function client-allowed-ip() {
    echo "What traffic do you want the client to forward through WireGuard?"
    echo "  1) Everything (Recommended)"
    echo "  2) Custom (Advanced)"
    until [[ "${CLIENT_ALLOWED_IP_SETTINGS}" =~ ^[1-2]$ ]]; do
      read -rp "Client Allowed IP Choice [1-2]:" -e -i 1 CLIENT_ALLOWED_IP_SETTINGS
    done
    case ${CLIENT_ALLOWED_IP_SETTINGS} in
    1)
      CLIENT_ALLOWED_IP="0.0.0.0/0,::/0"
      ;;
    2)
      read -rp "Custom IPs:" CLIENT_ALLOWED_IP
      if [ -z "${CLIENT_ALLOWED_IP}" ]; then
        CLIENT_ALLOWED_IP="0.0.0.0/0,::/0"
      fi
      ;;
    esac
  }

  # Traffic Forwarding
  client-allowed-ip

  # real-time updates
  function enable-automatic-updates() {
    echo "Would you like to setup real-time updates?"
    echo "  1) Yes (Recommended)"
    echo "  2) No (Advanced)"
    until [[ "${AUTOMATIC_UPDATES_SETTINGS}" =~ ^[1-2]$ ]]; do
      read -rp "Automatic Updates [1-2]:" -e -i 1 AUTOMATIC_UPDATES_SETTINGS
    done
    case ${AUTOMATIC_UPDATES_SETTINGS} in
    1)
      crontab -l | {
        cat
        echo "0 0 * * * $(realpath "$0") --update"
      } | crontab -
      if ! pgrep systemd-journal; then
        service cron enable
        service cron start
      fi
      ;;
    2)
      echo "Real-time Updates Disabled"
      ;;
    esac
  }

  # real-time updates
  enable-automatic-updates

  # real-time backup
  function enable-automatic-backup() {
    echo "Would you like to setup real-time backup?"
    echo "  1) Yes (Recommended)"
    echo "  2) No (Advanced)"
    until [[ "${AUTOMATIC_BACKUP_SETTINGS}" =~ ^[1-2]$ ]]; do
      read -rp "Automatic Backup [1-2]:" -e -i 1 AUTOMATIC_BACKUP_SETTINGS
    done
    case ${AUTOMATIC_BACKUP_SETTINGS} in
    1)
      crontab -l | {
        cat
        echo "0 0 * * * $(realpath "$0") --backup"
      } | crontab -
      if ! pgrep systemd-journal; then
        service cron enable
        service cron start
      fi
      ;;
    2)
      echo "Real-time Backup Disabled"
      ;;
    esac
  }

  # real-time backup
  enable-automatic-backup

  # Send real time notifications
  function real-time-notifications() {
    echo "Would you like to setup notifications?"
    echo "  1) No (Recommended)"
    echo "  2) Twilio (Advanced)"
    until [[ "${NOTIFICATIONS_PREFERENCE_SETTINGS}" =~ ^[1-2]$ ]]; do
      read -rp "Notifications setup [1-2]:" -e -i 1 NOTIFICATIONS_PREFERENCE_SETTINGS
    done
    case ${NOTIFICATIONS_PREFERENCE_SETTINGS} in
    1)
      echo "Real-time Notifications Disabled"
      ;;
    2)
      read -rp "Twilio Account SID:" TWILIO_ACCOUNT_SID
      if [ -z "${TWILIO_ACCOUNT_SID}" ]; then
        TWILIO_ACCOUNT_SID="$(openssl rand -hex 10)"
      fi
      read -rp "Twilio Auth Token:" TWILIO_AUTH_TOKEN
      if [ -z "${TWILIO_AUTH_TOKEN}" ]; then
        TWILIO_AUTH_TOKEN="$(openssl rand -hex 10)"
      fi
      read -rp "Twilio From Number:" TWILIO_FROM_NUMBER
      if [ -z "${TWILIO_FROM_NUMBER}" ]; then
        TWILIO_FROM_NUMBER="$(openssl rand -hex 10)"
      fi
      read -rp "Twilio To Number:" TWILIO_TO_NUMBER
      if [ -z "${TWILIO_TO_NUMBER}" ]; then
        TWILIO_TO_NUMBER="$(openssl rand -hex 10)"
      fi
      crontab -l | {
        cat
        echo "* * * * * $(realpath "$0") --notification"
      } | crontab -
      if ! pgrep systemd-journal; then
        service cron enable
        service cron start
      fi
      ;;
    esac
  }

  # real time notifications updates
  real-time-notifications

  # Would you like to install coredns.
  function ask-install-dns() {
    echo "Which DNS provider would you like to use?"
    echo "  1) Coredns (Recommended)"
    echo "  2) Custom (Advanced)"
    until [[ "${DNS_PROVIDER_SETTINGS}" =~ ^[1-2]$ ]]; do
      read -rp "DNS provider [1-2]:" -e -i 1 DNS_PROVIDER_SETTINGS
    done
    case ${DNS_PROVIDER_SETTINGS} in
    1)
      INSTALL_COREDNS="y"
      echo "Do you want to prevent advertisements, tracking, malware, and phishing using the content-blocker?"
      echo "  1) Yes (Recommended)"
      echo "  2) No"
      until [[ "${CONTENT_BLOCKER_SETTINGS}" =~ ^[1-2]$ ]]; do
        read -rp "Content Blocker Choice [1-2]:" -e -i 1 CONTENT_BLOCKER_SETTINGS
      done
      case ${CONTENT_BLOCKER_SETTINGS} in
      1)
        INSTALL_BLOCK_LIST="y"
        ;;
      2)
        INSTALL_BLOCK_LIST="n"
        ;;
      esac
      ;;
    2)
      CUSTOM_DNS="y"
      ;;
    esac
  }

  # Ask To Install DNS
  ask-install-dns

  # Use custom dns
  function custom-dns() {
    if [[ ${CUSTOM_DNS} =~ ^[Yy]$ ]]; then
      echo "Which DNS do you want to use with the WireGuard connection?"
      echo "  1) Google (Recommended)"
      echo "  2) AdGuard"
      echo "  3) NextDNS"
      echo "  4) OpenDNS"
      echo "  5) Cloudflare"
      echo "  6) Verisign"
      echo "  7) Quad9"
      echo "  8) FDN"
      echo "  9) Custom (Advanced)"
      until [[ "${CLIENT_DNS_SETTINGS}" =~ ^[0-9]+$ ]] && [ "${CLIENT_DNS_SETTINGS}" -ge 1 ] && [ "${CLIENT_DNS_SETTINGS}" -le 9 ]; do
        read -rp "DNS [1-9]:" -e -i 1 CLIENT_DNS_SETTINGS
      done
      case ${CLIENT_DNS_SETTINGS} in
      1)
        CLIENT_DNS="8.8.8.8,8.8.4.4,2001:4860:4860::8888,2001:4860:4860::8844"
        ;;
      2)
        CLIENT_DNS="94.140.14.14,94.140.15.15,2a10:50c0::ad1:ff,2a10:50c0::ad2:ff"
        ;;
      3)
        CLIENT_DNS="45.90.28.167,45.90.30.167,2a07:a8c0::12:cf53,2a07:a8c1::12:cf53"
        ;;
      4)
        CLIENT_DNS="208.67.222.222,208.67.220.220,2620:119:35::35,2620:119:53::53"
        ;;
      5)
        CLIENT_DNS="1.1.1.1,1.0.0.1,2606:4700:4700::1111,2606:4700:4700::1001"
        ;;
      6)
        CLIENT_DNS="64.6.64.6,64.6.65.6,2620:74:1b::1:1,2620:74:1c::2:2"
        ;;
      7)
        CLIENT_DNS="9.9.9.9,149.112.112.112,2620:fe::fe,2620:fe::9"
        ;;
      8)
        CLIENT_DNS="80.67.169.40,80.67.169.12,2001:910:800::40,2001:910:800::12"
        ;;
      9)
        read -rp "Custom DNS:" CLIENT_DNS
        if [ -z "${CLIENT_DNS}" ]; then
          CLIENT_DNS="8.8.8.8,8.8.4.4,2001:4860:4860::8888,2001:4860:4860::8844"
        fi
        ;;
      esac
    fi
  }

  # use custom dns
  custom-dns

  # What would you like to name your first WireGuard peer?
  function client-name() {
    if [ -z "${CLIENT_NAME}" ]; then
      echo "Let's name the WireGuard Peer. Use one word only, no special characters, no spaces."
      read -rp "Client name:" -e -i "$(openssl rand -hex 25)" CLIENT_NAME
    fi
    if [ -z "${CLIENT_NAME}" ]; then
      CLIENT_NAME="$(openssl rand -hex 50)"
    fi
  }

  # Client Name
  client-name

  # Automatically remove wireguard peers after a period of time.
  function auto-remove-confg() {
    echo "Would you like to expire the peer after a certain period of time?"
    echo "  1) Every Year (Recommended)"
    echo "  2) Six Months"
    echo "  3) No"
    until [[ "${AUTOMATIC_CONFIG_REMOVER}" =~ ^[1-3]$ ]]; do
      read -rp "Automatic config expire [1-3]:" -e -i 1 AUTOMATIC_CONFIG_REMOVER
    done
    case ${AUTOMATIC_CONFIG_REMOVER} in
    1)
      crontab -l | {
        cat
        echo "0 0 1 1 * $(realpath "$0") --purge"
      } | crontab -
      if ! pgrep systemd-journal; then
        service cron enable
        service cron start
      fi
      ;;
    2)
      crontab -l | {
        cat
        echo "0 0 1 */6 * $(realpath "$0") --purge"
      } | crontab -
      if ! pgrep systemd-journal; then
        service cron enable
        service cron start
      fi
      ;;
    3)
      echo "The auto-config expiration feature has been deactivated."
      ;;
    esac
  }

  # Automatic Remove Config
  auto-remove-confg

  # Lets check the kernel version and check if headers are required
  function install-kernel-headers() {
    CHECK_KERNEL_HEADERS=$(ls -l /usr/src/linux-headers-"$(uname -r)")
    if [ ! "${CHECK_KERNEL_HEADERS}" ]; then
      echo "Kernel headers are not installed. Installing now."
    fi
  }

  # Kernel Version
  install-kernel-headers

  # Install WireGuard Server
  function install-wireguard-server() {
    if { [ ! -x "$(command -v wg)" ]; }; then
      apt-get update
      apt-get install wireguard -y
    fi
  }

  # Install WireGuard Server
  install-wireguard-server

  # Function to install coredns
  function install-coredns() {
    if [[ ${INSTALL_COREDNS} =~ ^[Yy]$ ]]; then
      if [ ! -x "$(command -v coredns)" ]; then
        if [ ! -d "${COREDNS_ROOT}" ]; then
          mkdir -p ${COREDNS_ROOT}
        fi
        if [ ! -f "${COREDNS_BUILD}" ]; then
          curl -L "${COREDNS_LATEST_RELEASE_URL}" -o "${COREDNS_TMP_PATH}"
          tar xvzf "${COREDNS_TMP_PATH}" -C "${COREDNS_ROOT}"
          rm -f "${COREDNS_TMP_PATH}"
        fi
        ln -s ${COREDNS_BUILD} /usr/bin/coredns
        echo ". {
    bind 127.0.0.1 ::1 ${GATEWAY_ADDRESS_V4} ${GATEWAY_ADDRESS_V6}
    acl {
        allow net 127.0.0.1 ::1 ${IPV4_SUBNET} ${IPV6_SUBNET}
        block
    }
    hosts ${COREDNS_HOSTFILE} {
        fallthrough
    }
    forward . tls://1.1.1.1 tls://1.0.0.1 tls://2606:4700:4700::1111 tls://2606:4700:4700::1001 {
        tls_servername cloudflare-dns.com
        health_check 5s
    }
    any
    errors
    loop
    cache
    minimal
    reload
}" >>${COREDNS_CONFIG}
        if [ -f "${RESOLV_CONFIG_OLD}" ]; then
          rm -f ${RESOLV_CONFIG_OLD}
        fi
        if [ -f "${RESOLV_CONFIG}" ]; then
          chattr -i ${RESOLV_CONFIG}
          mv ${RESOLV_CONFIG} ${RESOLV_CONFIG_OLD}
          echo "nameserver 127.0.0.1" >>${RESOLV_CONFIG}
          echo "nameserver ::1" >>${RESOLV_CONFIG}
          chattr +i ${RESOLV_CONFIG}
        fi
        echo "Coredns: true" >>${COREDNS_MANAGER}
        if [ -f "${COREDNS_TMP_PATH}" ]; then
          rm -f ${COREDNS_TMP_PATH}
        fi
        if [[ ${INSTALL_BLOCK_LIST} =~ ^[Yy]$ ]]; then
          if [ -f "${COREDNS_HOSTFILE}" ]; then
            rm -f ${COREDNS_HOSTFILE}
          fi
          curl -o ${COREDNS_HOSTFILE} ${CONTENT_BLOCKER_URL}
          sed -i -e "s/^/0.0.0.0 /" ${COREDNS_HOSTFILE}
        fi
        if [ ! -f "${COREDNS_SERVICE_FILE}" ]; then
          echo "[Unit]
Description=CoreDNS DNS server
After=network.target
[Service]
Type=simple
ExecStart=${COREDNS_BUILD} -conf=${COREDNS_CONFIG}
Restart=on-failure
[Install]
WantedBy=multi-user.target" >>${COREDNS_SERVICE_FILE}
        fi
        if ! pgrep systemd-journal; then
          service coredns enable
          service coredns restart
        fi
      fi
      CLIENT_DNS="${GATEWAY_ADDRESS_V4},${GATEWAY_ADDRESS_V6}"
    fi
  }

  # Install coredns
  install-coredns

  # WireGuard Set Config
  function wireguard-setconf() {
    SERVER_PRIVKEY=$(wg genkey)
    SERVER_PUBKEY=$(echo "${SERVER_PRIVKEY}" | wg pubkey)
    CLIENT_PRIVKEY=$(wg genkey)
    CLIENT_PUBKEY=$(echo "${CLIENT_PRIVKEY}" | wg pubkey)
    CLIENT_ADDRESS_V4="${PRIVATE_SUBNET_V4::-3}3"
    CLIENT_ADDRESS_V6="${PRIVATE_SUBNET_V6::-3}3"
    PRESHARED_KEY=$(wg genpsk)
    PEER_PORT=$(shuf -i1024-65535 -n1)
    mkdir -p ${WIREGUARD_CLIENT_PATH}
    if [ -f "${COREDNS_MANAGER}" ]; then
      IPTABLES_POSTUP="iptables -A FORWARD -i ${WIREGUARD_PUB_NIC} -j ACCEPT; iptables -t nat -A POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE; ip6tables -A FORWARD -i ${WIREGUARD_PUB_NIC} -j ACCEPT; ip6tables -t nat -A POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE; iptables -A INPUT -s ${PRIVATE_SUBNET_V4} -p udp -m udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT; ip6tables -A INPUT -s ${PRIVATE_SUBNET_V6} -p udp -m udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT"
      IPTABLES_POSTDOWN="iptables -D FORWARD -i ${WIREGUARD_PUB_NIC} -j ACCEPT; iptables -t nat -D POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE; ip6tables -D FORWARD -i ${WIREGUARD_PUB_NIC} -j ACCEPT; ip6tables -t nat -D POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE; iptables -D INPUT -s ${PRIVATE_SUBNET_V4} -p udp -m udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT; ip6tables -D INPUT -s ${PRIVATE_SUBNET_V6} -p udp -m udp --dport 53 -m conntrack --ctstate NEW -j ACCEPT"
    else
      IPTABLES_POSTUP="iptables -A FORWARD -i ${WIREGUARD_PUB_NIC} -j ACCEPT; iptables -t nat -A POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE; ip6tables -A FORWARD -i ${WIREGUARD_PUB_NIC} -j ACCEPT; ip6tables -t nat -A POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE"
      IPTABLES_POSTDOWN="iptables -D FORWARD -i ${WIREGUARD_PUB_NIC} -j ACCEPT; iptables -t nat -D POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE; ip6tables -D FORWARD -i ${WIREGUARD_PUB_NIC} -j ACCEPT; ip6tables -t nat -D POSTROUTING -o ${SERVER_PUB_NIC} -j MASQUERADE"
    fi
    # Set WireGuard settings for this host and first peer.
    echo "# ${PRIVATE_SUBNET_V4} ${PRIVATE_SUBNET_V6} ${SERVER_HOST}:${SERVER_PORT} ${SERVER_PUBKEY} ${CLIENT_DNS} ${MTU_CHOICE} ${NAT_CHOICE} ${CLIENT_ALLOWED_IP}
# ${TWILIO_ACCOUNT_SID} ${TWILIO_AUTH_TOKEN} ${TWILIO_FROM_NUMBER} ${TWILIO_TO_NUMBER}
[Interface]
Address = ${GATEWAY_ADDRESS_V4}/${PRIVATE_SUBNET_MASK_V4},${GATEWAY_ADDRESS_V6}/${PRIVATE_SUBNET_MASK_V6}
DNS = ${CLIENT_DNS}
ListenPort = ${SERVER_PORT}
MTU = ${MTU_CHOICE}
PrivateKey = ${SERVER_PRIVKEY}
PostUp = ${IPTABLES_POSTUP}
PostDown = ${IPTABLES_POSTDOWN}
SaveConfig = false
# ${CLIENT_NAME} start
[Peer]
PublicKey = ${CLIENT_PUBKEY}
PresharedKey = ${PRESHARED_KEY}
AllowedIPs = ${CLIENT_ADDRESS_V4}/32,${CLIENT_ADDRESS_V6}/128
# ${CLIENT_NAME} end" >>${WIREGUARD_CONFIG}

    echo "# ${WIREGUARD_WEBSITE_URL}
[Interface]
Address = ${CLIENT_ADDRESS_V4}/${PRIVATE_SUBNET_MASK_V4},${CLIENT_ADDRESS_V6}/${PRIVATE_SUBNET_MASK_V6}
DNS = ${CLIENT_DNS}
ListenPort = ${PEER_PORT}
MTU = ${MTU_CHOICE}
PrivateKey = ${CLIENT_PRIVKEY}
[Peer]
AllowedIPs = ${CLIENT_ALLOWED_IP}
Endpoint = ${SERVER_HOST}:${SERVER_PORT}
PersistentKeepalive = ${NAT_CHOICE}
PresharedKey = ${PRESHARED_KEY}
PublicKey = ${SERVER_PUBKEY}" >>${WIREGUARD_CLIENT_PATH}/"${CLIENT_NAME}"-${WIREGUARD_PUB_NIC}.conf
    # Service Restart
    if ! pgrep systemd-journal; then
      service wg-quick@${WIREGUARD_PUB_NIC} enable
      service wg-quick@${WIREGUARD_PUB_NIC} restart
    fi
    # Generate QR Code
    qrencode -t ansiutf8 -r ${WIREGUARD_CLIENT_PATH}/"${CLIENT_NAME}"-${WIREGUARD_PUB_NIC}.conf
    echo "Client Config --> ${WIREGUARD_CLIENT_PATH}/${CLIENT_NAME}-${WIREGUARD_PUB_NIC}.conf"
  }

  # Setting Up WireGuard Config
  wireguard-setconf

# After WireGuard Install
else

  # Already installed what next?
  function wireguard-next-questions-interface() {
    echo "What do you want to do?"
    echo "   1) Show WireGuard"
    echo "   2) Start WireGuard"
    echo "   3) Stop WireGuard"
    echo "   4) Restart WireGuard"
    echo "   5) Add WireGuard Peer (client)"
    echo "   6) Remove WireGuard Peer (client)"
    echo "   7) Reinstall WireGuard"
    echo "   8) Uninstall WireGuard"
    echo "   9) Update this script"
    echo "   10) Backup WireGuard"
    echo "   11) Restore WireGuard"
    echo "   12) Check WireGuard Status"
    echo "   13) Update Interface IP"
    echo "   14) Update Interface Port"
    echo "   15) Purge WireGuard Peers"
    until [[ "${WIREGUARD_OPTIONS}" =~ ^[0-9]+$ ]] && [ "${WIREGUARD_OPTIONS}" -ge 1 ] && [ "${WIREGUARD_OPTIONS}" -le 15 ]; do
      read -rp "Select an Option [1-15]:" -e -i 1 WIREGUARD_OPTIONS
    done
    case ${WIREGUARD_OPTIONS} in
    1) # WG Show
      wg show
      ;;
    2) # Enable & Start WireGuard
      if ! pgrep systemd-journal; then
        service wg-quick@${WIREGUARD_PUB_NIC} enable
        service wg-quick@${WIREGUARD_PUB_NIC} start
      fi
      ;;
    3) # Disable & Stop WireGuard
      if ! pgrep systemd-journal; then
        service wg-quick@${WIREGUARD_PUB_NIC} disable
        service wg-quick@${WIREGUARD_PUB_NIC} stop
      fi
      ;;
    4) # Restart WireGuard
      if ! pgrep systemd-journal; then
        service wg-quick@${WIREGUARD_PUB_NIC} restart
      fi
      ;;
    5) # WireGuard add Peer
      if [ -z "${NEW_CLIENT_NAME}" ]; then
        echo "Let's name the WireGuard Peer. Use one word only, no special characters, no spaces."
        read -rp "New client peer:" -e -i "$(openssl rand -hex 25)" NEW_CLIENT_NAME
      fi
      if [ -z "${NEW_CLIENT_NAME}" ]; then
        NEW_CLIENT_NAME="$(openssl rand -hex 50)"
      fi
      LASTIPV4=$(grep "/32" ${WIREGUARD_CONFIG} | tail -n1 | awk '{print $3}' | cut -d "/" -f 1 | cut -d "." -f 4)
      LASTIPV6=$(grep "/128" ${WIREGUARD_CONFIG} | tail -n1 | awk '{print $3}' | cut -d ":" -f 5 | cut -d "/" -f 1)
      if { [ -z "${LASTIPV4}" ] || [ -z "${LASTIPV6}" ]; }; then
        LASTIPV4="2"
        LASTIPV6="2"
      fi
      if { [ "${LASTIPV4}" -ge 255 ] || [ "${LASTIPV6}" -ge 255 ]; }; then
        CURRENT_IPV4_RANGE=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $2}')
        CURRENT_IPV6_RANGE=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $3}')
        IPV4_BEFORE_BACKSLASH=$(echo "${CURRENT_IPV4_RANGE}" | cut -d "/" -f 1 | cut -d "." -f 4)
        IPV6_BEFORE_BACKSLASH=$(echo "${CURRENT_IPV6_RANGE}" | cut -d "/" -f 1 | cut -d ":" -f 5)
        IPV4_AFTER_FIRST=$(echo "${CURRENT_IPV4_RANGE}" | cut -d "/" -f 1 | cut -d "." -f 2)
        IPV6_AFTER_FIRST=$(echo "${CURRENT_IPV6_RANGE}" | cut -d "/" -f 1 | cut -d ":" -f 2)
        SECOND_IPV4_IN_RANGE=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $2}' | cut -d "/" -f 1 | cut -d "." -f 2)
        SECOND_IPV6_IN_RANGE=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $3}' | cut -d "/" -f 1 | cut -d ":" -f 2)
        THIRD_IPV4_IN_RANGE=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $2}' | cut -d "/" -f 1 | cut -d "." -f 3)
        THIRD_IPV6_IN_RANGE=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $3}' | cut -d "/" -f 1 | cut -d ":" -f 3)
        NEXT_IPV4_RANGE=$((THIRD_IPV4_IN_RANGE + 1))
        NEXT_IPV6_RANGE=$((THIRD_IPV6_IN_RANGE + 1))
        CURRENT_IPV4_RANGE_CIDR=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $2}' | cut -d "/" -f 2)
        CURRENT_IPV6_RANGE_CIDR=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $3}' | cut -d "/" -f 2)
        FINAL_IPV4_RANGE=$(echo "${CURRENT_IPV4_RANGE}" | cut -d "/" -f 1 | cut -d "." -f 1,2)".${NEXT_IPV4_RANGE}.${IPV4_BEFORE_BACKSLASH}/${CURRENT_IPV4_RANGE_CIDR}"
        FINAL_IPV6_RANGE=$(echo "${CURRENT_IPV6_RANGE}" | cut -d "/" -f 1 | cut -d ":" -f 1,2)":${NEXT_IPV6_RANGE}::${IPV6_BEFORE_BACKSLASH}/${CURRENT_IPV6_RANGE_CIDR}"
        if { [ "${THIRD_IPV4_IN_RANGE}" -ge 255 ] || [ "${THIRD_IPV6_IN_RANGE}" -ge 255 ]; }; then
          if { [ "${SECOND_IPV4_IN_RANGE}" -ge 255 ] && [ "${SECOND_IPV6_IN_RANGE}" -ge 255 ] && [ "${THIRD_IPV4_IN_RANGE}" -ge 255 ] && [ "${THIRD_IPV6_IN_RANGE}" -ge 255 ] && [ "${LASTIPV4}" -ge 255 ] && [ "${LASTIPV6}" -ge 255 ]; }; then
            echo "Error: You are unable to add any more peers."
            exit
          fi
          NEXT_IPV4_RANGE=$((SECOND_IPV4_IN_RANGE + 1))
          NEXT_IPV6_RANGE=$((SECOND_IPV6_IN_RANGE + 1))
          FINAL_IPV4_RANGE=$(echo "${CURRENT_IPV4_RANGE}" | cut -d "/" -f 1 | cut -d "." -f 1)".${NEXT_IPV4_RANGE}.${IPV4_AFTER_FIRST}.${IPV4_BEFORE_BACKSLASH}/${CURRENT_IPV4_RANGE_CIDR}"
          FINAL_IPV6_RANGE=$(echo "${CURRENT_IPV6_RANGE}" | cut -d "/" -f 1 | cut -d ":" -f 1)":${NEXT_IPV6_RANGE}:${IPV6_AFTER_FIRST}::${IPV6_BEFORE_BACKSLASH}/${CURRENT_IPV6_RANGE_CIDR}"
        fi
        sed -i "1s|${CURRENT_IPV4_RANGE}|${FINAL_IPV4_RANGE}|" ${WIREGUARD_CONFIG}
        sed -i "1s|${CURRENT_IPV6_RANGE}|${FINAL_IPV6_RANGE}|" ${WIREGUARD_CONFIG}
        LASTIPV4="2"
        LASTIPV6="2"
      fi
      CLIENT_PRIVKEY=$(wg genkey)
      CLIENT_PUBKEY=$(echo "${CLIENT_PRIVKEY}" | wg pubkey)
      PRESHARED_KEY=$(wg genpsk)
      PEER_PORT=$(shuf -i1024-65535 -n1)
      PRIVATE_SUBNET_V4=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $2}')
      PRIVATE_SUBNET_MASK_V4=$(echo "${PRIVATE_SUBNET_V4}" | cut -d "/" -f 2)
      PRIVATE_SUBNET_V6=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $3}')
      PRIVATE_SUBNET_MASK_V6=$(echo "${PRIVATE_SUBNET_V6}" | cut -d "/" -f 2)
      SERVER_HOST=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $4}')
      SERVER_PUBKEY=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $5}')
      CLIENT_DNS=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $6}')
      MTU_CHOICE=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $7}')
      NAT_CHOICE=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $8}')
      CLIENT_ALLOWED_IP=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $9}')
      CLIENT_ADDRESS_V4="${PRIVATE_SUBNET_V4::-3}$((LASTIPV4 + 1))"
      CLIENT_ADDRESS_V6="${PRIVATE_SUBNET_V6::-3}$((LASTIPV6 + 1))"
      echo "# ${NEW_CLIENT_NAME} start
[Peer]
PublicKey = ${CLIENT_PUBKEY}
PresharedKey = ${PRESHARED_KEY}
AllowedIPs = ${CLIENT_ADDRESS_V4}/32,${CLIENT_ADDRESS_V6}/128
# ${NEW_CLIENT_NAME} end" >${WIREGUARD_ADD_PEER_CONFIG}
      wg addconf ${WIREGUARD_PUB_NIC} ${WIREGUARD_ADD_PEER_CONFIG}
      cat ${WIREGUARD_ADD_PEER_CONFIG} >>${WIREGUARD_CONFIG}
      rm -f ${WIREGUARD_ADD_PEER_CONFIG}
      echo "# ${WIREGUARD_WEBSITE_URL}
[Interface]
Address = ${CLIENT_ADDRESS_V4}/${PRIVATE_SUBNET_MASK_V4},${CLIENT_ADDRESS_V6}/${PRIVATE_SUBNET_MASK_V6}
DNS = ${CLIENT_DNS}
ListenPort = ${PEER_PORT}
MTU = ${MTU_CHOICE}
PrivateKey = ${CLIENT_PRIVKEY}
[Peer]
AllowedIPs = ${CLIENT_ALLOWED_IP}
Endpoint = ${SERVER_HOST}${SERVER_PORT}
PersistentKeepalive = ${NAT_CHOICE}
PresharedKey = ${PRESHARED_KEY}
PublicKey = ${SERVER_PUBKEY}" >>${WIREGUARD_CLIENT_PATH}/"${NEW_CLIENT_NAME}"-${WIREGUARD_PUB_NIC}.conf
      wg addconf ${WIREGUARD_PUB_NIC} <(wg-quick strip ${WIREGUARD_PUB_NIC})
      qrencode -t ansiutf8 -r ${WIREGUARD_CLIENT_PATH}/"${NEW_CLIENT_NAME}"-${WIREGUARD_PUB_NIC}.conf
      echo "Client config --> ${WIREGUARD_CLIENT_PATH}/${NEW_CLIENT_NAME}-${WIREGUARD_PUB_NIC}.conf"
      ;;
    6) # Remove WireGuard Peer
      echo "Which WireGuard client do you want to remove?"
      grep start ${WIREGUARD_CONFIG} | awk '{print $2}'
      read -rp "Type in Client Name:" REMOVECLIENT
      CLIENTKEY=$(sed -n "/\# ${REMOVECLIENT} start/,/\# ${REMOVECLIENT} end/p" ${WIREGUARD_CONFIG} | grep PublicKey | awk '{print $3}')
      wg set ${WIREGUARD_PUB_NIC} peer "${CLIENTKEY}" remove
      sed -i "/\# ${REMOVECLIENT} start/,/\# ${REMOVECLIENT} end/d" ${WIREGUARD_CONFIG}
      rm -f ${WIREGUARD_CLIENT_PATH}/"${REMOVECLIENT}"-${WIREGUARD_PUB_NIC}.conf
      wg addconf ${WIREGUARD_PUB_NIC} <(wg-quick strip ${WIREGUARD_PUB_NIC})
      ;;
    7) # Reinstall WireGuard
      dpkg-reconfigure wireguard-dkms
      modprobe wireguard
      service reenable wg-quick@${WIREGUARD_PUB_NIC}
      service restart wg-quick@${WIREGUARD_PUB_NIC}
      ;;
    8) # Uninstall WireGuard and purging files
      if ! pgrep systemd-journal; then
        service wg-quick@${WIREGUARD_PUB_NIC} disable
        service wg-quick@${WIREGUARD_PUB_NIC} stop
        wg-quick down ${WIREGUARD_PUB_NIC}
      fi
      # Removing Wireguard Files
      if [ -d "${WIREGUARD_PATH}" ]; then
        rm -rf ${WIREGUARD_PATH}
      fi
      if [ -d "${WIREGUARD_CLIENT_PATH}" ]; then
        rm -rf ${WIREGUARD_CLIENT_PATH}
      fi
      if [ -f "${WIREGUARD_CONFIG}" ]; then
        rm -f ${WIREGUARD_CONFIG}
      fi
      if [ -f "${WIREGUARD_IP_FORWARDING_CONFIG}" ]; then
        rm -f ${WIREGUARD_IP_FORWARDING_CONFIG}
      fi
      apt-get remove --purge wireguard -y
      # Delete WireGuard backup
      if [ -f "${WIREGUARD_CONFIG_BACKUP}" ]; then
        rm -f ${WIREGUARD_CONFIG_BACKUP}
        if [ -f "${WIREGUARD_BACKUP_PASSWORD_PATH}" ]; then
          rm -f "${WIREGUARD_BACKUP_PASSWORD_PATH}"
        fi
      fi
      # Uninstall coredns
      if [ -x "$(command -v coredns)" ]; then
        if ! pgrep systemd-journal; then
          service coredns disable
          service coredns stop
        fi
        if [ -f "${RESOLV_CONFIG_OLD}" ]; then
          chattr -i ${RESOLV_CONFIG}
          rm -f ${RESOLV_CONFIG}
          mv ${RESOLV_CONFIG_OLD} ${RESOLV_CONFIG}
          chattr +i ${RESOLV_CONFIG}
        fi
        if [ -d "${COREDNS_ROOT}" ]; then
          rm -rf ${COREDNS_ROOT}
        fi
        if [ -f "${COREDNS_SERVICE_FILE}" ]; then
          rm -f ${COREDNS_SERVICE_FILE}
        fi
      fi
      # If any cronjobs are identified, they should be removed.
      crontab -l | grep -v "$(realpath "$0")" | crontab -
      ;;
    9) # Update the script
      CURRENT_FILE_PATH="$(realpath "$0")"
      curl -o "${CURRENT_FILE_PATH}" ${WIREGUARD_MANAGER_UPDATE}
      chmod +x "${CURRENT_FILE_PATH}"
      # Update the unbound configs
      if [ -x "$(command -v coredns)" ]; then
        if [ -f "${COREDNS_ROOT}" ]; then
          rm -f ${COREDNS_ROOT}
          curl -o ${COREDNS_HOSTFILE} ${CONTENT_BLOCKER_URL}
          sed -i -e "s/^/0.0.0.0 /" ${COREDNS_HOSTFILE}
        fi
        if ! pgrep systemd-journal; then
          service coredns restart
        fi
      fi
      ;;
    10) # Backup WireGuard Config
      if [ -d "${WIREGUARD_PATH}" ]; then
        if [ -f "${WIREGUARD_CONFIG_BACKUP}" ]; then
          rm -f ${WIREGUARD_CONFIG_BACKUP}
        fi
        if [ -f "${WIREGUARD_BACKUP_PASSWORD_PATH}" ]; then
          rm -f "${WIREGUARD_BACKUP_PASSWORD_PATH}"
        fi
              BACKUP_PASSWORD="$(openssl rand -hex 25)"
              echo "${BACKUP_PASSWORD}" >>"${WIREGUARD_BACKUP_PASSWORD_PATH}"
              zip -P "${BACKUP_PASSWORD}" -rj ${WIREGUARD_CONFIG_BACKUP} ${WIREGUARD_CONFIG}
        ;;
      13)
        # Change the IP address of your wireguard interface.
        if [ -f "${WIREGUARD_INTERFACE}" ]; then
          OLD_SERVER_HOST=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $4}' | awk -F: '{print $1}')
          NEW_SERVER_HOST="$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
          if [ -z "${NEW_SERVER_HOST}" ]; then
            NEW_SERVER_HOST="$(curl -4 -s 'https://checkip.amazonaws.com')"
          fi
          sed -i "1s/${OLD_SERVER_HOST}/${NEW_SERVER_HOST}/" ${WIREGUARD_CONFIG}
        fi
        if [ -f "${WIREGUARD_MANAGER}" ]; then
          BACKUP_PASSWORD="$(openssl rand -hex 25)"
          echo "${BACKUP_PASSWORD}" >>"${WIREGUARD_BACKUP_PASSWORD_PATH}"
          zip -P "${BACKUP_PASSWORD}" -rj ${WIREGUARD_CONFIG_BACKUP} ${WIREGUARD_CONFIG}
        fi
      fi
      ;;
    11) # Restore WireGuard Config
      if [ -d "${WIREGUARD_PATH}" ]; then
        rm -rf ${WIREGUARD_PATH}
      fi
      unzip ${WIREGUARD_CONFIG_BACKUP} -d ${WIREGUARD_PATH}
      # Restart WireGuard
      if ! pgrep systemd-journal; then
        service wg-quick@${WIREGUARD_PUB_NIC} enable
        service wg-quick@${WIREGUARD_PUB_NIC} restart
      fi
      ;;
    12) # Twilio's server for real-time notifications.
      TWILIO_ACCOUNT_SID=$(head -2 ${WIREGUARD_CONFIG} | tail +2 | awk '{print $1}')
      TWILIO_AUTH_TOKEN=$(head -2 ${WIREGUARD_CONFIG} | tail +2 | awk '{print $2}')
      TWILIO_FROM_NUMBER=$(head -2 ${WIREGUARD_CONFIG} | tail +2 | awk '{print $3}')
      TWILIO_TO_NUMBER=$(head -2 ${WIREGUARD_CONFIG} | tail +2 | awk '{print $4}')
      if [ "$(service is-active wg-quick@"${WIREGUARD_PUB_NIC}")" == "inactive" ]; then
        if { [ -n "${TWILIO_ACCOUNT_SID}" ] && [ -n "${TWILIO_AUTH_TOKEN}" ] && [ -n "${TWILIO_FROM_NUMBER}" ] && [ -n "${TWILIO_TO_NUMBER}" ]; }; then
          curl -X POST https://api.twilio.com/2010-04-01/Accounts/"${TWILIO_ACCOUNT_SID}"/Messages.json --data-urlencode "Body=Hello, WireGuard has gone down ${SERVER_HOST}." --data-urlencode "From=${TWILIO_FROM_NUMBER}" --data-urlencode "To=${TWILIO_TO_NUMBER}" -u "${TWILIO_ACCOUNT_SID}":"${TWILIO_AUTH_TOKEN}"
        fi
      fi
      ;;
    13) # Change the IP address of your wireguard interface.
      OLD_SERVER_HOST=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $4}' | awk -F: '{print $1}')
      NEW_SERVER_HOST="$(curl -4 -s 'https://api.ipengine.dev' | jq -r '.network.ip')"
      if [ -z "${NEW_SERVER_HOST}" ]; then
        NEW_SERVER_HOST="$(curl -4 -s 'https://checkip.amazonaws.com')"
      fi
      sed -i "1s/${OLD_SERVER_HOST}/${NEW_SERVER_HOST}/" ${WIREGUARD_CONFIG}
      ;;
    14) # Change the wireguard interface's port number.
      OLD_SERVER_PORT=$(head -n1 ${WIREGUARD_CONFIG} | awk '{print $4}' | awk -F: '{print $2}')
      until [[ "${NEW_SERVER_PORT}" =~ ^[0-9]+$ ]] && [ "${NEW_SERVER_PORT}" -ge 1 ] && [ "${NEW_SERVER_PORT}" -le 65535 ]; do
        read -rp "Custom port [1-65535]: " -e -i 51820 NEW_SERVER_PORT
      done
      if [ "$(lsof -i UDP:"${NEW_SERVER_PORT}")" ]; then
        echo "Error: The port ${NEW_SERVER_PORT} is already used by a different application, please use a different port."
      fi
      sed -i "s/${OLD_SERVER_PORT}/${NEW_SERVER_PORT}/g" ${WIREGUARD_CONFIG}
      ;;
    15) # All wireguard peers should be removed from your interface
      COMPLETE_CLIENT_LIST=$(grep start ${WIREGUARD_CONFIG} | awk '{print $2}')
      for CLIENT_LIST_ARRAY in ${COMPLETE_CLIENT_LIST}; do
        USER_LIST[${ADD_CONTENT}]=${CLIENT_LIST_ARRAY}
        ADD_CONTENT=$(("${ADD_CONTENT}" + 1))
      done
      for CLIENT_NAME in "${USER_LIST[@]}"; do
        CLIENTKEY=$(sed -n "/\# ${CLIENT_NAME} start/,/\# ${CLIENT_NAME} end/p" ${WIREGUARD_CONFIG} | grep PublicKey | awk '{print $3}')
        wg set ${WIREGUARD_PUB_NIC} peer "${CLIENTKEY}" remove
        sed -i "/\# ${CLIENT_NAME} start/,/\# ${CLIENT_NAME} end/d" ${WIREGUARD_CONFIG}
        rm -f ${WIREGUARD_CLIENT_PATH}/"${CLIENT_NAME}"-${WIREGUARD_PUB_NIC}.conf
        wg addconf ${WIREGUARD_PUB_NIC} <(wg-quick strip ${WIREGUARD_PUB_NIC})
      done
      ;;
    esac
  }

  # Running Questions Command
  wireguard-next-questions-interface

fi
