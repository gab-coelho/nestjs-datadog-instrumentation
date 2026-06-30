#!/usr/bin/env bash
set -euo pipefail

. scripts/env.sh
load_env

ns="${DATADOG_NAMESPACE:-datadog}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

need helm
need kubectl

cat <<'EOF'
Datadog keys must stay outside Git. You can put them in local .env:
  DD_API_KEY=...
  DD_APP_KEY=... # optional for this lab

Or create the Kubernetes secret manually:
  kubectl create namespace datadog --dry-run=client -o yaml | kubectl apply -f -
  kubectl create secret generic datadog-secret --from-literal api-key="$DD_API_KEY" -n datadog
EOF

kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -

if [ -n "${DD_API_KEY:-}" ]; then
  if [ -n "${DD_APP_KEY:-}" ]; then
    kubectl create secret generic datadog-secret \
      --from-literal "api-key=${DD_API_KEY}" \
      --from-literal "app-key=${DD_APP_KEY}" \
      -n "$ns" \
      --dry-run=client -o yaml | kubectl apply -f -
  else
    kubectl create secret generic datadog-secret \
      --from-literal "api-key=${DD_API_KEY}" \
      -n "$ns" \
      --dry-run=client -o yaml | kubectl apply -f -
  fi
elif ! kubectl get secret datadog-secret -n "$ns" >/dev/null 2>&1; then
  echo "missing '$ns/datadog-secret' and DD_API_KEY is not set in the environment or .env" >&2
  exit 1
fi

helm repo add datadog https://helm.datadoghq.com >/dev/null
helm repo update datadog >/dev/null
helm upgrade --install datadog-operator datadog/datadog-operator \
  --namespace "$ns" \
  --values datadog/operator/values.yaml

kubectl wait --for=condition=Established crd/datadogagents.datadoghq.com --timeout=120s
kubectl apply -f datadog/agents/datadog-agent.yaml

echo "Datadog Operator and DatadogAgent resources applied"
