# Fluxo do laboratório

Passos para reproduzir o laboratório com comandos prontos para copiar e executar.

1. `scripts/cluster.sh` sobe um cluster local usando kind e um registry em `localhost:5001`.
2. Crie um `.env` com `DD_API_KEY`, usando `.env.example` como base.
3. `scripts/datadog.sh` cria/atualiza o Secret Kubernetes a partir do `.env`, instala o Datadog Operator e aplica `datadog/agents/datadog-agent.yaml`, habilitando APM, Admission Controller e SSI.
4. `scripts/build.sh all` faz o build da imagem base (`app/Dockerfile.base`) e da imagem manual (`manual-instrumentation/Dockerfile`), enviando ambas para o registry local.
5. Implante a variante com instrumentação manual:
   - `scripts/deploy.sh manual` aplica os manifests de `manual-instrumentation/k8s/*`;
   - acesse `/health`, confirme que o pod está `Running` e valide que `DD_AGENT_HOST` resolve corretamente.
6. Implante a variante SSI:
   - reutilize a imagem base, sem novo build da aplicação; esse é o ponto principal da comparação;
   - `scripts/deploy.sh auto` aplica os manifests de `ssi-instrumentation/k8s/*` com as annotations/labels necessárias;
   - use `kubectl describe pod` e compare com o spec original para ver o que o admission webhook injetou (init containers, volumes e variáveis de ambiente).
7. `scripts/load.sh manual` e `scripts/load.sh auto` geram tráfego comparável nas duas apps.
   - inclui uma pequena taxa de 5xx no fluxo de pagamento, controlada por `PAYMENTS_MOCK_5XX_RATE` e aplicada ao ConfigMap por `scripts/deploy.sh`, para validar o Error Tracking no Datadog.
8. Compare os resultados no Datadog:
   - confirme que os dois serviços aparecem no APM;
   - confirme que há uma baixa taxa de erros 5xx;
   - compare a completude dos traces: chamadas HTTP de saída foram capturadas? chamadas de banco aparecem? os flame graphs são equivalentes para a mesma requisição?
   - se aparecerem spans `<anonymous>` na waterfall, use [`js-anonymous-spans.md`](js-anonymous-spans.md);
   - confira logs e valide se a correlação entre trace e log funciona em cada abordagem.
9. Quebre algo de propósito:
   - remova o `-r tracer.js` do Dockerfile da variante manual, faça o redeploy e confirme se o tracing para silenciosamente sem erro no startup;
   - remova a annotation/label de admission do deployment SSI, faça o redeploy e confirme se o pod volta limpo, sem instrumentação.
10. Registre as descobertas em `docs/comparison-matrix.md` com o que foi observado na prática, não apenas com o que a documentação promete.
11. `scripts/destroy.sh` remove o ambiente do laboratório.
