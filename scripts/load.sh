#!/usr/bin/env bash
set -euo pipefail

. scripts/env.sh
load_env

usage() {
  echo "usage: $0 manual|auto" >&2
}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

need kubectl
need k6

variant="${1:-}"
case "$variant" in
  manual)
    ns="nestjs-manual"
    svc="nestjs-manual"
    port="${LOAD_PORT:-3001}"
    ;;
  auto)
    ns="nestjs-auto"
    svc="nestjs-auto"
    port="${LOAD_PORT:-3002}"
    ;;
  *)
    usage
    exit 1
    ;;
esac

log="/tmp/dd-nest-lab-${variant}-port-forward.log"
kubectl -n "$ns" port-forward "svc/${svc}" "${port}:3000" >"$log" 2>&1 &
pf_pid="$!"
trap 'kill "$pf_pid" >/dev/null 2>&1 || true' EXIT

sleep 3
if ! kill -0 "$pf_pid" >/dev/null 2>&1; then
  echo "port-forward failed; see $log" >&2
  exit 1
fi

TARGET_URL="http://127.0.0.1:${port}" k6 run load-testing/k6-script.js
