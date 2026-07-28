#!/bin/bash

../proxy.sh & 

set -e


###########################################
# Root check
###########################################

if [ "$EUID" -ne 0 ]; then
    echo "Run with sudo:"
    echo "sudo ./phase3_install_kubernetes.sh"
    exit 1
fi


###########################################
# Proxy Configuration
###########################################

echo
echo "========================================"
echo "Configuring IITD Proxy"
echo "========================================"


PROXY="http://10.10.78.61:3128"


###########################################
# System environment proxy
###########################################

cat <<EOF >> /etc/environment

http_proxy=$PROXY
https_proxy=$PROXY
ftp_proxy=$PROXY

HTTP_PROXY=$PROXY
HTTPS_PROXY=$PROXY
FTP_PROXY=$PROXY

EOF


echo "Global proxy configured."


###########################################
# Apt proxy
###########################################

echo
echo "Configuring APT proxy"


cat <<EOF > /etc/apt/apt.conf.d/95proxies

Acquire::http::Proxy "$PROXY";
Acquire::https::Proxy "$PROXY";

EOF


echo "APT proxy configured."


###########################################
# Update packages
###########################################

echo
echo "========================================"
echo "Updating Packages"
echo "========================================"


###########################################
# Install dependencies
###########################################

echo
echo "========================================"
echo "Installing Kubernetes Dependencies"
echo "========================================"


apt install -y \
curl \
ca-certificates \
gnupg \
apt-transport-https


###########################################
# Add Kubernetes Repository Key
###########################################

echo
echo "Adding Kubernetes repository key"


curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key \
| gpg --dearmor \
-o /etc/apt/keyrings/kubernetes-apt-keyring.gpg


###########################################
# Add Kubernetes Repository
###########################################

echo
echo "Adding Kubernetes repository"


mkdir -p /etc/apt/keyrings


cat <<EOF > /etc/apt/sources.list.d/kubernetes.list

deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /

EOF


###########################################
# Install Kubernetes
###########################################

echo
echo "========================================"
echo "Installing Kubernetes"
echo "========================================"




apt install -y \
kubelet \
kubeadm \
kubectl


###########################################
# Hold Kubernetes versions
###########################################

apt-mark hold kubelet kubeadm kubectl


###########################################
# Configure containerd proxy
###########################################

echo
echo "========================================"
echo "Configuring Containerd Proxy"
echo "========================================"


mkdir -p /etc/systemd/system/containerd.service.d


cat <<EOF > /etc/systemd/system/containerd.service.d/http-proxy.conf

[Service]
Environment="HTTP_PROXY=$PROXY"
Environment="HTTPS_PROXY=$PROXY"
Environment="FTP_PROXY=$PROXY"
Environment="NO_PROXY=localhost,127.0.0.1,10.96.0.0/12,10.244.0.0/16"

EOF


###########################################
# Configure kubelet proxy
###########################################

echo
echo "========================================"
echo "Configuring Kubelet Proxy"
echo "========================================"


mkdir -p /etc/systemd/system/kubelet.service.d


cat <<EOF > /etc/systemd/system/kubelet.service.d/http-proxy.conf

[Service]
Environment="HTTP_PROXY=$PROXY"
Environment="HTTPS_PROXY=$PROXY"
Environment="FTP_PROXY=$PROXY"
Environment="NO_PROXY=localhost,127.0.0.1,10.96.0.0/12,10.244.0.0/16"

EOF


###########################################
# Download Helm
###########################################

echo
echo "========================================"
echo "Installing Helm"
echo "========================================"


HELM_VERSION="v4.2.3"


TMP_DIR=$(mktemp -d)


cd "$TMP_DIR"


curl -fsSL \
"https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" \
-o helm.tar.gz


tar -zxvf helm.tar.gz


install linux-amd64/helm /usr/local/bin/helm


cd /


rm -rf "$TMP_DIR"


###########################################
# Verify Helm
###########################################

echo
echo "========================================"
echo "Checking Helm Installation"
echo "========================================"


helm version


###########################################
# Configure Helm Environment
###########################################

echo
echo "========================================"
echo "Helm Proxy Configuration"
echo "========================================"


mkdir -p /etc/systemd/system


cat <<EOF > /etc/profile.d/helm-proxy.sh

export http_proxy=$PROXY
export https_proxy=$PROXY
export ftp_proxy=$PROXY

export HTTP_PROXY=$PROXY
export HTTPS_PROXY=$PROXY
export FTP_PROXY=$PROXY

EOF


chmod +x /etc/profile.d/helm-proxy.sh


###########################################
# Final Check
###########################################

echo
echo "========================================"
echo "Helm Installation Complete"
echo "========================================"


echo
echo "Helm binary:"
which helm


echo
echo "Helm version:"
helm version


echo
echo "Next step:"
echo "After Kubernetes is running, add Helm repositories:"
echo
echo "helm repo add <name> <url>"
echo "helm repo update"


###########################################
# Reload systemd
###########################################

echo
echo "Reloading system services"


systemctl daemon-reload


systemctl restart containerd

systemctl enable containerd


systemctl enable kubelet


###########################################
# Verification
###########################################

echo
echo "========================================"
echo "Verification"
echo "========================================"


echo
echo "Kubernetes versions:"

kubectl version --client

kubeadm version


echo
echo "Containerd status:"

systemctl status containerd --no-pager


echo
echo "Proxy configuration:"

echo $HTTP_PROXY


echo
echo "========================================"
echo "Phase 3 Complete"
echo "========================================"

echo
echo "Node is ready for kubeadm."
