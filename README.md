# Single Step Instrumentation vs SDK manual em aplicações NestJS

A ideia é usar a mesma aplicação em duas formas de instrumentação e comparar lado a lado a preparação, implantação, configuração e cobertura de observabilidade.

## Estrutura do repositório

- `app/` — backend NestJS simples (sem nenhum código específico do Datadog), usado como base para ambas as variantes.
- `manual-instrumentation/` — variante com `dd-trace` adicionado manualmente (código + Dockerfile + manifests Kubernetes).
- `ssi-instrumentation/` — variante usando a mesma imagem base, instrumentada via Admission Controller.
- `datadog/` — values para instalar o Datadog Operator e manifest `DatadogAgent`.
- `load-testing/` — script k6 para gerar tráfego comparável nas duas variantes.
- `docs/` — matriz de comparação, fluxo do teste e premissas/ressalvas.
- `scripts/` — automação de cluster, build, deploy e limpeza do ambiente.

## Pré-requisitos

- `kubectl`, `helm`, Docker, kind, Node.js 20+
- `k6` para gerar carga local
- Conta Datadog com API key e permissão para instalar o Agent

## Como rodar

```bash
# Sobe o cluster kind com registry local em localhost:5001
./scripts/cluster.sh

# Crie o secret fora do repositório antes de instalar o Datadog
kubectl create namespace datadog --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic datadog-secret \
  --from-literal api-key="$DD_API_KEY" \
  -n datadog

# Instala o Datadog Operator e aplica o DatadogAgent
./scripts/datadog.sh

# Faz o build das imagens base e manual, e envia ao registry local
./scripts/build.sh all

# Implanta as duas variantes
./scripts/deploy.sh all

# Gera tráfego para comparar no Datadog
./scripts/load.sh manual
./scripts/load.sh auto
```

Depois disso, compare os dois serviços no APM e preencha suas observações em `docs/comparison-matrix.md`.

## Fluxo completo do laboratório

Passo a passo detalhado, incluindo como inspecionar o que o Admission Controller injeta nos pods e como simular falhas propositais de cada abordagem, está em [`docs/lab-flow.md`](docs/lab-flow.md).

## Resultado esperado

Ao final do laboratório você deve conseguir responder, com dados reais (não só documentação):

- Qual abordagem é melhor para cada caso de uso?
- Qual cobre melhor spans customizados e lógica de negócio?
- O que acontece quando cada uma falha silenciosamente?
- Qual é mais fácil de manter em escala, com muitos serviços?

Veja a matriz completa em [`docs/comparison-matrix.md`](docs/comparison-matrix.md).

## Importante

Este repositório é um laboratório de comparação, não um guia de rollout para produção. 
Decisões também devem considerar consistência entre serviços, e integração com o pipeline de CI/CD existente.
Mais detalhes em [`docs/assumptions-and-caveats.md`](docs/assumptions-and-caveats.md).