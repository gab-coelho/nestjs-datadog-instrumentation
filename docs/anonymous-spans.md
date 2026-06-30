# Entendendo os Spans `<anonymous>` nos traces

> 🕵️‍♂️ Saiba por que seu trace da Datadog mostra misteriosos spans sem nome.

---

## O que está acontecendo?

Você está monitorando sua aplicação NestJS com a Datadog e, de repente, encontra spans chamados `<anonymous>` no trace de uma requisição como `GET /orders/9999`.
Não veio do seu `OrdersController`, não é uma rota que você criou... então, de onde surgiu? 👻

A boa notícia: não é um bug.
A má notícia: é um comportamento esperado do `dd-trace-js` ao instrumentar a pilha de middleware do Express/router.

---

## A história por trás dos spans

Quando o `dd-trace-js` faz o tracing da sua aplicação, ele "intercepta" cada camada HTTP.
Cada middleware, parser e wrapper vira um span no trace.
O problema começa quando uma dessas funções não tem nome — ou tem um nome que o JavaScript considera vazio.
Nesses casos, o tracer não tem outra escolha senão rotulá-la como `<anonymous>`.

### Quem são os responsáveis?

| Span que você vê | De onde vem |
|---|---|
| `jsonParser` | Do middleware `express.json()` que o NestJS registra automaticamente |
| `urlencodedParser` | Do middleware `express.urlencoded()` também registrado pelo NestJS |
| `handle` | Da função interna do Express que despacha a rota |
| `<anonymous>` | De funções sem nome ou wrappers internos do framework |

---

## Por que isso acontece? A receita do bolo 🍰

Três ingredientes combinados produzem esse resultado:

1. **JavaScript adora funções anônimas** — callbacks e closures sem nome são perfeitamente válidos e extremamente comuns em middlewares.
2. **Express modela requisições como uma cadeia de funções** — cada middleware é uma função.
3. **`dd-trace-js` mostra cada passo dessa cadeia** — por padrão, ele cria um span para cada middleware, usando o nome da função como identificador.

### O caminho da informação

No lab, quando criamos a aplicação com `NestFactory.create(AppModule)`, o NestJS registra automaticamente dois parsers de body (a menos que desliguemos com `bodyParser: false`):
- `express.json()` → vira o span `jsonParser`
- `express.urlencoded()` → vira o span `urlencodedParser`

Esses nomes vêm direto do pacote `body-parser@2.2.0`, onde as funções são explicitamente nomeadas.
Já o Express 5 usa o pacote `router@2.2.0`, que tenta extrair o nome da função via `fn.name`.
Quando a função não tem nome, o fallback é... adivinhou: `<anonymous>`.

O `dd-trace-js@5.110.0` então pega esse nome e o usa como `resource.name` do span. Se o nome for vazio, você vê `<anonymous>` no APM.

---

## "Mas em Java ou .NET isso não acontece!"

Calma, lá também não é perfeito. A diferença está na **fonte dos metadados**:

| Plataforma | Como o tracer identifica spans |
|---|---|
| **Java** | O `javaagent` instrumenta classes carregadas pela JVM. Em Spring, o tracer consegue ler anotações, nomes de classe, métodos e templates de rota. É um modelo baseado em metadados estáticos e bem definidos. |
| **.NET** | O profiler integra-se com ASP.NET Core e usa route templates para nomear resources. A pipeline web é tratada de forma mais abstrata. |
| **Node.js** | O tracer depende do `fn.name` de callbacks em tempo de execução. Se a função é anônima, o nome é vazio. |

**A conclusão:** não é que Java/.NET estão "certos" e Node.js está "errado".
É que a pilha Node.js/Express é **callback-based**, e o tracer JavaScript está sendo mais transparente (alguns diriam: mais barulhento) sobre cada passo da pipeline.

---

## Usar SSI vs SDK Manual: faz diferença?

**Não**, a semântica dos spans é a mesma.

O que gera `jsonParser`, `urlencodedParser`, `handle` e `<anonymous>` é a biblioteca `dd-trace-js` instrumentando o Express/router, independentemente de como ela chegou lá.

A diferença real está na **inicialização e no controle de versão**:

| Variante | Como funciona | Observação |
|---|---|---|
| **SSI (Single Step Instrumentation)** | O Admission Controller injeta a biblioteca no pod automaticamente. | A versão pode mudar sem você alterar nada no repositório. |
| **Manual** | Você declara `dd-trace` no `package.json` (no lab, `^5.0.0`) e inicia a app com `node -r ./dist/tracer.js dist/main.js`. | Um novo `npm install` pode resolver uma versão diferente dentro do major 5. |

---

## Como mitigar 🔇

A solução mais eficaz é simples: **desabilite os spans de middleware** quando eles não agregam valor.

### Via variável de ambiente (funciona para SSI e manual):

```yaml
env:
  - name: DD_TRACE_MIDDLEWARE_TRACING_ENABLED
    value: "false"
```

Isso remove ou reduz drasticamente os spans `*.middleware`, incluindo os `<anonymous>`, mas **preserva o span HTTP principal** e a rota quando o framework consegue identificar `http.route`/`resource.name`.

### Via código, na variante manual:

```ts
tracer.init({
  service: process.env.DD_SERVICE,
  env: process.env.DD_ENV,
  version: process.env.DD_VERSION,
  logInjection: true,
  runtimeMetrics: true,
  middlewareTracingEnabled: false,
});
```

### Controle do plugin de router (variante manual):

```ts
tracer.use('router', {
  middleware: false,
});
```

> ⚠️ **Importante:** mantenha essa configuração no arquivo carregado por `node -r`, **antes** da aplicação importar Nest/Express. Se o tracer já instrumentou, é tarde demais.

---

## Outras abordagens (com ressalvas)

| Tática | O que faz | Limitação |
|---|---|---|
| **Nomear seus próprios middlewares** | Melhora spans de código que você controla | Não resolve wrappers internos ou funções anônimas do Nest/Express |
| **Criar spans customizados** | Use nomes explícitos como `orders.get` ou `payments.authorize` para lógica de negócio | Requer instrumentação manual com o SDK |
| **Fixar versões do tracer** | Evita surpresas ao comparar SSI vs manual | Não elimina os spans, só torna o comportamento previsível |

---

## Checklist para validar no lab ✅

1. **Gere tráfego** para uma rota (ex: `GET /orders/9999`) e confirme a presença dos spans `<anonymous>` no APM.
2. **Registre a versão efetiva** do tracer:
   - **SSI:** inspecione o pod mutado e verifique a versão injetada pelo Admission Controller.
   - **Manual:** rode `npm ls dd-trace` dentro da imagem ou durante o build.
3. **Aplique** `DD_TRACE_MIDDLEWARE_TRACING_ENABLED=false` nas duas variantes.
4. **Redeploy** as aplicações e gere o mesmo tráfego.
5. **Valide:** o span HTTP principal continua existindo? Os spans de middleware sumiram ou foram drasticamente reduzidos?

---

## Referências

- [Datadog — Configuração do SDK Node.js](https://docs.datadoghq.com/tracing/trace_collection/library_config/nodejs/)
- [Datadog — Single Step APM Instrumentation no Kubernetes](https://docs.datadoghq.com/tracing/trace_collection/single-step-apm/kubernetes/)
- [Datadog — Local SDK Injection](https://docs.datadoghq.com/tracing/guide/local_sdk_injection/)
- [Datadog — Admission Controller](https://docs.datadoghq.com/containers/cluster_agent/admission_controller/)
- [Datadog — Tracing Java applications](https://docs.datadoghq.com/tracing/trace_collection/dd_libraries/java/)
- [Datadog — Tracing .NET Core applications](https://docs.datadoghq.com/tracing/trace_collection/dd_libraries/dotnet-core/)
- [Datadog — Configuração do SDK .NET Core](https://docs.datadoghq.com/tracing/trace_collection/library_config/dotnet-core/)
- [Tarball npm `dd-trace@5.110.0`](https://registry.npmjs.org/dd-trace/-/dd-trace-5.110.0.tgz)
- [Tarball npm `router@2.2.0`](https://registry.npmjs.org/router/-/router-2.2.0.tgz)
- [Tarball npm `body-parser@2.2.0`](https://registry.npmjs.org/body-parser/-/body-parser-2.2.0.tgz)