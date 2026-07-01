# Learning Journal

Este journal documenta a história do repositório até o commit `c732404`, que é o
`HEAD` gravado no momento desta edição.

## Como este journal usa evidências

- Base primária:
  `git log`, `README.md`, `openapi.yaml`, `docs/architecture/overview.md`,
  `docs/evaluation-guide.md`, `docs/observability.md`,
  `docs/testing-strategy.md` e `docs/spec-driven/verification-report.md`.

- Quando este texto afirma que o projeto endureceu segurança, contracts ou
  quality gates:
  a leitura se apoia na mensagem do commit, nos arquivos tocados e nos testes ou
  comandos documentados no verification report.

- Escopo:
  commits já gravados até `c732404`.

## O que o histórico não prova

- O histórico não prova escala real de fan-out sob carga alta.
- O histórico não prova operação de produção com incidentes humanos reais.
- O histórico não prova que toda alternativa arquitetural foi debatida
  publicamente; algumas comparações abaixo são inferência comparativa a partir do
  desenho atual.

## 1. Objetivo do projeto

FlowBridge existe para ensinar como tratar automação orientada a webhook como um
produto operacional sério, não como um punhado de callbacks disparando HTTP. O
repo quer deixar claro que os problemas importantes são:

- workflow versionado e imutável;
- validação de grafo antes de publicar;
- execução assíncrona com retry e dead-letter;
- egress HTTP sob política explícita;
- evidência de connector sem vazar segredo.

Ao terminar este journal, o leitor deve conseguir:

- seguir um webhook da ingestão até a execução e o dead-letter;
- explicar por que publicar workflow é uma operação de versionamento, não um
  simples `save`;
- apontar onde o código diferencia erro de transporte, erro de node e erro de
  modelagem;
- dizer quais testes e quality gates tornam o repo confiável.

## 2. Como ler o repositório primeiro, em ordem de aprendizado

1. Leia `README.md`.
2. Leia `docs/architecture/overview.md` e `docs/architecture/module-boundaries.md`.
3. Leia `openapi.yaml`.
4. Leia `app/controllers/api/base_controller.rb` e
   `app/services/flow_bridge/webhook_ingestor.rb`.
5. Leia `app/services/flow_bridge/workflow_graph_validator.rb`,
   `app/services/flow_bridge/workflow_publisher.rb` e
   `app/services/flow_bridge/graph_checksum.rb`.
6. Leia `app/services/flow_bridge/execution_runner.rb`,
   `app/services/flow_bridge/node_executor.rb` e
   `app/services/flow_bridge/retry_policy.rb`.
7. Leia `app/services/flow_bridge/http_client.rb`,
   `app/services/flow_bridge/http_egress_policy.rb` e
   `app/services/flow_bridge/secret_masker.rb`.
8. Feche com `test/integration/api_workflow_lifecycle_test.rb`,
   `test/integration/webhook_failure_scenarios_test.rb`,
   `test/services/node_executor_test.rb` e
   `test/system/operator_console_test.rb`.

### O que ignorar na primeira passada

- Não comece por deploy/Kamal.
  O coração do aprendizado está no boundary do workflow, não na entrega.

- Não comece pelo console do operador.
  Ele faz mais sentido depois que o caminho webhook -> execution -> DLQ já está
  claro.

## 3. História cronológica da implementação

### Fase 1: fundação, core e console (`d0ff96a` a `f51dafb`, 2026-05-29)

- O projeto começou por baseline documental, runtime Rails de produção e um
  primeiro core de workflow automation.
- Logo depois entrou o console autenticado do operador, o que mostra uma
  prioridade incomum e correta: operação não foi tratada como pós-scriptum.
- Base usada:
  commits `d0ff96a`, `39d0e49`, `0769bb9`, `f51dafb`; `README.md`,
  `app/services/flow_bridge/*`, `app/controllers/operator/*`.

### Fase 2: documentação de arquitetura e postura de showcase (`1eab0d1` a `35bd192`, 2026-05-29 a 2026-05-30)

- O repositório passou a se explicar como portfolio de seniority, com
  architecture docs, threat guidance, evaluation guide e readiness spec.
- Isso importa para o journal porque o repo não quer só “funcionar”; ele quer
  ser lido, avaliado e defendido.
- Base usada:
  commits `1eab0d1`, `e500971`, `81b6488`, `6f2a04f`, `28952a0`, `5c240f5`,
  `35bd192`; docs em `docs/`.

### Fase 3: hardening real de produção local (`75b11f4` a `c732404`, 2026-05-31)

- Esta fase concentra o que diferencia um toy workflow engine de um sistema que
  já pensa como specialist.
- `75b11f4` endurece readiness do motor.
- `f95adf9` e `d6b3001` atacam o risco clássico de connectors: egress inseguro e
  vazamento de segredo em evidência.
- `1d98bb6` e `9e8674f` mostram maturidade de contrato: métricas de outbound e
  OpenAPI validado contra respostas reais.
- `b44745c` e `c732404` fecham com quality gates mais rígidos e documentação do
  novo nível de exigência.
- Base usada:
  commits `75b11f4`, `f95adf9`, `1d98bb6`, `9e8674f`, `1bcc132`, `d6b3001`,
  `b44745c`, `c732404`; verification report e testes.

## Features importantes como unidades completas

### Publicação imutável de workflow

- Problema que resolve:
  editar um workflow já em voo destrói auditabilidade e explicabilidade.

- Commits principais:
  `0769bb9`, `75b11f4`.

- Arquivos principais:
  `app/services/flow_bridge/workflow_graph_validator.rb`,
  `app/services/flow_bridge/workflow_publisher.rb`,
  `app/services/flow_bridge/graph_checksum.rb`,
  `test/models/workflow_version_test.rb`.

- Por que a solução final tomou essa forma:
  o repo preferiu versionar e validar explicitamente em vez de empurrar a
  disciplina para convenção informal no controller.

- Alternativa plausível:
  workflow mutável com snapshot tardio.
  O desenho atual rejeita isso na prática.

### Execução, retry e dead-letter

- Problema que resolve:
  falha de connector não pode nem bloquear o request original nem sumir como
  ruído operacional.

- Commits principais:
  `0769bb9`, `75b11f4`, `1d98bb6`.

- Arquivos principais:
  `app/services/flow_bridge/execution_runner.rb`,
  `app/services/flow_bridge/node_executor.rb`,
  `app/services/flow_bridge/retry_policy.rb`,
  `app/controllers/operator/dead_letters_controller.rb`.

- Testes que protegem a feature:
  `test/services/execution_runner_test.rb`,
  `test/services/node_executor_test.rb`,
  `test/integration/webhook_failure_scenarios_test.rb`,
  `test/jobs/workflow_execution_job_test.rb`.

### Connector real com egress policy e secret masking

- Problema que resolve:
  chamar HTTP “de verdade” sem política explícita ou redaction transforma a
  demo em risco.

- Commits principais:
  `f95adf9`, `d6b3001`.

- Arquivos principais:
  `app/services/flow_bridge/http_client.rb`,
  `app/services/flow_bridge/http_egress_policy.rb`,
  `app/services/flow_bridge/secret_masker.rb`.

- Prós:
  torna a demo honesta e mais próxima de revisão real.

- Contras:
  cresce o custo de fixture, test harness e surface area de segurança.

## 4. Decisão por decisão

- Workflow versionado e publicado:
  escolhido para garantir replay e auditabilidade.

- Console operador dentro do monólito:
  escolhido porque DLQ, retry e inspeção são parte do produto, não acessório.

- Egress policy explícita:
  escolhida para que integração externa não vire capacidade implícita demais.

- Quality gates mais rígidos:
  escolhidos porque um repo que vende seniority precisa provar mais do que “testes
  passaram”.

## 5. Prós e contras das escolhas principais

- Imutabilidade de workflow:
  pró: reduz ambiguidade histórica.
  contra: aumenta fricção de evolução.

- Connector real:
  pró: ensino mais honesto.
  contra: mais risco de configuração e mais paths de falha.

- Monólito operacional:
  pró: reduz latência cognitiva entre runtime e console.
  contra: cresce a superfície do deployable.

## 6. Erros, correções e endurecimentos

- O histórico mostra que o repo não tratou readiness como resolvido cedo demais;
  ele voltou nisso em `75b11f4`.
- Egress seguro e masking vieram como correções de maturidade, não como
  ornamentação.
- OpenAPI contracts e CI gates também são sinais de que a forma final só ficou
  aceitável depois de uma segunda passada de rigor.

## 7. Como os testes foram usados

- Primeiro para provar o lifecycle básico do workflow.
- Depois para isolar execution runner, node executor e falhas de webhook.
- Por fim para validar respostas OpenAPI reais e consolidar o repositório como
  showcase verificável.

## 8. Quais testes protegem quais decisões

- Publicação/versionamento:
  `test/models/workflow_version_test.rb`,
  `test/integration/api_workflow_lifecycle_test.rb`.

- Execução e retries:
  `test/services/execution_runner_test.rb`,
  `test/services/node_executor_test.rb`,
  `test/jobs/workflow_execution_job_test.rb`.

- Segurança de connector:
  `test/services/http_egress_policy_test.rb`,
  `test/services/secret_masker_test.rb`.

- Contrato e operação:
  `test/integration/openapi_response_contract_test.rb`,
  `test/integration/rate_limiting_and_metrics_test.rb`,
  `test/system/operator_console_test.rb`.

## 9. Timeline dos commits atômicos

| Commit | Pergunta que o commit responde | Mudança principal | Prova |
| --- | --- | --- | --- |
| `d0ff96a` | Qual é o problema do produto? | baseline documental | docs |
| `39d0e49` | Como preparar o runtime? | fundação Rails de produção | scaffold |
| `0769bb9` | Como modelar o core de workflow? | engine inicial | services/tests |
| `f51dafb` | Como operar o motor? | console autenticado | operator controllers |
| `1eab0d1` | Como explicar a arquitetura? | docs de arquitetura e avaliação | docs |
| `e500971` | Como manter fixtures confiáveis? | determinismo de fixtures | tests |
| `81b6488` | Como reduzir ruído do scaffold? | limpeza de Active Storage variants | code cleanup |
| `28952a0` | Como implantar manualmente? | workflow Kamal | CI/deploy docs |
| `5c240f5` | Como tratar ameaça e evento? | threat + event guidance | docs |
| `35bd192` | Como avaliar seniority? | readiness spec-driven | docs/spec-driven |
| `75b11f4` | O motor já é operacionalmente confiável? | readiness hardening | tests/docs |
| `f95adf9` | Como impedir egress perigoso? | connector egress policy | security tests |
| `1d98bb6` | Como observar outbound? | outbound idempotency metrics | metrics/tests |
| `9e8674f` | O OpenAPI ainda bate com runtime? | response contracts executáveis | integration tests |
| `1bcc132` | Como registrar o endurecimento? | contract hardening evidence | docs |
| `d6b3001` | Como guardar evidência sem vazar segredo? | secret masking | tests/services |
| `b44745c` | A barra de CI é suficiente? | quality gates mais rígidos | CI |
| `c732404` | Como explicar a nova barra? | docs de stricter quality gates | docs |

## 9A. Perguntas de recuperação

- Por que o repo escolhe publicar workflow em vez de editar workflow ativo?
- Onde você investigaria primeiro uma execução “travada”: job, retry policy ou
  graph validator?
- Qual arquivo melhor explica o limite entre HTTP real e capacidade autorizada?

## 10. Comandos de terminal que um specialist usaria aqui

Comandos historicamente documentados no verification report ou diretamente úteis
para reproduzir o raciocínio:

```bash
git log --oneline --reverse
git show --stat f95adf9
bin/rails test test/services/node_executor_test.rb test/services/execution_runner_test.rb
bin/rails test test/integration/openapi_response_contract_test.rb
bin/rails test:all
bin/rubocop
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
bin/bundler-audit
npx --yes @redocly/cli lint openapi.yaml
bin/ci
```

## 11. Como adicionar a próxima feature sem quebrar a aula

Se a próxima feature for um novo tipo de node:

1. descreva o shape no validator antes de executar;
2. exponha o efeito no `node_executor`;
3. decida se a evidência precisa de masking;
4. prove falha e sucesso em tests/services e integration.

## 12. Limites de produção deixados de propósito

- não prova escala alta de automação massiva;
- não tenta virar engine distribuído de longa duração;
- não cobre secrets manager real, incident response real nem deploy com tráfego
  público contínuo;
- mantém foco em clareza de boundary e operabilidade local auditável.

## 13. Resultado das revisões de qualidade

O próprio repositório registra um passo de maturidade importante em
`docs/spec-driven/verification-report.md`: não bastou “o app roda”. O nível
aceitável passou a incluir tests:all, RuboCop, Brakeman estrito, bundler-audit,
lint de OpenAPI, checagem de links de docs e `bin/ci`.

## 14. Addendum: benchmark também é contrato operacional

Um gap posterior apareceu fora do core de domínio: a trilha de benchmark dizia
que o repo tinha metodologia e scripts, mas a execução local ainda não era um
contrato operável de verdade.

- O problema real não era “falta mais um gráfico”.
  Era pior: o reviewer path aceitava um benchmark que falhava com erro opaco de
  `k6`, e o default do connector URL batia na própria política de egress do
  projeto.

- A correção certa não é afrouxar a política default.
  O ajuste local bom é isolar a exceção no harness de benchmark, não no runtime
  normal do app.

- Isso produz uma lição útil:
  benchmark para portfolio não é só script no repositório; é um caminho
  canônico que sobe a app, espera readiness, executa a carga, grava o resumo e
  falha com mensagem explicável quando o contrato quebra.
