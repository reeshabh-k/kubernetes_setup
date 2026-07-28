#!/bin/bash

~/proxy.sh &
sleep 2

set -e

if [ "$EUID" -ne 0 ]; then
    exit 1
fi

PROXY="http://10.10.78.61:3128"

cat <<EOF >> /etc/environment

http_proxy=$PROXY
https_proxy=$PROXY
ftp_proxy=$PROXY

HTTP_PROXY=$PROXY
HTTPS_PROXY=$PROXY
FTP_PROXY=$PROXY

EOF

cat <<EOF > /etc/apt/apt.conf.d/95proxies

Acquire::http::Proxy "$PROXY";
Acquire::https::Proxy "$PROXY";

EOF

apt update

apt install -y \
curl \
ca-certificates \
gnupg \
apt-transport-https

mkdir -p /etc/apt/keyrings

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key \
| gpg --dearmor \
-o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

cat <<EOF > /etc/apt/sources.list.d/kubernetes.list

deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /

EOF

apt update

apt install -y \
kubelet \
kubeadm \
kubectl

apt-mark hold kubelet kubeadm kubectl

mkdir -p /etc/systemd/system/containerd.service.d

cat <<EOF > /etc/systemd/system/containerd.service.d/http-proxy.conf

[Service]
Environment="HTTP_PROXY=$PROXY"
Environment="HTTPS_PROXY=$PROXY"
Environment="FTP_PROXY=$PROXY"
Environment="NO_PROXY=localhost,127.0.0.1,10.96.0.0/12,10.244.0.0/16"

EOF

mkdir -p /etc/systemd/system/kubelet.service.d

cat <<EOF > /etc/systemd/system/kubelet.service.d/http-proxy.conf

[Service]
Environment="HTTP_PROXY=$PROXY"
Environment="HTTPS_PROXY=$PROXY"
Environment="FTP_PROXY=$PROXY"
Environment="NO_PROXY=localhost,127.0.0.1,10.96.0.0/12,10.244.0.0/16"

EOF

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

mkdir -p /etc/profile.d

cat <<EOF > /etc/profile.d/helm-proxy.sh

export http_proxy=$PROXY
export https_proxy=$PROXY
export ftp_proxy=$PROXY

export HTTP_PROXY=$PROXY
export HTTPS_PROXY=$PROXY
export FTP_PROXY=$PROXY

EOF

chmod +x /etc/profile.d/helm-proxy.sh

systemctl daemon-reload

systemctl restart containerd

systemctl enable containerd

systemctl enable kubelet
