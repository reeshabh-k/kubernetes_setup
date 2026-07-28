#!/bin/bash

../proxy.sh &

set -e

###########################################
# Check root
###########################################

if [ "$EUID" -ne 0 ]; then
    echo "Please run with sudo:"
    echo "sudo ./phase2_prepare_node.sh"
    exit 1
fi


###########################################
# Update Ubuntu
###########################################

echo
echo "========================================"
echo "Updating Ubuntu"
echo "========================================"

apt update

apt upgrade -y


###########################################
# Disable Swap
###########################################

echo
echo "========================================"
echo "Disabling Swap"
echo "========================================"

swapoff -a


# Disable swap permanently after reboot

sed -i '/\sswap\s/s/^/#/' /etc/fstab


echo "Swap disabled."


###########################################
# Load Kernel Modules
###########################################

echo
echo "========================================"
echo "Loading Kernel Modules"
echo "========================================"


cat <<EOF > /etc/modules-load.d/kubernetes.conf
overlay
br_netfilter
EOF


modprobe overlay
modprobe br_netfilter


echo "Kernel modules loaded."


###########################################
# Kubernetes Network Settings
###########################################

echo
echo "========================================"
echo "Configuring Network Settings"
echo "========================================"


cat <<EOF > /etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward = 1
EOF


sysctl --system


echo "Network configuration applied."


###########################################
# Install Required Packages
###########################################

echo
echo "========================================"
echo "Installing Required Packages"
echo "========================================"


apt install -y \
curl \
wget \
ca-certificates \
gnupg \
apt-transport-https \
software-properties-common


###########################################
# Install Containerd
###########################################

echo
echo "========================================"
echo "Installing Containerd"
echo "========================================"


apt install -y containerd


###########################################
# Configure Containerd
###########################################

echo
echo "========================================"
echo "Configuring Containerd"
echo "========================================"


mkdir -p /etc/containerd


containerd config default > /etc/containerd/config.toml


sed -i \
's/SystemdCgroup = false/SystemdCgroup = true/' \
/etc/containerd/config.toml


systemctl restart containerd

systemctl enable containerd


###########################################
# Verification
###########################################

echo
echo "========================================"
echo "Verification"
echo "========================================"


echo
echo "Swap:"
swapon --show


echo
echo "Containerd:"
systemctl status containerd --no-pager


echo
echo "Kernel Modules:"
lsmod | grep -E "overlay|br_netfilter"


echo
echo "========================================"
echo "Phase 2 Complete"
echo "========================================"

echo
echo "Node is ready for Kubernetes installation."
