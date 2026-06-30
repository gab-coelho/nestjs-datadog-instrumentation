# Objetivo

Este repositório é apenas um lab para comparar duas estratégias de instrumentação Datadog em NestJS.
Ele não visa substituir uma avaliação de produção.

## Premissas

- O cluster de referência é local, usando kind com registry em `localhost:5001`.
- As duas variantes devem expor a mesma aplicação e receber tráfego comparável.
- A variante manual deve conter `dd-trace` antes de qualquer módulo instrumentável da aplicação.
- A variante SSI deve depender do Admission Controller do Datadog para injetar a biblioteca de auto-instrumentation.
- A aplicação base usa `module: Node16`; a variante manual compila a mesma fonte como CommonJS para que `node -r ./dist/tracer.js` carregue `dd-trace` antes dos imports de Nest.
- O Datadog é instalado pelo Operator, e o Agent é configurado pelo manifest `datadog/agents/datadog-agent.yaml`.
- `DD_API_KEY` não é versionada; use `.env` ou crie o secret Kubernetes `datadog-secret` manualmente fora do repositório.
- A comparação deve usar o mesmo ambiente Datadog, mesma janela de tempo e volume de tráfego semelhante.

## Ressalvas

- Resultados de latência e overhead em kind não representam automaticamente produção.
- A cobertura de auto-instrumentation depende da versão da biblioteca injetada e das bibliotecas usadas pela aplicação.
- Spans de lógica de negócio ainda exigem código manual, mesmo quando SSI está habilitado.
- SSI reduz mudanças por serviço, mas aumenta a importância da governança de configuração no cluster.
- Instrumentação manual dá mais controle por serviço, mas cria trabalho recorrente de manutenção de dependências.
- Falhas na chamada ao provedor mock de pagamento são engolidas de propósito para manter o fluxo do lab ativo e ainda gerar traces comparáveis.
