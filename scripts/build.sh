#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "usage: $0 [base|manual|all]" >&2
}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

build_base() {
  docker build -f app/Dockerfile.base -t localhost:5001/nestjs-dd-base:latest .
  docker push localhost:5001/nestjs-dd-base:latest
}

build_manual() {
  docker build -f manual-instrumentation/Dockerfile -t localhost:5001/nestjs-dd-manual:latest .
  docker push localhost:5001/nestjs-dd-manual:latest
}

need docker

target="${1:-all}"
case "$target" in
  base)
    build_base
    ;;
  manual)
    build_manual
    ;;
  all)
    build_base
    build_manual
    ;;
  *)
    usage
    exit 1
    ;;
esac
