#!/usr/bin/env bash
set -euo pipefail

cluster="${KIND_CLUSTER_NAME:-dd-nest-lab}"
registry="${KIND_REGISTRY_NAME:-kind-registry}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

need docker
need kind
need kubectl

if kubectl cluster-info >/dev/null 2>&1; then
  helm uninstall datadog-operator -n datadog >/dev/null 2>&1 || true
  kubectl delete datadogagent datadog -n datadog --ignore-not-found=true >/dev/null 2>&1 || true
  kubectl delete namespace nestjs-manual nestjs-auto datadog --ignore-not-found=true >/dev/null 2>&1 || true
fi

if kind get clusters | grep -qx "$cluster"; then
  kind delete cluster --name "$cluster"
fi

if docker inspect "$registry" >/dev/null 2>&1; then
  docker rm -f "$registry" >/dev/null
fi

echo "lab resources removed"
