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

version() {
  if [ -n "${DD_VERSION:-}" ]; then
    echo "$DD_VERSION"
  elif command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git rev-parse --short HEAD
  else
    echo "0.0.1"
  fi
}

tag_deployment() {
  ns="$1"
  name="$2"
  ver="$3"

  kubectl patch deployment "$name" -n "$ns" --type merge -p \
    "{\"metadata\":{\"labels\":{\"tags.datadoghq.com/version\":\"${ver}\"}},\"spec\":{\"template\":{\"metadata\":{\"labels\":{\"tags.datadoghq.com/version\":\"${ver}\"}}}}}"
}

deploy_manual() {
  ver="$(version)"
  kubectl apply -f manual-instrumentation/k8s/namespace.yaml
  kubectl apply -f manual-instrumentation/k8s/configmap.yaml
  kubectl apply -f manual-instrumentation/k8s/service.yaml
  kubectl apply -f manual-instrumentation/k8s/deployment.yaml
  tag_deployment nestjs-manual nestjs-manual "$ver"
  kubectl set env deployment/nestjs-manual -n nestjs-manual "DD_VERSION=${ver}"
  kubectl rollout status deployment/nestjs-manual -n nestjs-manual --timeout=180s
}

deploy_auto() {
  ver="$(version)"
  kubectl apply -f ssi-instrumentation/k8s/namespace.yaml
  kubectl apply -f ssi-instrumentation/k8s/service.yaml
  kubectl apply -f ssi-instrumentation/k8s/deployment.yaml
  tag_deployment nestjs-auto nestjs-auto "$ver"
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
