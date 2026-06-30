# Mutações observadas nos pods SSI

Use este arquivo como template depois de executar o laboratório. Não preencha
com conteúdo sintético: registre apenas o que apareceu no cluster real.

## Coleta sugerida

```bash
kubectl get pods -n nestjs-auto
kubectl describe pod <pod> -n nestjs-auto
kubectl get pod <pod> -n nestjs-auto -o yaml
```

Compare o resultado com `ssi-instrumentation/k8s/deployment.yaml`.

## Init containers injetados

<!-- preencher após rodar o lab -->

## Volumes injetados

<!-- preencher após rodar o lab -->

## Volume mounts injetados

<!-- preencher após rodar o lab -->

## Variáveis de ambiente injetadas

<!-- preencher após rodar o lab -->

## Observações

<!-- preencher após rodar o lab -->
