#!/bin/bash 


../proxy.sh &

set -e


#############################################
# CHECK ROOT
#############################################

if [ "$EUID" -ne 0 ]; then
    echo "Run with sudo:"
    echo "sudo bash cluster_prepare_all.sh"
    exit 1
fi


#############################################
# VARIABLES
#############################################

PROXY="http://10.10.78.61:3128"

WORKDIR="/opt/cluster-downloads"


#############################################
# PHASE 1
# DOWNLOAD SOFTWARE
#############################################

echo "================================="
echo "PHASE 1: Download Software"
echo "================================="


mkdir -p $WORKDIR
cd $WORKDIR





wget -nc \
https://downloads.apache.org/hadoop/common/hadoop-3.4.2/hadoop-3.4.2.tar.gz


echo "Downloading Flink"


wget -nc \
https://downloads.apache.org/flink/flink-2.1.0/flink-2.1.0-bin-scala_2.12.tgz


echo "Downloading MinIO"


wget -nc \
https://dl.min.io/server/minio/release/linux-amd64/minio


chmod +x minio


echo "Downloading MinIO client"


wget -nc \
https://dl.min.io/client/mc/release/linux-amd64/mc


chmod +x mc



#############################################
# PHASE 2
# UBUNTU PREPARATION
#############################################

echo "================================="
echo "PHASE 2: Ubuntu Preparation"
echo "================================="


echo "Disabling swap"


swapoff -a


sed -i '/ swap / s/^/#/' /etc/fstab



echo "Loading kernel modules"


cat <<EOF >/etc/modules-load.d/kubernetes.conf
overlay
br_netfilter
EOF


modprobe overlay
modprobe br_netfilter



echo "Setting kernel parameters"


cat <<EOF >/etc/sysctl.d/kubernetes.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF


sysctl --system



#############################################
# INSTALL CONTAINERD
#############################################

echo "Installing containerd"


apt install -y containerd


mkdir -p /etc/containerd


containerd config default \
>/etc/containerd/config.toml



echo "Using systemd cgroups"


sed -i \
's/SystemdCgroup = false/SystemdCgroup = true/' \
/etc/containerd/config.toml



systemctl restart containerd

systemctl enable containerd



#############################################
# PHASE 3
# PROXY + KUBERNETES
#############################################

echo "================================="
echo "PHASE 3: Kubernetes Installation"
echo "================================="



#############################################
# GLOBAL PROXY
#############################################


cat <<EOF >/etc/profile.d/proxy.sh

export http_proxy=$PROXY
export https_proxy=$PROXY
export ftp_proxy=$PROXY

export HTTP_PROXY=$PROXY
export HTTPS_PROXY=$PROXY
export FTP_PROXY=$PROXY

EOF


chmod +x /etc/profile.d/proxy.sh



cat <<EOF >>/etc/environment

http_proxy=$PROXY
https_proxy=$PROXY
ftp_proxy=$PROXY

HTTP_PROXY=$PROXY
HTTPS_PROXY=$PROXY
FTP_PROXY=$PROXY

EOF



#############################################
# APT PROXY
#############################################


cat <<EOF >/etc/apt/apt.conf.d/95proxy

Acquire::http::Proxy "$PROXY";
Acquire::https::Proxy "$PROXY";

EOF



export http_proxy=$PROXY
export https_proxy=$PROXY



#############################################
# INSTALL KUBERNETES PACKAGES
#############################################


apt update


apt install -y \
curl \
ca-certificates \
apt-transport-https \
gpg



mkdir -p /etc/apt/keyrings



curl -fsSL \
https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key \
| gpg --dearmor \
-o /etc/apt/keyrings/kubernetes.gpg



cat <<EOF >/etc/apt/sources.list.d/kubernetes.list

deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /

EOF



apt update


apt install -y \
kubeadm \
kubelet \
kubectl



apt-mark hold kubeadm kubelet kubectl



#############################################
# CONTAINERD PROXY
#############################################


mkdir -p \
/etc/systemd/system/containerd.service.d



cat <<EOF >/etc/systemd/system/containerd.service.d/proxy.conf

[Service]
Environment="HTTP_PROXY=$PROXY"
Environment="HTTPS_PROXY=$PROXY"
Environment="NO_PROXY=localhost,127.0.0.1,10.96.0.0/12,10.244.0.0/16"

EOF



#############################################
# KUBELET PROXY
#############################################


mkdir -p \
/etc/systemd/system/kubelet.service.d



cat <<EOF >/etc/systemd/system/kubelet.service.d/proxy.conf

[Service]
Environment="HTTP_PROXY=$PROXY"
Environment="HTTPS_PROXY=$PROXY"
Environment="NO_PROXY=localhost,127.0.0.1,10.96.0.0/12,10.244.0.0/16"

EOF



systemctl daemon-reload


systemctl restart containerd


systemctl restart kubelet



#############################################
# INSTALL HELM
#############################################


echo "Installing Helm"


HELM_VERSION="v3.17.1"


cd /tmp


wget -nc \
https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz


tar -zxvf helm-${HELM_VERSION}-linux-amd64.tar.gz



install linux-amd64/helm \
/usr/local/bin/helm



#############################################
# TESTS
#############################################


echo
echo "================================="
echo "INSTALLATION COMPLETE"
echo "================================="


echo
echo "Versions:"
echo


containerd --version

kubeadm version

kubectl version --client

helm version


echo
echo "Next steps:"
echo
echo "MASTER ONLY:"
echo "sudo kubeadm init --kubernetes-version=v1.33.13 --pod-network-cidr=192.168.0.0/16"
echo
echo "WORKERS:"
echo "Run kubeadm join command generated by master"
