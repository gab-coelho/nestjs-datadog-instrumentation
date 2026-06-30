#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 manual|auto|all" >&2
}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

deploy_manual() {
  kubectl apply -f manual-instrumentation/k8s/namespace.yaml
  kubectl apply -f manual-instrumentation/k8s/configmap.yaml
  kubectl apply -f manual-instrumentation/k8s/service.yaml
  kubectl apply -f manual-instrumentation/k8s/deployment.yaml
  kubectl rollout status deployment/nestjs-manual -n nestjs-manual --timeout=180s
}

deploy_auto() {
  kubectl apply -f ssi-instrumentation/k8s/namespace.yaml
  kubectl apply -f ssi-instrumentation/k8s/service.yaml
  kubectl apply -f ssi-instrumentation/k8s/deployment.yaml
  kubectl rollout status deployment/nestjs-auto -n nestjs-auto --timeout=180s
}

need kubectl

target="${1:-}"
case "$target" in
  manual)
    deploy_manual
    ;;
  auto)
    deploy_auto
    ;;
  all)
    deploy_manual
    deploy_auto
    ;;
  *)
    usage
    exit 1
    ;;
esac
