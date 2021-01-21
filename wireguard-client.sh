#!/bin/bash
# https://github.com/complexorganizations/wireguard-manager

# Require script to be run as root
function super-user-check() {
  if [ "$EUID" -ne 0 ]; then
    echo "You need to run this script as super user."
    exit
  fi
}

# Check for root
super-user-check

# Checking For Virtualization
function virt-check() {
  # Deny OpenVZ Virtualization
  if [ "$(systemd-detect-virt)" == "openvz" ]; then
    echo "OpenVZ virtualization is not supported (yet)."
    exit
  # Deny LXC Virtualization
  elif [ "$(systemd-detect-virt)" == "lxc" ]; then
    echo "LXC virtualization is not supported (yet)."
    exit
  fi
}

# Virtualization Check
virt-check

# Detect Operating System
function dist-check() {
  if [ -e /etc/os-release ]; then
    # shellcheck disable=SC1091
    source /etc/os-release
    DISTRO=$ID
    DISTRO_VERSION=$VERSION_ID
  fi
}

# Check Operating System
dist-check

# Check if they are using a supported linux distro
function check-operating-system() {
  if { [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "raspbian" ] || [ "$DISTRO" == "pop" ] || [ "$DISTRO" == "kali" ] || [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "centos" ] || [ "$DISTRO" == "rhel" ] || [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ]; }; then
    echo "Correct: Linux Distro" >/dev/null 2>&1
  else
    echo "Error: Linux Distro not supported." >&2
    exit
  fi
}

# Just a basic check to check for the correct os.
check-operating-system

# Pre-Checks
function installing-system-requirements() {
  if { ! [ -x "$(command -v curl)" ] || ! [ -x "$(command -v iptables)" ] || ! [ -x "$(command -v bc)" ] || ! [ -x "$(command -v jq)" ] || ! [ -x "$(command -v sed)" ]; }; then
    if { [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "raspbian" ] || [ "$DISTRO" == "pop" ] || [ "$DISTRO" == "kali" ]; }; then
      apt-get update && apt-get install iptables curl coreutils bc jq sed e2fsprogs -y
    elif { [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "centos" ] || [ "$DISTRO" == "rhel" ]; }; then
      yum update -y && yum install epel-release iptables curl coreutils bc jq sed e2fsprogs -y
    elif { [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ]; }; then
      pacman -Syu --noconfirm iptables curl bc jq sed
    fi
  fi
}

# Run the function and check for requirements
installing-system-requirements

# Check for docker stuff
function docker-check() {
  if [ -f /.dockerenv ]; then
    DOCKER_KERNEL_VERSION_LIMIT=5.6
    DOCKER_KERNEL_CURRENT_VERSION=$(uname -r | cut -c1-3)
    if (($(echo "$KERNEL_CURRENT_VERSION >= $KERNEL_VERSION_LIMIT" | bc -l))); then
      echo "Correct: Kernel version, $KERNEL_CURRENT_VERSION" >/dev/null 2>&1
    else
      echo "Error: Kernel version $DOCKER_KERNEL_CURRENT_VERSION please update to $DOCKER_KERNEL_VERSION_LIMIT" >&2
      exit
    fi
  fi
}

# Docker Check
docker-check

# Lets check the kernel version
function kernel-check() {
  KERNEL_VERSION_LIMIT=3.1
  KERNEL_CURRENT_VERSION=$(uname -r | cut -c1-3)
  if (($(echo "$KERNEL_CURRENT_VERSION >= $KERNEL_VERSION_LIMIT" | bc -l))); then
    echo "Correct: Kernel version, $KERNEL_CURRENT_VERSION" >/dev/null 2>&1
  else
    echo "Error: Kernel version $KERNEL_CURRENT_VERSION please update to $KERNEL_VERSION_LIMIT" >&2
    exit
  fi
}

# Kernel Version
kernel-check

# Wireguard Public Network Interface
WIREGUARD_PUB_NIC="wg0"
WG_CONFIG="/etc/wireguard/$WIREGUARD_PUB_NIC.conf"
if [ ! -f "$WG_CONFIG" ]; then

  # Lets check the kernel version and check if headers are required
  function install-kernel-headers() {
    KERNEL_VERSION_LIMIT=5.6
    KERNEL_CURRENT_VERSION=$(uname -r | cut -c1-3)
    if (($(echo "$KERNEL_CURRENT_VERSION <= $KERNEL_VERSION_LIMIT" | bc -l))); then
      if { [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "pop" ] || [ "$DISTRO" == "kali" ]; }; then
        apt-get update
        apt-get install linux-headers-"$(uname -r)" -y
      elif [ "$DISTRO" == "raspbian" ]; then
        apt-get update
        apt-get install raspberrypi-kernel-headers -y
      elif { [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ]; }; then
        pacman -Syu
        pacman -Syu --noconfirm linux-headers
      elif [ "$DISTRO" == "fedora" ]; then
        dnf update -y
        dnf install kernel-headers-"$(uname -r)" kernel-devel-"$(uname -r)" -y
      elif { [ "$DISTRO" == "centos" ] || [ "$DISTRO" == "rhel" ]; }; then
        yum update -y
        yum install kernel-headers-"$(uname -r)" kernel-devel-"$(uname -r)" -y
      fi
    else
      echo "Correct: You do not need kernel headers." >/dev/null 2>&1
    fi
  }

  # Kernel Version
  install-kernel-headers

  # Install WireGuard Server
  function install-wireguard-server() {
    if ! [ -x "$(command -v wg)" ]; then
      if [ "$DISTRO" == "ubuntu" ] && { [ "$DISTRO_VERSION" == "20.10" ] || [ "$DISTRO_VERSION" == "20.04" ] || [ "$DISTRO_VERSION" == "19.10" ]; }; then
        apt-get update
        apt-get install wireguard qrencode haveged ifupdown resolvconf -y
      elif [ "$DISTRO" == "ubuntu" ] && { [ "$DISTRO_VERSION" == "16.04" ] || [ "$DISTRO_VERSION" == "18.04" ]; }; then
        apt-get update
        apt-get install software-properties-common -y
        add-apt-repository ppa:wireguard/wireguard -y
        apt-get update
        apt-get install wireguard qrencode haveged ifupdown resolvconf -y
      elif [ "$DISTRO" == "pop" ]; then
        apt-get update
        apt-get install wireguard qrencode haveged ifupdown resolvconf -y
      elif { [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "kali" ]; }; then
        apt-get update
        if [ ! -f "/etc/apt/sources.list.d/unstable.list" ]; then
          echo "deb http://deb.debian.org/debian/ unstable main" >>/etc/apt/sources.list.d/unstable.list
        fi
        if [ ! -f "/etc/apt/preferences.d/limit-unstable" ]; then
          printf "Package: *\nPin: release a=unstable\nPin-Priority: 90\n" >>/etc/apt/preferences.d/limit-unstable
        fi
        apt-get update
        apt-get install wireguard qrencode haveged ifupdown resolvconf -y
      elif [ "$DISTRO" == "raspbian" ]; then
        apt-get update
        apt-get install dirmngr -y
        apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 04EE7237B7D453EC
        if [ ! -f "/etc/apt/sources.list.d/unstable.list" ]; then
          echo "deb http://deb.debian.org/debian/ unstable main" >>/etc/apt/sources.list.d/unstable.list
        fi
        if [ ! -f "/etc/apt/preferences.d/limit-unstable" ]; then
          printf "Package: *\nPin: release a=unstable\nPin-Priority: 90\n" >>/etc/apt/preferences.d/limit-unstable
        fi
        apt-get update
        apt-get install wireguard qrencode haveged ifupdown resolvconf -y
      elif { [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ]; }; then
        pacman -Syu
        pacman -Syu --noconfirm haveged qrencode iptables resolvconf
        pacman -Syu --noconfirm wireguard-tools
      elif [ "$DISTRO" = "fedora" ] && [ "$DISTRO_VERSION" == "32" ]; then
        dnf update -y
        dnf install qrencode wireguard-tools haveged resolvconf -y
      elif [ "$DISTRO" = "fedora" ] && { [ "$DISTRO_VERSION" == "30" ] || [ "$DISTRO_VERSION" == "31" ]; }; then
        dnf update -y
        dnf copr enable jdoss/wireguard -y
        dnf install qrencode wireguard-dkms wireguard-tools haveged resolvconf -y
      elif [ "$DISTRO" == "centos" ] && { [ "$DISTRO_VERSION" == "8" ] || [ "$DISTRO_VERSION" == "8.1" ]; }; then
        yum update -y
        yum config-manager --set-enabled PowerTools
        yum copr enable jdoss/wireguard -y
        yum install wireguard-dkms wireguard-tools qrencode haveged resolvconf -y
      elif [ "$DISTRO" == "centos" ] && [ "$DISTRO_VERSION" == "7" ]; then
        yum update -y
        if [ ! -f "/etc/yum.repos.d/wireguard.repo" ]; then
          curl https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo --create-dirs -o /etc/yum.repos.d/wireguard.repo
        fi
        yum update -y
        yum install wireguard-dkms wireguard-tools qrencode haveged resolvconf -y
      elif [ "$DISTRO" == "rhel" ] && [ "$DISTRO_VERSION" == "8" ]; then
        yum update -y
        yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm
        yum update -y
        subscription-manager repos --enable codeready-builder-for-rhel-8-"$(arch)"-rpms
        yum copr enable jdoss/wireguard
        yum install wireguard-dkms wireguard-tools qrencode haveged resolvconf -y
      elif [ "$DISTRO" == "rhel" ] && [ "$DISTRO_VERSION" == "7" ]; then
        yum update -y
        if [ ! -f "/etc/yum.repos.d/wireguard.repo" ]; then
          curl https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo --create-dirs -o /etc/yum.repos.d/wireguard.repo
        fi
        yum update -y
        yum install wireguard-dkms wireguard-tools qrencode haveged resolvconf -y
      fi
      echo "WireGuard: true" >>/etc/wireguard/wireguard-manager
    fi
  }

  # Install WireGuard Server
  install-wireguard-server

  echo "Move the files to /etc/wireguard/$WIREGUARD_PUB_NIC.conf"

  echo "if pgrep systemd-journal; then
      systemctl enable wg-quick@$WIREGUARD_PUB_NIC
      systemctl restart wg-quick@$WIREGUARD_PUB_NIC
    else
      service wg-quick@$WIREGUARD_PUB_NIC enable
      service wg-quick@$WIREGUARD_PUB_NIC restart
    fi"

else

  function take-user-input() {
    echo "What do you want to do?"
    echo "   1) Show WireGuard Interface"
    echo "   2) Start WireGuard Interface"
    echo "   3) Stop WireGuard Interface"
    echo "   4) Restart WireGuard Interface"
    echo "   5) Reinstall WireGuard Interface"
    echo "   6) Uninstall WireGuard Interface"
    echo "   7) Update this script"
    until [[ "$USER_OPTIONS" =~ ^[1-9]$ ]]; do
      read -rp "Select an option [1-9]: " -e -i 1 USER_OPTIONS
    done
    case $USER_OPTIONS in
    1)
      wg show
      ;;
    2)
      if pgrep systemd-journal; then
        systemctl enable wg-quick@$WIREGUARD_PUB_NIC
        systemctl start wg-quick@$WIREGUARD_PUB_NIC
      else
        service wg-quick@$WIREGUARD_PUB_NIC enable
        service wg-quick@$WIREGUARD_PUB_NIC start
      fi
      ;;
    3)
      if pgrep systemd-journal; then
        systemctl disable wg-quick@$WIREGUARD_PUB_NIC
        systemctl stop wg-quick@$WIREGUARD_PUB_NIC
      else
        service wg-quick@$WIREGUARD_PUB_NIC disable
        service wg-quick@$WIREGUARD_PUB_NIC stop
      fi
      ;;
    4)
      if pgrep systemd-journal; then
        systemctl restart wg-quick@$WIREGUARD_PUB_NIC
      else
        service wg-quick@$WIREGUARD_PUB_NIC restart
      fi
      ;;
    5)
      if { [ "$DISTRO" == "ubuntu" ] || [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "raspbian" ] || [ "$DISTRO" == "pop" ] || [ "$DISTRO" == "kali" ]; }; then
        dpkg-reconfigure wireguard-dkms
        modprobe wireguard
        systemctl restart wg-quick@$WIREGUARD_PUB_NIC
      elif { [ "$DISTRO" == "fedora" ] || [ "$DISTRO" == "centos" ] || [ "$DISTRO" == "rhel" ]; }; then
        yum reinstall wireguard-dkms -y
        service wg-quick@$WIREGUARD_PUB_NIC restart
      elif { [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ]; }; then
        pacman -Rs --noconfirm wireguard-tools
        service wg-quick@$WIREGUARD_PUB_NIC restart
      fi
      ;;
    6)
      # Uninstall Wireguard and purging files
      if [ -f "/etc/wireguard/wireguard-manager" ]; then
        if pgrep systemd-journal; then
          systemctl disable wg-quick@$WIREGUARD_PUB_NIC
          wg-quick down $WIREGUARD_PUB_NIC
        else
          service wg-quick@$WIREGUARD_PUB_NIC disable
          wg-quick down $WIREGUARD_PUB_NIC
        fi
        # Removing Wireguard Files
        rm -rf /etc/wireguard
        rm -rf /etc/wireguard/clients
        rm -f /etc/wireguard/$WIREGUARD_PUB_NIC.conf
        rm -f /etc/sysctl.d/wireguard.conf
        if [ "$DISTRO" == "centos" ]; then
          yum remove wireguard qrencode haveged -y
        elif { [ "$DISTRO" == "debian" ] || [ "$DISTRO" == "kali" ]; }; then
          apt-get remove --purge wireguard qrencode -y
          rm -f /etc/apt/sources.list.d/unstable.list
          rm -f /etc/apt/preferences.d/limit-unstable
        elif [ "$DISTRO" == "pop" ]; then
          apt-get remove --purge wireguard qrencode haveged -y
        elif [ "$DISTRO" == "ubuntu" ]; then
          apt-get remove --purge wireguard qrencode haveged -y
          if pgrep systemd-journal; then
            systemctl enable systemd-resolved
            systemctl restart systemd-resolved
          else
            service systemd-resolved enable
            service systemd-resolved restart
          fi
        elif [ "$DISTRO" == "raspbian" ]; then
          apt-key del 04EE7237B7D453EC
          apt-get remove --purge wireguard qrencode haveged dirmngr -y
          rm -f /etc/apt/sources.list.d/unstable.list
          rm -f /etc/apt/preferences.d/limit-unstable
        elif { [ "$DISTRO" == "arch" ] || [ "$DISTRO" == "manjaro" ]; }; then
          pacman -Rs wireguard qrencode haveged -y
        elif [ "$DISTRO" == "fedora" ]; then
          dnf remove wireguard qrencode haveged -y
          rm -f /etc/yum.repos.d/wireguard.repo
        elif [ "$DISTRO" == "rhel" ]; then
          yum remove wireguard qrencode haveged -y
          rm -f /etc/yum.repos.d/wireguard.repo
        fi
      fi
      ;;
    7) # Update the script
      CURRENT_FILE_PATH="$(realpath "$0")"
      curl -o "$CURRENT_FILE_PATH" https://raw.githubusercontent.com/complexorganizations/wireguard-manager/main/wireguard-client.sh
      chmod +x "$CURRENT_FILE_PATH" || exit
      ;;
    8) # Backup Wireguard Config
      if [ ! -f "/etc/wireguard" ]; then
        rm -f /var/backups/wireguard-manager.zip
        zip -r -j /var/backups/wireguard-manager.zip /etc/wireguard/"$WIREGUARD_PUB_NIC".conf /etc/wireguard/wireguard-manager
      fi
      ;;
    9) # Restore Wireguard Config
      if [ -f "/var/backups/wireguard-manager.zip" ]; then
        rm -rf /etc/wireguard/
        unzip /var/backups/wireguard-manager.zip -d /etc/wireguard/
      else
        exit
      fi
      # Restart Wireguard
      if pgrep systemd-journal; then
        systemctl restart wg-quick@$WIREGUARD_PUB_NIC
      else
        service wg-quick@$WIREGUARD_PUB_NIC restart
      fi
      ;;
    esac
  }

  # run the function
  take-user-input

fi
