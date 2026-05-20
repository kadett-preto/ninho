# IDEA.md — Ninho

> Documento de referência do produto **Ninho** — app de divisão de tarefas domésticas. Use como contexto inicial em sessões de Claude Code, Devin, Cursor ou similares. Mantenha atualizado conforme decisões evoluem.

---

## 0. Identidade do Produto

**Nome:** **Ninho**

O nome resume o tom: um espaço compartilhado, acolhedor, onde quem mora junto cuida do lugar em conjunto. Toda comunicação do app (copy, notificações, prompts da IA, marketing) deve refletir essa metáfora — fala-se em "ninho", "moradores do ninho", "cuidar do ninho", e nunca em termos hostis, militares ou de competição agressiva.

> **Para Claude (e qualquer agente):** sempre que precisar gerar copy, prompts, mensagens ou nomes de telas, use "Ninho" como nome do produto e mantenha o tom pacificador descrito em §8.

---

## 1. Visão Geral

Aplicativo mobile para **casais, amigos e famílias que moram juntos** (ou convivem temporariamente no mesmo ambiente) e querem uma divisão **justa e clara** de tarefas domésticas.

**Tom do produto:** leve, acolhedor e pacificador. O app deve **reduzir atrito** entre conviventes, não gerar cobrança hostil. Linguagem amigável, gamificada com moderação, sem tornar a casa um campo de competição.

**Público-alvo (MVP):** duplas que dividem um espaço — namorados, casais, colegas de quarto, irmãos.

---

## 2. Design e Identidade Visual

**O design do Ninho vive no Stitch (Google Stitch).**

- Todos os fluxos visuais, telas, componentes e variantes de UI **estão sendo desenhados no Stitch** — essa é a fonte da verdade para layout, hierarquia, espaçamento, tipografia e paleta.
- **Antes de implementar qualquer tela**, o agente (Claude Code/Devin/Cursor) deve **pedir o link ou export do Stitch correspondente** àquela tela. Não inventar UI a partir do zero quando o design já existe.
- Se o Stitch ainda não tem a tela, o agente deve sinalizar isso explicitamente em vez de improvisar layouts genéricos — a decisão de design fica com a pessoa, não com o agente.
- O código Flutter deve **espelhar** o que está no Stitch: nomes de componentes, tokens de cor, tipografia e espaçamento devem ser extraídos do design, não improvisados.
- Quando houver divergência entre o que está no Stitch e o que está implementado, **o Stitch ganha** (a menos que haja decisão registrada aqui no IDEA.md em sentido contrário).

**Workflow esperado:**
1. Pessoa indica a tela a ser implementada e fornece o link/export do Stitch.
2. Agente extrai tokens (cores, tipografia, espaçamentos), componentes e estados visuais.
3. Agente implementa em Flutter, mantendo paridade visual.
4. Qualquer adaptação técnica (ex.: limitações do Flutter, acessibilidade) é registrada em comentário no código **e** sinalizada para a pessoa.

---

## 3. Conceitos Centrais (Glossário)

| Termo | Definição |
|---|---|
| **Ninho** | Espaço compartilhado (ex.: apartamento). Unidade de tenancy do app. *(Antes chamado de "ambiente" — o termo técnico no banco continua `environment` por compatibilidade, mas a UI sempre fala "ninho".)* |
| **Cômodo** | Subdivisão de um ninho (sala, cozinha, banheiro...). Possui tamanho aproximado e foto opcional. |
| **Morador** | Usuário participante de um ninho. Papéis: `owner` ou `member`. |
| **Task** | Tarefa doméstica com data de início, recorrência e responsável. Classificada por dificuldade: `mamão`, `embaçada`, `treta`. |
| **Poeira na pá** | Moeda interna do app, ganha ao concluir tasks. Valor varia conforme dificuldade. |
| **Streak** | Sequência de dias consecutivos sem falhar tasks. Existe por usuário e por ninho. |
| **Feed** | Linha do tempo de eventos do ninho (tasks concluídas, fotos, resumos). |

---

## 4. Fluxo do App (End-to-End)

> Esta seção descreve **o caminho que um usuário percorre** desde o primeiro toque no ícone até o uso recorrente. Claude deve consultar esta seção sempre que precisar entender em que ponto do app uma feature se encaixa.

### 4.1. Fluxo de Primeiro Acesso (Novo Usuário, Cria Ninho)

```
1. Splash / Onboarding
   └─ 3 telas curtas explicando: dividir tarefas, ganhar poeira, manter streak.
      Botão "Começar" no final.

2. Login
   └─ Opções: Google, Apple (obrigatório iOS), outros providers Supabase.
   └─ Consentimento LGPD explícito (§3.10).

3. Tela: "Criar ninho ou entrar em um?"
   ├─ [Criar novo ninho] → segue para 4.
   └─ [Entrar em um ninho] → segue para 4.7 (fluxo de convite).

4. Criar Ninho
   ├─ 4.1. Nome do ninho (ex.: "Nosso ap").
   ├─ 4.2. Fuso horário (default = fuso do dispositivo, editável).
   ├─ 4.3. Idioma (default = idioma do dispositivo entre pt-BR/en).
   └─ 4.4. Próximo →

5. Cadastrar Cômodos
   ├─ Lista vazia + botão "+ adicionar cômodo".
   ├─ Para cada cômodo:
   │   ├─ Nome (campo livre, com sugestões: sala, cozinha, banheiro, quarto...).
   │   ├─ Tamanho: P / M / G (com tooltip explicando m² aproximado).
   │   └─ Foto opcional.
   └─ Mínimo 1 cômodo para prosseguir.

6. Geração Inicial de Tasks por IA
   ├─ Agente Claude recebe lista de cômodos + tamanhos.
   ├─ Sugere lista de tasks (título, cômodo, dificuldade, recorrência sugerida).
   ├─ Usuário aceita/edita/remove cada uma.
   └─ Confirma → tasks criadas no banco.

7. Convidar Morador
   ├─ Mostra QR Code + link compartilhável.
   ├─ Botão "Compartilhar via..." (share sheet nativa).
   └─ Botão "Pular por enquanto" (pode convidar depois).

8. Tela Principal (Home / Hoje)
   └─ Entrada no uso recorrente — ver 4.4.
```

### 4.2. Fluxo de Entrada via Convite

```
1. Usuário recebe link/QR.
2. Abre o app (instala se necessário).
3. Login (Google/Apple/etc.).
4. App detecta o convite pendente → tela "Entrar no ninho X?".
5. Confirma → vira `member` do ninho.
6. Tour rápido (3 cards): "estas são suas tasks", "seu streak começa hoje", "fique de olho no feed".
7. Tela Principal.
```

### 4.3. Fluxo Diário (Uso Recorrente)

```
Manhã (09h padrão)
└─ Notificação amigável personalizada por IA.
   └─ Toca → abre direto na task pendente.

Tarde (15h padrão)
└─ Notificação "tudo certo com a task?" (se ainda pendente).

Noite (20h padrão)
└─ Notificação "streak em risco" (se ainda pendente).

A qualquer momento:
├─ Abre app → tela Home com:
│   ├─ Tasks de hoje (suas + do(s) outro(s) morador(es)).
│   ├─ Indicador de streak (individual + do ninho).
│   ├─ Saldo de poeira na pá.
│   └─ Atalho para o feed.
│
├─ Marca task como feita:
│   ├─ Opcional: tira foto do resultado.
│   ├─ Recebe poeira (5/15/40 conforme dificuldade).
│   ├─ Sistema cancela notificações restantes da task.
│   └─ Evento entra no feed.
│
└─ Loja (acessível pela home):
    ├─ Saldo + itens disponíveis.
    └─ Item MVP: Transferência de Task (30 poeiras, ver §3.8).

Meia-noite (fuso do ninho)
└─ Job avalia streaks:
   ├─ Tasks pendentes não concluídas → falha.
   ├─ Aplica "freeze" automático se disponível (§3.7).
   ├─ Atualiza streaks de usuário e de ninho.
   └─ Notifica se streak quebrou.

Domingo à noite
└─ IA gera resumo semanal → publica no feed.
```

### 4.4. Mapa de Telas (alto nível)

```
Auth
 ├─ Splash
 ├─ Onboarding (3 cards)
 ├─ Login
 └─ Consentimento LGPD

Onboarding de Ninho
 ├─ Criar ou entrar
 ├─ Criar ninho (nome, fuso, idioma)
 ├─ Cadastrar cômodos
 ├─ Geração de tasks por IA (revisar/aceitar)
 └─ Convidar morador (QR/link)

App Principal (tab bar)
 ├─ [Tab 1] Hoje
 │   ├─ Lista de tasks do dia
 │   ├─ Streak + poeira no topo
 │   └─ Detalhe da task (concluir, foto, transferir)
 ├─ [Tab 2] Tasks
 │   ├─ Todas as tasks do ninho (filtros: minhas, todas, por cômodo)
 │   ├─ Criar task manual
 │   └─ Editar task
 ├─ [Tab 3] Feed
 │   ├─ Eventos do ninho
 │   ├─ Fotos
 │   └─ Resumos semanais da IA
 ├─ [Tab 4] Loja
 │   ├─ Saldo de poeira
 │   ├─ Itens disponíveis
 │   └─ Histórico de compras
 └─ [Tab 5] Perfil/Ninho
     ├─ Conta (exportar dados, deletar conta — LGPD)
     ├─ Configurações do ninho (owner): cômodos, membros, modo viagem, loja on/off
     ├─ Notificações (horários customizáveis)
     └─ Sair do ninho / Transferir ownership
```

> **Para Claude:** ao implementar uma tela, identifique-a primeiro neste mapa, depois consulte o Stitch correspondente (§2). Se uma tela aqui descrita não existir no Stitch, **pergunte antes de implementar**.

---

## 5. Features

### 5.1. Autenticação
- Login via **Google** e demais provedores suportados pelo Supabase Auth (Apple obrigatório para publicação iOS).
- Conta única por e-mail; um mesmo usuário pode participar de múltiplos ninhos.

### 5.2. Cadastro de Ninho
- Usuário informa **cômodos**, **tamanho aproximado** de cada um e pode (opcionalmente) tirar **foto** de cada cômodo.
- **Tamanho do cômodo:** input em categorias **P / M / G** (escolha guiada com referência em m² no tooltip — reduz fricção no onboarding e funciona como entrada estruturada para a IA gerar tasks).
- **Limite MVP:** 2 pessoas por ninho. Limite ampliado em planos premium futuros.
- Quem cria o ninho é o **owner** por padrão.
- **Fuso horário do ninho:** definido pelo owner no cadastro (default = fuso do dispositivo). Toda lógica de streak, recorrência e notificações usa este fuso, garantindo que moradores em fusos distintos compartilhem o mesmo "dia".

### 5.3. Convite ao Ninho
- Cada ninho gera um **QR Code** e um **link de convite** compartilhável.
- Quem entra via convite vira `member` por padrão.
- O `owner` pode promover/rebaixar membros e remover participantes.
- **Convites têm expiração** (default: 7 dias) e podem ser revogados pelo owner a qualquer momento — ver §7 (Segurança).

### 5.4. Tasks
- Criação **manual** ou **assistida por IA** (agente gera lista de tasks a partir dos cômodos cadastrados).
- Campos: título, descrição, cômodo associado, responsável, dificuldade (`mamão`/`embaçada`/`treta`), **data de início**, **recorrência** (definida manualmente ou sugerida pela IA).
- Ao **concluir**, o usuário pode anexar uma foto opcional do resultado — a foto aparece no feed do ninho.
- Recompensa em **poeira na pá** proporcional à dificuldade (ver §5.8).

### 5.5. Perfis e Permissões
- **Owner:** gerencia ninho, cômodos, membros, tasks e configurações.
- **Member:** cria/edita tasks atribuídas a si, marca como feita, interage no feed.
- **Transferência de ownership:** o owner pode promover outro membro a owner antes de sair do ninho. Se o owner deletar a conta sem transferir, o sistema promove automaticamente o membro mais antigo. Se o ninho ficar sem membros, é arquivado por 30 dias e depois purgado.
- **Saída/remoção de membro:**
  - Tasks pendentes atribuídas ao membro voltam para uma fila "sem responsável" — o owner reatribui.
  - Histórico de tasks concluídas e fotos no feed **permanecem** (autoria preservada, mas membro aparece como "ex-morador").
  - Streak individual do membro é arquivado; ele leva consigo se reentrar em outro ninho (streak é por usuário, não por ninho).

### 5.6. Notificações Push
Três disparos diários por task pendente, com tom progressivo gerado por agente IA (personalizado ao ninho e seus moradores — **não** mensagens genéricas):

| Período | Horário padrão | Tom |
|---|---|---|
| Manhã | 09h | Amigável, lembrete leve |
| Tarde | 15h | Questionador, "tudo certo com a task?" |
| Noite | 20h | Urgência, "streak em risco" |

Horários são ajustáveis por usuário nas configurações. Antes de disparar, o sistema **sempre verifica** se a task já foi marcada como feita — se sim, suprime a notificação.

**Outros gatilhos de notificação:**
- Task transferida para você
- Novo morador entrou no ninho
- Foto postada no feed
- Streak em risco (última janela do dia sem task feita)
- Streak quebrado
- Item comprado na loja

### 5.7. Streak
- **Streak de usuário:** baseado nas tasks do próprio usuário. Falhar uma task zera o streak individual.
- **Streak de ninho:** baseado nas tasks de todos os moradores. Se **qualquer** morador falhar, o streak do ninho zera — mas o streak individual de quem **não** falhou se mantém.
- **Avaliação** acontece à meia-noite no fuso horário do ninho.
- **Política de graça (Streak Freeze):** cada usuário tem **2 "freezes" automáticos por mês** que cobrem 1 dia de falha sem zerar o streak (inspirado no Duolingo). Freezes não cobrem o streak do ninho — apenas o individual. Não são acumuláveis entre meses.
- **Congelamento manual (viagem):** o owner pode pausar o ninho por até 14 dias/ano (modo "viagem"), em que tasks são suspensas e streaks ficam intactos.

### 5.8. Loja e Economia ("Poeira na Pá")

**Tabela de recompensas por task concluída:**

| Dificuldade | Poeira ganha | Exemplos |
|---|---|---|
| Mamão 🥭 | **5** | Fazer a cama, tirar o lixo, lavar uma louça pontual |
| Embaçada 😅 | **15** | Aspirar a sala, limpar fogão, dobrar roupas |
| Treta 😤 | **40** | Faxina pesada do banheiro, limpar geladeira, lavar área de serviço |

**Item inicial (MVP) — Transferência de Task:**
- Custo: **30 poeiras**.
- Permite transferir **1 task** para outro morador do ninho.
- Uso limitado a **1 vez por semana** por usuário (reset toda segunda-feira no fuso do ninho).
- Pode ser **desativado nas configurações** do ninho pelo owner.
- Quando ativado, o destinatário **não pode recusar** a transferência.
- **Antiabuso:** o sistema bloqueia transferir para o mesmo destinatário em semanas consecutivas — força alternância em ninhos com 3+ pessoas (no MVP de 2 pessoas, vira cooldown de 1 semana adicional após cada uso).
- Quem **conclui** a task ganha a poeira da conclusão (não quem transferiu).

**Roadmap de itens futuros:** Streak Freeze extra, Skip de task (apaga a task do dia sem penalidade), customizações cosméticas, badges de ninho.

### 5.9. Feed
**Feed do ninho (MVP):**
- Resumo semanal das tasks do ninho (todo domingo à noite, gerado por IA)
- Fotos postadas ao concluir tasks
- Tasks finalizadas e eventos relevantes (novo morador, conquistas de streak, transferências)

**Moderação do feed:**
- Autor da foto pode deletá-la a qualquer momento.
- Owner pode ocultar/deletar qualquer item do feed do seu ninho.
- Botão "denunciar" disponível em todos os itens (reservado para o feed geral v2 — no MVP, dentro do ninho serve como sinal interno).

**Feed geral (futuro/v2):** linha do tempo pública com interações entre ninhos — escopo a definir.

### 5.10. Compliance e Internacionalização
- Implementação de regras **LGPD**:
  - Consentimento explícito no onboarding.
  - Exportação de dados (JSON via tela de conta).
  - Exclusão de conta com **purga em 30 dias** (soft delete + hard delete agendado), com tratamento do caso owner (ver §5.5).
  - Fotos: retenção **indefinida** enquanto o ninho existir; deletadas junto com a conta/ninho.
  - Conteúdo de fotos é visível **apenas** para moradores do ninho; nunca exposto fora dele no MVP.
- Suporte a **múltiplos idiomas** desde o lançamento: **pt-BR e en** no MVP, com estrutura preparada para es, fr. Prompts da IA também internacionalizados.

---

## 6. Stack Técnica

### 6.1. Mobile
- **Flutter** (Dart) — multiplataforma iOS/Android.
- Pacotes-chave a avaliar: `firebase_messaging` para push, `image_picker`, `mobile_scanner` (QR), `supabase_flutter`.

### 6.2. Backend
- **Supabase** como base:
  - Postgres + Auth + Storage + Realtime + **Row Level Security** (RLS).
  - RLS isola dados por ninho (multi-tenant).
  - Storage para fotos de cômodos e de tasks concluídas.
  - Realtime para o feed do ninho.
- **Edge Functions (Deno)** para lógica de agentes, cálculo de streak e jobs.
  - Alternativa caso a lógica cresça: **Node + Fastify** em serviço separado.

### 6.3. IA / Agentes
- **Claude API (Anthropic)** para:
  - Geração de tasks a partir dos cômodos cadastrados (incluindo recorrência sugerida).
  - Mensagens **personalizadas** de notificação (manhã/tarde/noite) com contexto do ninho, moradores e histórico.
  - Resumo semanal do feed.
- **Prompt caching** para reduzir custo nas notificações 3x/dia (contexto do ninho é estável).

### 6.4. Jobs e Notificações
- **Supabase Cron + Edge Functions** para disparos diários e checagem de streak à meia-noite.
  - Alternativa: **Trigger.dev** ou **Inngest** se a orquestração crescer.
- **Push:** Firebase Cloud Messaging (FCM) para Android e APNs para iOS, integrados via `firebase_messaging` no Flutter.

### 6.5. Observabilidade e Produto
- **Sentry** — rastreamento de erros mobile + backend.
- **PostHog** — analytics de produto e feature flags.
- **RevenueCat** — se/quando a loja envolver compras com dinheiro real (in-app purchases).

---

## 7. Segurança

> **Para Claude:** segurança não é opcional nem "fase 2". Toda implementação deve considerar essas diretrizes desde o primeiro commit. Quando estiver em dúvida entre "fazer rápido" e "fazer seguro", **escolha seguro e sinalize o trade-off**.

### 7.1. Isolamento Multi-Tenant (Crítico)
- **RLS no Supabase é obrigatório em todas as tabelas** que tenham `environment_id`. Nunca confiar apenas na camada de aplicação para isolamento.
- Toda policy de RLS deve ser revisada e **testada com testes automatizados** (§9) simulando usuários de ninhos diferentes — incluindo casos negativos (usuário tenta acessar dado de outro ninho).
- Edge Functions que recebem `environment_id` como parâmetro **devem revalidar** se o `auth.uid()` é membro daquele ninho antes de executar qualquer ação. Nunca confiar no input do cliente.

### 7.2. Autenticação e Sessão
- Tokens JWT do Supabase com expiração curta + refresh seguro.
- Logout invalida sessão localmente e no servidor.
- Login social só via providers oficiais (Google/Apple) — não implementar OAuth caseiro.

### 7.3. Convites
- Links de convite contêm token aleatório de **alta entropia** (mínimo 128 bits).
- Convites têm **expiração** (default 7 dias).
- Owner pode **revogar** convites pendentes.
- Convite usado é invalidado (one-time use por padrão; configurável para multi-uso com limite).
- Rate limit no endpoint de aceite de convite para mitigar enumeração.

### 7.4. Storage de Fotos
- Buckets do Supabase Storage com **policies de acesso** vinculadas ao `environment_id`.
- URLs de fotos **assinadas e com TTL curto** (não usar URLs públicas permanentes).
- Validação de tipo de arquivo (apenas imagens) e tamanho máximo no upload.
- Strip de metadados EXIF sensíveis (especialmente GPS) antes de armazenar.

### 7.5. Dados Pessoais e LGPD
- Dados sensíveis (e-mail, nome, foto de perfil) **nunca** logados em telemetria/Sentry.
- PII em logs deve ser mascarada/hasheada.
- Backups criptografados em repouso (padrão Supabase).
- Trilha de auditoria para ações sensíveis (mudança de ownership, deleção de conta, exportação de dados).

### 7.6. IA / Prompt Injection
- Inputs de usuário que entram em prompts da IA (nomes de cômodos, descrições de tasks, nomes de moradores) devem ser **tratados como não-confiáveis**.
- Prompt template separa claramente instruções do sistema (estáticas) de dados do usuário (variáveis), reduzindo superfície de injeção.
- Saída da IA nunca executada como código nem usada para tomar decisões de autorização — apenas para gerar conteúdo (tasks sugeridas, mensagens, resumos), sempre revisável pelo usuário.
- Rate limit nas chamadas à Claude API por usuário/ninho para evitar abuso e custo descontrolado.

### 7.7. Segredos e Configuração
- **Nenhum segredo no repositório.** Use variáveis de ambiente e secret managers (Supabase Vault, GitHub Secrets, etc.).
- Chaves de API (Claude, Firebase, etc.) **nunca** embarcadas no cliente Flutter — sempre via Edge Function intermediadora.
- Rotação periódica de chaves documentada.

### 7.8. Notificações Push
- Conteúdo da notificação **não pode vazar PII** de outros moradores além do necessário (ex.: "Marina concluiu Aspirar a sala" é ok dentro do ninho; nunca enviar dados de um ninho para o device de um usuário que não é membro).
- Tokens FCM/APNs invalidados no logout e na remoção do app.

### 7.9. Dependências
- **Dependabot/Renovate** ativo no repositório.
- Revisão obrigatória antes de adicionar dependência nova (licença, manutenção, surface).
- `pubspec.lock` e `package-lock.json` versionados.

### 7.10. Modelo de Ameaças (resumo)
Ameaças prioritárias a mitigar no MVP:
1. **Vazamento entre ninhos** (RLS mal configurada) — mitigação: §7.1.
2. **Sequestro de ninho por convite vazado** — mitigação: §7.3.
3. **Acesso indevido a fotos** — mitigação: §7.4.
4. **Prompt injection na IA gerando conteúdo malicioso ou caro** — mitigação: §7.6.
5. **Escalada de privilégio** (member virando owner sem autorização) — mitigação: testes em §9 + revisão de RLS.

---

## 8. Testes

> **Para Claude:** código sem teste é código incompleto. Toda PR deve incluir testes para o que foi adicionado/modificado. Se um teste é difícil de escrever, isso é sinal de que o design precisa mudar — não de que o teste pode ser pulado.

### 8.1. Pirâmide de Testes

```
        /\
       /  \    E2E (poucos, fluxos críticos)
      /----\
     /      \  Integração (RLS, Edge Functions, IA)
    /--------\
   /          \ Unitários (lógica de domínio, widgets)
  /------------\
```

### 8.2. Mobile (Flutter)
- **Unitários** (`flutter_test`): lógica de domínio pura (cálculo de poeira, regras de streak, validações, formatação de datas/fusos).
- **Widget tests**: cada tela crítica tem teste de renderização e interação principal (login, criar task, concluir task, ver feed).
- **Golden tests** para componentes-chave do design (vindos do Stitch) — detectam regressão visual.
- **Integration tests** (`integration_test`) para fluxos críticos: onboarding completo, conclusão de task com foto, transferência de task.
- **Mocks** para Supabase e Claude API — testes não dependem de rede.

### 8.3. Backend (Edge Functions / Postgres)
- **Testes de RLS**: para cada tabela com RLS, suíte que simula usuários de **ninhos diferentes** e verifica isolamento (positivo e negativo). Isso é **obrigatório** — sem isso, a PR não passa.
- **Testes de Edge Functions** (Deno test): inputs válidos, inválidos, malicasos, casos de borda (fuso, virada de dia, freeze esgotado, etc.).
- **Testes de migrations**: cada migration tem rollback testado.
- **Testes de jobs cron**: lógica de streak à meia-noite, geração de resumo semanal, etc., com clock mockado.

### 8.4. IA / Agentes
- **Testes de prompt**: snapshot dos prompts montados a partir de templates + dados — qualquer mudança não-intencional aparece no diff.
- **Eval suite**: conjunto de casos (ninho com X cômodos / Y moradores / histórico Z) com expectativas qualitativas — verifica regressão de qualidade quando o prompt muda.
- **Testes de segurança de prompt**: inputs maliciosos (tentativas de prompt injection em nomes de cômodos/tasks) **não** devem fazer a IA quebrar o tom, vazar instruções de sistema ou gerar conteúdo fora do escopo.

### 8.5. Segurança
- **Testes negativos de autorização**: para cada endpoint/policy, ao menos um teste que tenta acessar como usuário não autorizado e espera **falha**.
- **Linter de segurança**: análise estática (ex.: `dart analyze`, `deno lint`, regras customizadas) bloqueando padrões perigosos (logs com PII, queries sem RLS, etc.).
- **Revisão manual obrigatória** em PRs que tocam: RLS, Edge Functions com `service_role`, fluxo de convite, autenticação, prompts de IA.

### 8.6. CI/CD
- Pipeline executa: lint → unit tests → widget tests → integration tests → testes de backend/RLS → build.
- **PR não merge sem CI verde.**
- Cobertura mínima sugerida: **70% global**, **90% em módulos de segurança** (auth, RLS, convites, ownership).
- Smoke test em ambiente de staging antes de release para produção.

### 8.7. QA Manual
- Checklist de release com fluxos críticos verificados em device real (iOS + Android) antes de cada publicação na store.
- Teste de aceitação visual contra o **Stitch** (paridade de design).

---

## 9. Modelo de Dados (Esboço Inicial)

> Esquema inicial sujeito a refinamento. Todas as tabelas com RLS por `environment_id` quando aplicável. *(O termo técnico no banco permanece `environment` para evitar reescrita; a UI/copy usa "ninho".)*

- **users** — perfil do usuário (vinculado a `auth.users` do Supabase).
- **environments** — ninho, com `owner_id`, `timezone`, configurações (ex.: `transfer_item_enabled`, `vacation_mode`).
- **environment_members** — relação N:N entre `users` e `environments`, com `role` (`owner`/`member`), `joined_at`, `left_at`.
- **rooms** — cômodos, ligados a `environment_id`, com `name`, `size_category` (P/M/G), `photo_url`.
- **tasks** — task com `environment_id`, `room_id`, `assignee_id`, `difficulty`, `start_date`, `recurrence_rule` (RRULE).
- **task_completions** — registro de conclusão, com `completed_by`, `completed_at`, `photo_url`.
- **task_transfers** — histórico de transferências (origem, destino, semana ISO).
- **streaks** — snapshot diário; chaves separadas para streak de usuário e de ninho, com contador de freezes restantes no mês.
- **dust_ledger** — entradas/saídas de poeira na pá por usuário (auditável).
- **feed_events** — eventos do feed (conclusão de task, foto, conquista, morador novo).
- **notification_log** — registro de notificações enviadas/suprimidas (para auditoria e antiabuso).
- **invites** — tokens de convite com `environment_id`, `token_hash`, `expires_at`, `used_at`, `revoked_at` (ver §7.3).
- **audit_log** — trilha de ações sensíveis (mudança de ownership, deleção de conta, exportações).

---

## 10. MVP vs. Futuro

### MVP (v1) — Ninho 1.0
- Login Google/Apple
- Cadastro de ninho (até 2 pessoas) + cômodos
- Convite via QR Code e link (com expiração e revogação)
- Tasks manuais **e** geração inicial via IA
- Conclusão de task com foto opcional
- Push notifications 3x/dia com tom personalizado por IA
- Streak individual e de ninho (com 2 freezes/mês)
- Loja com 1 item: Transferência de Task
- Feed do ninho + resumo semanal por IA
- pt-BR + en
- Compliance LGPD básica
- Segurança baseline (§7) + testes baseline (§8)

### v2 e além
- Mais moradores por ninho (planos premium)
- Feed geral com interações entre ninhos
- Novos itens na loja (freeze extra, skip, cosméticos)
- Conquistas/badges
- Estatísticas e relatórios mensais
- Integrações (calendário, assistentes de voz)
- Idiomas adicionais (es, fr)

---

## 11. Métricas de Sucesso

- **Ativação:** % de usuários que completam o cadastro de ninho e convidam ao menos 1 pessoa.
- **Engajamento:** DAU/MAU, % de tasks concluídas no dia, streak médio por ninho.
- **Retenção:** D1, D7, D30.
- **IA:** taxa de aceitação das tasks geradas pelo agente; CTR/abertura das notificações personalizadas.
- **Saúde da comunidade:** ninhos com 100% das tasks concluídas na semana.
- **Qualidade técnica:** % de cobertura de testes, número de incidentes de segurança, MTTR.

---

## 12. Princípios de Design

- **Pacificador antes de gamificado.** O streak é incentivo, não punição pública.
- **Transparência.** Toda transferência, conclusão e mudança de papel é visível no feed/log.
- **Privacidade por padrão.** Conteúdo do ninho nunca vaza para fora dele no MVP.
- **IA com personalidade, não genérica.** Mensagens devem refletir o contexto real do ninho.
- **Multi-tenant via RLS.** Toda query passa por isolamento de ninho; nunca confiar só na camada de app.
- **Design vem do Stitch.** Implementação espelha o design; agente não inventa UI.
- **Segurança e testes não são extras.** Toda feature nasce com ambos.

---

## 13. Como Usar Este Documento

Em sessões com Claude Code, Devin, Cursor ou similares:

1. Inclua este `IDEA.md` no contexto inicial.
2. Referencie seções específicas ao pedir implementação (ex.: "implementar §5.7 — Streak").
3. **Antes de implementar uma tela**, peça/forneça o link do Stitch (§2).
4. **Toda PR deve incluir testes** correspondentes (§8) e considerar as diretrizes de segurança (§7).
5. Quando uma decisão da §5 for alterada, atualize o documento antes de pedir nova implementação para evitar deriva.
6. Mantenha §10 atualizada para refletir o escopo real do MVP em construção.

---

## 14. Checklist Rápido para o Agente

Antes de começar qualquer task de implementação, Claude (e outros agentes) devem confirmar:

- [ ] Li a seção do IDEA.md correspondente à feature.
- [ ] Identifiquei a(s) tela(s) no mapa do §4.4.
- [ ] Tenho o link/export do Stitch para a tela (ou sinalizei que falta).
- [ ] Considerei as diretrizes de segurança aplicáveis (§7).
- [ ] Planejei os testes que vou escrever (§8).
- [ ] Usarei "Ninho" e os termos do glossário (§3) na UI e copy.
- [ ] Sinalizarei qualquer trade-off ou dúvida em vez de assumir silenciosamente.
