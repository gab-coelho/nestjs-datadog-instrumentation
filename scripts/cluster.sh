#!/usr/bin/env bash
set -euo pipefail

cluster="${KIND_CLUSTER_NAME:-dd-nest-lab}"
registry="${KIND_REGISTRY_NAME:-kind-registry}"
port="${KIND_REGISTRY_PORT:-5001}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

need docker
need kind
need kubectl

if ! docker inspect "$registry" >/dev/null 2>&1; then
  docker run -d --restart=always -p "127.0.0.1:${port}:5000" --name "$registry" registry:2 >/dev/null
fi

tmp="$(mktemp)"
cat >"$tmp" <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
  - |-
    [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:${port}"]
      endpoint = ["http://${registry}:5000"]
nodes:
  - role: control-plane
  - role: worker
EOF

if ! kind get clusters | grep -qx "$cluster"; then
  kind create cluster --name "$cluster" --config "$tmp"
fi
rm -f "$tmp"

if ! docker network inspect kind --format '{{json .Containers}}' | grep -q "\"${registry}\""; then
  docker network connect kind "$registry" || true
fi

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: local-registry-hosting
  namespace: kube-public
data:
  localRegistryHosting.v1: |
    host: "localhost:${port}"
    help: "https://kind.sigs.k8s.io/docs/user/local-registry/"
EOF

echo "kind cluster '$cluster' is ready with registry localhost:${port}"
