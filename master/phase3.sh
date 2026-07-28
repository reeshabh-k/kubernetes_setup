#!/bin/bash

~/proxy.sh &
sleep 2

set -e

FLINK_OPERATOR_VERSION="1.13.0"

helm repo add minio https://charts.min.io/
helm repo add flink-operator-repo https://downloads.apache.org/flink/flink-kubernetes-operator-$FLINK_OPERATOR_VERSION/

helm repo update

helm install minio minio/minio \
--namespace minio --create-namespace \
-f "$(dirname "$0")/minio-values.yaml"

helm install flink-kubernetes-operator flink-operator-repo/flink-kubernetes-operator \
--namespace flink --create-namespace

kubectl wait --for=condition=Available \
--namespace flink deployment/flink-kubernetes-operator \
--timeout=180s

kubectl apply -f "$(dirname "$0")/flink-deployment.yaml"
