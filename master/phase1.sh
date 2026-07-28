#!/bin/bash

PROXY_SCRIPT="${SUDO_USER:+/home/$SUDO_USER/proxy.sh}"
PROXY_SCRIPT="${PROXY_SCRIPT:-$HOME/proxy.sh}"

"$PROXY_SCRIPT" &
sleep 2

set -e

if [ "$EUID" -ne 0 ]; then
    exit 1
fi

apt update

apt upgrade -y

swapoff -a

sed -i '/\sswap\s/s/^/#/' /etc/fstab

cat <<EOF > /etc/modules-load.d/kubernetes.conf
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter

cat <<EOF > /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF

sysctl --system

apt install -y \
curl \
wget \
ca-certificates \
gnupg \
apt-transport-https \
software-properties-common

apt install -y containerd

mkdir -p /etc/containerd

containerd config default > /etc/containerd/config.toml

sed -i \
's/SystemdCgroup = false/SystemdCgroup = true/' \
/etc/containerd/config.toml

systemctl restart containerd

systemctl enable containerd
