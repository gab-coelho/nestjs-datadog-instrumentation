#!/usr/bin/env bash
set -euo pipefail

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
Datadog API key secret must be created outside this repo, for example:
  kubectl create namespace datadog --dry-run=client -o yaml | kubectl apply -f -
  kubectl create secret generic datadog-secret \
    --from-literal api-key="$DD_API_KEY" \
    -n datadog
EOF

kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -

if ! kubectl get secret datadog-secret -n "$ns" >/dev/null 2>&1; then
  echo "missing secret '$ns/datadog-secret'; create it with your Datadog API key before installing" >&2
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
