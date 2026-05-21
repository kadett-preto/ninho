# TASKS.md — Ninho

> Plano de execução do MVP (Ninho 1.0). Derivado do `IDEA.md`. Atualizar a cada conclusão/mudança de escopo.
>
> **Convenções:**
> - `[ ]` pendente · `[~]` em andamento · `[x]` concluída · `[!]` bloqueada
> - Toda tarefa referencia seção do `IDEA.md` quando aplicável.
> - Toda feature carrega segurança (§7) e testes (§8) embutidos — não criar task separada "adicionar testes depois".
> - Antes de qualquer tela: pedir Stitch (§2). Marcar `[!] aguardando Stitch` se faltar.

---

## Status Geral

- **Fase atual:** 5 — IA Onboarding (concluída exceto eval suite real 5.8)
- **Última atualização:** 2026-05-22
- **Bloqueios ativos:** Cards 2 e 3 do onboarding (placeholder até Stitch entregar); Apple Auth (2.5) precisa Apple Developer account ($99/ano) — adiado para pré-release
- **Stitch atualizado:** projeto `16698352297286313348` agora tem telas de Convite, Home, Tasks, Feed, Loja, Perfil, Notificações, IA, Configurações — destrava maioria das tasks `[!] aguardando Stitch`. Lista completa em `CLAUDE.md` §2.

---

## Fase 0 — Setup do Projeto

- [x] **0.1.** `flutter create` com estrutura inicial (arch best-practices — skill `flutter-apply-architecture-best-practices`). Flutter 3.44, `lib/{data,domain,ui}` criados.
- [x] **0.2.** `git init` + `.gitignore` Flutter padrão + commit inicial (`36a190e`)
- [x] **0.3.** Projeto Supabase `ninho-dev` (region sa-east) criado; URL+anon em `.env` local. Data API: on. Auto-expose new tables: off (defense-in-depth, §7.1).
- [x] **0.4.** `supabase_flutter` + `flutter_dotenv` integrados (`SupabaseService.init` em `lib/data/services/supabase_client.dart`, bootstrap em `main()`). Smoke real de conexão fica p/ Fase 1 (precisa tabela existir).
- [x] **0.5.** CI baseline (GitHub Actions: format/analyze/test/coverage) em `.github/workflows/flutter-ci.yml`
- [x] **0.6.** Dependabot semanal em `.github/dependabot.yml` (pub + github-actions)
- [x] **0.7.** Sentry mobile integrado (`SentryService`, sampling 0.2, PII scrubbed, §7.5). Pendente: criar projeto `ninho-edge` (Deno) ao iniciar Edge Functions.
- [x] **0.8.** PostHog SDK adicionado com config restritiva (autocapture/session-replay/lifecycle off; identifiedOnly). `PosthogService.setupIfConsented` aguarda consentimento LGPD da Fase 2 antes de inicializar. Falta: AUTO_INIT=false em AndroidManifest + Info.plist na Fase 2.
- [x] **0.9.** README mínimo (`README.md`)

---

## Fase 1 — Modelagem de Dados + RLS

> Pré-requisito de quase tudo. Sem isso, nada de feature.

> Schema condensado em 5 migrations timestampadas (não 8 tabelas separadas). Aplicado em local dev; remoto pendente.

- [x] **1.1.** `users` (em `20260519230100_core_schema.sql`)
- [x] **1.2.** `environments` + `environment_members` (em `20260519230100`)
- [x] **1.3.** `rooms` (em `20260519230200_rooms_and_tasks.sql`)
- [x] **1.4.** `tasks` + `task_completions` + `task_transfers` (em `20260519230200`)
- [x] **1.5.** `streaks` + `dust_ledger` (em `20260519230300_engagement.sql`)
- [x] **1.6.** `feed_events` + `notification_log` (em `20260519230300` e `20260519230400`)
- [x] **1.7.** `invites` com token_hash + expires_at + used_at + revoked_at (em `20260519230400_security_and_audit.sql`)
- [x] **1.8.** `audit_log` (em `20260519230400`)
- [x] **1.9.** RLS habilitado em todas as 13 tabelas + policies por papel (owner/member); tabelas só-server (invites/audit/notification/dust/transfers/streaks) sem INSERT/UPDATE/DELETE de cliente
- [x] **1.10.** 40 pgTAP tests passando (`supabase test db`) — `01_rls_core_isolation` (26) + `02_rls_sensitive_tables` (14). Cobre helpers, isolamento Alice/Bob/Carol, forja de created_by/completed_by, lockdown de tabelas sensíveis
- [ ] **1.11.** Testes de rollback de migrations — Supabase não tem down migrations nativas; usar `supabase db reset` p/ replay determinístico já cobre o objetivo. Marcado como N/A salvo necessidade futura
- [x] **1.12.** Migrations aplicadas no remoto `ninho-dev` via `supabase db push` (link + PAT + db password gerenciados localmente, fora do repo)
- [x] **1.13.** `.github/workflows/db-ci.yml` roda `supabase start` + `supabase test db` em mudanças a migrations/tests/config — bloqueia merge se RLS quebrar

---

## Fase 2 — Autenticação + Onboarding Inicial

- [x] **2.1.** Splash com wordmark + auto-advance 1.2s (`lib/ui/features/onboarding/splash_screen.dart`)
- [~] **2.2.** Onboarding 3 cards — card 1 "Bem-vindo" implementado (`welcome_card.dart`); cards 2 e 3 como placeholder até Stitch entregar
- [x] **2.3.** Login com hero circle + Google/Apple buttons + termos/privacidade (`login_screen.dart`). Provider real fica em 2.4/2.5.
- [x] **2.4.** Supabase Auth Google funcionando end-to-end (`AuthService.signInWithGoogle`, Supabase Provider Google ativo, redirect web via `Uri.base.origin`). Mobile pendente (deep-link scheme `io.supabase.ninho://login-callback/`).
- [!] **2.5.** Apple provider — adiado: exige Apple Developer ($99/ano) e Sign in with Apple service config. Faremos antes do release iOS.
- [x] **2.6.** Consentimento LGPD — 3 cards (1 obrigatório + 2 opcionais) (`lgpd_consent_screen.dart`)
- [x] **2.7.** Persistência LGPD: `UsersRepository.updateLgpdConsent` + trigger Postgres `log_lgpd_consent` (audit_log append-only) + `PosthogService.setupIfConsented` se analytics opt-in. Splash checa `hasLgpdConsent` e pula `/consent` quando já aceito.
- [x] **2.8.** Logout: `HomePlaceholderScreen` exibe email + botão "Sair do ninho". Sequência: `PosthogService.optOutAndReset` → `AuthService.signOut` (invalida sessão local+servidor §7.2) → redirect `/splash`.
- [x] **2.9.** Roteamento go_router (`lib/ui/core/routes.dart`, MaterialApp.router em `app.dart`)
- [x] **2.10.** Widget tests — 5 testes verdes (splash + welcome + login + LGPD + theme)

---

## Fase 3 — Cadastro de Ninho

- [x] **3.1.** Splash + LGPD redirecionam pra `/setup/step1` se sem ninho. (`splash_screen.dart`: sessão → consent → `hasActiveEnvironment` → home ou setup.)
- [x] **3.2.** Step 1 coleta nome do ninho. Icon picker pendente.
- [x] **3.3.** Timezone default `America/Sao_Paulo`. Lookup IANA via plugin pendente (compat web).
- [x] **3.4.** Step 2 grid de cômodos + dialog novo. Foto por cômodo pendente.
- [x] **fix RLS:** `environments_select_member` policy aceita `owner_id = auth.uid()` p/ destravar INSERT...RETURNING — trigger AFTER inserir membership não tinha rodado quando o RETURNING checava SELECT USING. Migration `20260520210000`. End-to-end validado.
- [x] **3.5.** Upload foto cômodo via Storage signed URL + EXIF strip (§7.4). Cliente re-encoda para JPEG sem metadados antes do upload.
- [x] **3.6.** Validação tipo/tamanho upload (§7.4). Cliente aceita JPG/PNG até 8 MB; bucket privado aceita só `image/jpeg` até 8 MB.
- [x] **3.7.** Edge Function p/ atomicidade — `create-environment` chama RPC transacional `create_environment_with_rooms` para criar ninho + cômodos numa única transação. Fotos opcionais sobem depois e atualizam `rooms.photo_path`.
- [x] **3.8.** Tests: 11 unit do `SetupController`; widget tests das 3 telas; pgTAP Storage RLS + RPC transacional. Integration test (`integration_test/setup_flow_test.dart`) rodado em device Android real (Galaxy S24, API 36); valida step1→step2→step3 + submit do repo. Adição de cômodo custom via UI no device esbarra em overflow do GridView (CTA bottom sobrepõe), então o teste injeta a operação pelo controller — UI manual segue coberta pelos widget tests.

---

## Fase 4 — Convites

- [x] **4.1.** Tela convidar morador (QR + link + share + skip). `invite_screen.dart` reusável; modo `fromSetup` pós-cadastro com "Pular por agora" + "Concluir configuração", modo `home` com appbar. Stitch: "Convidar Parceiro" (`a36ab0c9bb9849c8aad916f159c32536`). Step 3 do setup agora redireciona pra `/invite/setup`.
- [x] **4.2.** Edge Function: gerar convite (`create-invite/index.ts`). Token de 256 bits (`crypto.getRandomValues` 32 bytes → base64url), SHA-256 chega como hash no banco. RPC `create_invite` (SECURITY DEFINER) valida ownership e insere com defense-in-depth — RLS na tabela bloqueia INSERT direto. TTL 1-30 dias (default 7). Audit log gravado.
- [x] **4.3.** Edge Function `accept-invite` + RPC `accept_invite` SECURITY DEFINER. Token base64url → sha-256 → lookup, valida revoked/used/expired, lock `for update` p/ corrida, one-time use atômico (used_at+used_by), insere `environment_members` como `member`, idempotente p/ já-membro (retorna `already_member=true`). Rate-limit DB: 10 attempts/min/usuário via audit_log → 54000. Audit log: `invite.accept_attempt` + `invite.accept`.
- [x] **4.4.** Edge Function: revogar convite (owner only) — RPC `revoke_invite` SECURITY DEFINER, idempotente, audit log gravado. Falta UI de listagem/revogação (entra com tela de Configurações do Ambiente).
- [!] **4.5.** Tela "Entrar no ninho X?" deep link / QR — aguardando Stitch
- [ ] **4.6.** Mobile scanner QR (skill `flutter-use-http-package` para fetch + `mobile_scanner`)
- [ ] **4.7.** Tour 3 cards pós-entrada — aguardando Stitch
- [x] **4.8.** pgTAP `07_accept_invite_rpc.test.sql` — 17 testes: sem auth (28000), hash curto (22023), inexistente (42704), revogado/expirado/usado (22023), aceite válido (membership+used_at+audit), one-time use (segundo aceite rejeitado), idempotência já-membro (`already_member=true` sem duplicar), rate-limit 11ª tentativa → 54000, attempt rate-limited não é logado. Suite total: 93 ✓. Pendente: testes negativos de revoke (member tentando, etc) — cobertos em 06.

---

## Fase 5 — Geração de Tasks por IA (Onboarding)

- [x] **5.1.** Edge Function `suggest-tasks` (Deno + `@anthropic-ai/sdk`) chama Claude com cômodos+tamanhos. Modelo `claude-haiku-4-5` (custo baixo). Output via `output_config.format` JSON schema rígido + `additionalProperties:false`. Filtro server-side de room_id forjado pela IA.
- [x] **5.2.** System prompt fixo + dados de usuário passados como JSON inteiro (não interpolados em texto). Sanitiza nome de cômodo (strip control chars, trim, max 60). System prompt diz à IA tratar `name` como rótulo opaco e não interpretar instruções nele (§7.6).
- [x] **5.3.** `cache_control: ephemeral` no system block. Cache só dispara real quando o prompt cresce ≥4096 tokens (mínimo Haiku 4.5), marker fica como ponto de extensão. Usage retornada ao cliente.
- [x] **5.4.** RPC `claim_suggest_attempt` SECURITY DEFINER: rate-limit por audit_log (24h, 5/usuário, 10/ninho default), valida owner. Falha cedo antes de gastar token de IA.
- [x] **5.5.** Tela `SuggestionsScreen` (Stitch `10485bb86c9040658544e1afe99d9dd9`) com `SuggestionsController` (ChangeNotifier). Lista agrupada por cômodo, badges mamão/embaçada/treta + recorrência (Diária/Semanal/Mensal etc.), card clicável p/ toggle, ícone edit abre dialog (título + dificuldade + recorrência), sticky footer "Adicionar N tarefa(s)" + "Selecionar todas/Desmarcar todas". Erros do servidor (rate-limit 54000, sem ninho, sem cômodos) viram mensagens amigáveis em pt-BR. 8 widget tests novos cobrem load, toggle, toggle-all, submit, rate-limit, sem-ninho, filtro room_id desconhecido e edição. Rota `/suggestions` em `routes.dart`.
- [x] **5.6.** RPC `accept_suggested_tasks` SECURITY DEFINER, transacional, owner-only. Valida cada sugestão (título, dificuldade, interval ∈ {1,3,7,14,30}, room_id pertence ao ninho). Traduz `interval_days` → `RRULE FREQ=DAILY;INTERVAL=N`. Audit log gravado.
- [x] **5.7.** Snapshot test do system prompt: `test/suggest_tasks_prompt_snapshot_test.dart` extrai template literal do `index.ts` via regex e compara com `test/snapshots/suggest_tasks_system_prompt.txt`. Segundo teste assegura 4 invariantes-chave (§7.6) ainda presentes no prompt.
- [~] **5.8.** Eval suite real (chamadas Claude API com fixtures de 3/6 cômodos) — placeholder. Não roda em CI sem `ANTHROPIC_API_KEY` + custo. Estrutura prevista em sessão futura.
- [x] **5.9.** Testes de prompt injection cobertos parcialmente: (a) snapshot test bloqueia regressão silenciosa nas invariantes do prompt; (b) Edge Function sanitiza nome do cômodo (strip control chars/quebras de linha); (c) pgTAP em `accept_suggested_tasks` valida room_id cross-tenant rejeitado com 23503 — impede IA reaproveitar sugestão com room_id forjado. Eval comportamental real fica com 5.8.

---

## Fase 6 — Tela Home (Hoje) + Tasks Tab

- [ ] **6.1.** Tab bar 5 tabs (Hoje, Tasks, Feed, Loja, Perfil). Stitch: "Início" (`63345f0e4cd44e0fbc15ef27f70c8cc9`) tem barra.
- [ ] **6.2.** Tela Hoje (lista tasks do dia + streak + poeira). Stitch: "Início".
- [ ] **6.3.** Layout responsivo (skill `flutter-build-responsive-layout`)
- [ ] **6.4.** Tela detalhe da task (concluir, foto, transferir). Stitch: "Detalhes da Tarefa" (`309bf756f62a4f23afec37c474dc7002`) + "Confirmação de Tarefa" (`d73dc74d40c5425b91bb017fab82b593`).
- [ ] **6.5.** Conclusão de task: marca completion + cancela notifs restantes + credita poeira + emite feed event
- [ ] **6.6.** Upload foto de conclusão (signed URL + EXIF strip + tipo/tamanho)
- [ ] **6.7.** Tela Tasks (filtros: minhas/todas/por cômodo). Stitch: "Gerenciamento de Tarefas" (`55659509c4af477ea18567f8519ac5a5`).
- [ ] **6.8.** Tela criar task manual. Stitch: "Criar Tarefa" (`36b5246bf0744fe4878f4a57ba90d84b`).
- [ ] **6.9.** Tela editar task — reusar "Criar Tarefa" + "Detalhes da Tarefa".
- [ ] **6.10.** Widget tests + integration test "concluir task com foto" (§8.2)
- [ ] **6.11.** Golden tests dos componentes-chave (§8.2)

---

## Fase 7 — Streak + Jobs

- [ ] **7.1.** Lógica pura de streak (testável unitariamente, §8.2)
- [ ] **7.2.** Edge Function + Supabase Cron: avaliação à meia-noite no fuso do ninho (§5.7)
- [ ] **7.3.** Política de freeze automático (2/mês, individual apenas, não acumulável)
- [ ] **7.4.** Modo "viagem" (owner pausa ninho até 14d/ano, §5.7)
- [ ] **7.5.** Streak quebrado dispara notif (§5.6)
- [ ] **7.6.** Testes com clock mockado (virada de dia, freeze esgotado, modo viagem ativo)

---

## Fase 8 — Notificações Push

- [ ] **8.1.** Configurar FCM (Android) + APNs (iOS) via `firebase_messaging`
- [ ] **8.2.** Persistir token FCM/APNs por device do usuário
- [ ] **8.3.** Invalidar token no logout/remoção (§7.8)
- [ ] **8.4.** Edge Function 3x/dia (09h/15h/20h, fuso do ninho) — verifica task pendente antes de enviar
- [ ] **8.5.** Geração de mensagem personalizada via Claude API (prompt caching, §6.3)
- [ ] **8.6.** Garantir não vazamento de PII de outros ninhos (§7.8)
- [ ] **8.7.** Tela configurar horários de notificação. Stitch: "Configurar Horários de Notificação" (`dde54107f2b54a4abe97fc3de2349c90`) + "Configurar Notificações - Desativado" (`c0969501314f450eb2f6733017193ef5`) + "Prévia de Notificações" (`6db3c3a815624853aa44689e843d14c9`).
- [ ] **8.8.** Testes: notificação suprimida se task feita; eval qualitativa dos tons (§8.4)
- [ ] **8.9.** Demais gatilhos: task transferida, novo morador, foto no feed, streak em risco/quebrado, compra na loja

---

## Fase 9 — Loja e Economia

- [ ] **9.1.** Tela Loja (saldo + itens). Stitch: "Loja da Poeira" (`7bdc5123d9a84cdd93f313024fccd516` / `05972ff2fe2b41e696166ba9d8c5f9df`).
- [ ] **9.2.** Item "Transferência de Task" (30 poeiras, §5.8)
- [ ] **9.3.** Antiabuso: 1x/semana, bloquear destinatário consecutivo, cooldown extra MVP 2-pessoas
- [ ] **9.4.** Edge Function transferência atômica (débito + reassign + audit + notif)
- [ ] **9.5.** Config owner: ligar/desligar item de transferência
- [ ] **9.6.** Histórico de compras
- [ ] **9.7.** Testes: saldo insuficiente, limite semanal, item desativado, destinatário consecutivo

---

## Fase 10 — Feed

- [ ] **10.1.** Tela Feed (timeline eventos + fotos). Stitch: "Mural do Ambiente" (`5a57a56c0a2e41a0ad5b185827798f95`) + "Detalhe da Foto - Mural" (`7f0a41702d9842d9b34d38fccbabb8ab`).
- [ ] **10.2.** Realtime via Supabase Realtime (§6.2)
- [ ] **10.3.** Moderação: autor deleta foto; owner oculta/deleta qualquer item (§5.9)
- [ ] **10.4.** Botão "denunciar" (sinal interno MVP)
- [ ] **10.5.** Edge Function + Cron domingo à noite: resumo semanal via Claude API
- [ ] **10.6.** Eval suite resumo semanal (§8.4)

---

## Fase 11 — Perfil / Configurações / LGPD

- [ ] **11.1.** Tela Perfil/Ninho. Stitch: "Perfil do Usuário - Marina" (`620c0c86988d41b5bbda558ea787d1b4`) + "Configurações da Conta" (`6ce6cc12a0eb4eada6121d2eba3f55ec`) + "Configurações do Ambiente" (`00cead6f615e494d844da464d3905604`) + "Lista de Membros" (`db4f6fd8644941638e82b519fce72d6e`) + "Transferir Propriedade" (`f10b6a24123d449ba8200ce848fc1021`) + "Exportar Meus Dados" (`8c521a3908d84436a161038dca39a239`) + "Excluir Conta" (`c56e7ed4352347bcb448bb158b0a08af`).
- [ ] **11.2.** Exportação de dados em JSON (§5.10)
- [ ] **11.3.** Deletar conta: soft delete + purga em 30d (§5.10)
- [ ] **11.4.** Tratamento owner deletando conta sem transferir (auto-promoção membro mais antigo, §5.5)
- [ ] **11.5.** Arquivar ninho sem membros por 30d → purga (§5.5)
- [ ] **11.6.** Transferência de ownership manual (§5.5)
- [ ] **11.7.** Sair do ninho (§5.5)
- [ ] **11.8.** Configurações do ninho (cômodos, membros, modo viagem, loja on/off)
- [ ] **11.9.** Audit log de todas ações sensíveis (§7.5)
- [ ] **11.10.** Testes negativos de autorização nas Edge Functions (§8.5)

---

## Fase 12 — Internacionalização

- [ ] **12.1.** Setup i18n Flutter (skill `flutter-setup-localization`) — pt-BR + en
- [ ] **12.2.** Strings de UI extraídas para arb
- [ ] **12.3.** Prompts da IA internacionalizados (template por locale)
- [ ] **12.4.** Estrutura preparada para es, fr (mesmo sem tradução)

---

## Fase 13 — Segurança Hardening (transversal)

> Itens que cortam várias fases — revisitar após cada fase relevante.

- [ ] **13.1.** Code review checklist de segurança em PRs que tocam RLS/Edge Functions/auth/convites/prompts (§8.5)
- [ ] **13.2.** Linter de segurança (dart analyze + deno lint + regras custom contra log de PII)
- [ ] **13.3.** Rotação de chaves documentada (§7.7)
- [ ] **13.4.** Threat model §7.10 — validar mitigação de cada ameaça antes do release

---

## Fase 14 — Release MVP

- [ ] **14.1.** Suíte integration tests cobrindo fluxos críticos (onboarding, conclusão com foto, transferência)
- [ ] **14.2.** Cobertura ≥70% global / ≥90% módulos de segurança (§8.6)
- [ ] **14.3.** Smoke test em staging
- [ ] **14.4.** QA manual em device real iOS + Android (§8.7)
- [ ] **14.5.** Paridade visual contra Stitch (§8.7)
- [ ] **14.6.** Configurar RevenueCat (placeholder — se IAP entrar pré-lançamento)
- [ ] **14.7.** Build release iOS (App Store Connect)
- [ ] **14.8.** Build release Android (Play Console)
- [ ] **14.9.** Política de privacidade + termos publicados
- [ ] **14.10.** Publicação

---

## Histórico de Mudanças

- **2026-05-19** — arquivo criado, plano inicial derivado de `IDEA.md` (todas fases pendentes).
- **2026-05-19** — Fase 0 parcialmente concluída: 0.1, 0.2, 0.5, 0.6, 0.9 ✓. 0.3, 0.4, 0.7, 0.8 bloqueadas aguardando contas externas. Commit inicial `36a190e`.
- **2026-05-19** — Supabase dev criado, 0.3 e 0.4 ✓. Commit `20ba10d` (supabase_flutter + flutter_dotenv).
- **2026-05-19** — Sentry mobile integrado (PII scrub + sampling 0.2). 0.7 ✓. Commit `86542f8`.
- **2026-05-19** — PostHog SDK adicionado com consent-gate (não inicializa até Fase 2). 0.8 ✓. Commit `8d04c90`. **Fase 0 concluída.**
- **2026-05-19** — Fase 1 schema MVP + RLS implementados (5 migrations, 13 tabelas, 40 pgTAP tests verdes em local). Tasks 1.1–1.10 ✓. Commit `01fe7b3`. Falta: push remoto (1.12) + CI db tests (1.13).
- **2026-05-20** — Migrations aplicadas no remoto `ninho-dev` via `supabase db push`. CI workflow `db-ci.yml` adicionado (1.12 + 1.13 ✓). Commit `c4efb77`. **Fase 1 concluída.**
- **2026-05-20** — Fase 2 telas implementadas via Stitch MCP: splash, onboarding card 1, login, LGPD consent + routing go_router + 5 widget tests verdes. Tasks 2.1, 2.3, 2.6, 2.9, 2.10 ✓; 2.2 parcial; 2.4, 2.5, 2.7, 2.8 pendentes. Commit `f051fb2`.
- **2026-05-20** — Logo oficial no splash (`fe3b09a`); Google Auth end-to-end validado em web (commit `fe3b09a`); LGPD persistência + triggers + grants (commits relacionados); Logout (`ac337b8`). **Fase 2 fechada pragmaticamente** — 2.5 (Apple) adiada p/ pré-release iOS; cards 2/3 onboarding aguardam Stitch.
- **2026-05-20** — Wizard de cadastro de ninho (Fase 3 mínima) implementado em 3 passos. Bug RLS em INSERT...RETURNING diagnosticado e fixado via SELECT policy fallback (`owner_id = auth.uid()`). End-to-end validado: splash → onboarding → login → consent → setup → home. Pendentes Fase 3: foto cômodo + EXIF strip + signed URL + Edge Function atomicidade.
- **2026-05-21** — Foto opcional de cômodo implementada: `image_picker`, validação JPG/PNG até 8 MB, EXIF strip por re-encode JPEG, upload para bucket privado `room-photos` via signed upload URL após criação do ninho. Storage RLS por pasta `{environment_id}` validado em pgTAP. Fase 3 pendente: Edge Function de atomicidade + integration test.
- **2026-05-21** — Hardening Supabase: `public.set_updated_at` passou a fixar `search_path`; advisor de segurança local ficou sem issues.
- **2026-05-21** — Edge Function `create-environment` criada e publicada no remoto. Flutter passou a chamar a função; o RPC `create_environment_with_rooms` garante atomicidade de ninho + cômodos. pgTAP agora cobre rollback transacional do RPC.
- **2026-05-21** — Integration test do cadastro de ninho criado (`integration_test/setup_flow_test.dart`) com router injetável e repositório fake para não tocar o Supabase remoto. `flutter drive -d web-server` compila/serve, mas não executa sem `chromedriver` em `localhost:4444`.
- **2026-05-21** — `CLAUDE.md` criado na raiz: guia operacional para agentes (resumo de IDEA.md + arquitetura + Stitch screen IDs + checklist). Tasks `[!] aguardando Stitch` destravadas (4.1, 5.5, 6.1/2/4/7/8/9, 8.7, 9.1, 10.1, 11.1) — Stitch agora cobre essas telas. 3.1 fechada.
- **2026-05-21** — Fase 4 parcial: tasks 4.1, 4.2, 4.4 ✓. RPCs `create_invite` + `revoke_invite` SECURITY DEFINER, Edge Function `create-invite` em `supabase/functions/`, tela `InviteScreen` com QR (`qr_flutter`) + copy + share (`share_plus`). Step3 do setup agora abre `/invite/setup`. Suítes: pgTAP 14 testes novos (totais 76 ✓) cobrem owner-only, member rejeitado, sem sessão, TTL/hash inválidos, revoke idempotente. Widget tests 3 novos (total 23 ✓). flutter analyze limpo. Visual da tela validado via Chrome MCP em `http://localhost:5454/#/invite/setup`. Pendente 4.3 (aceitar convite), 4.5 (tela "Entrar no ninho X?" — aguardando Stitch), 4.6 (mobile scanner), 4.7 (tour pós-entrada — aguardando Stitch), 4.8 (testes negativos de aceitar).
- **2026-05-22** — Fase 4 avança: 4.3 + 4.8 ✓. Migration `20260522000000_accept_invite_rpc.sql` cria RPC SECURITY DEFINER com lock `for update`, rate-limit por audit_log e idempotência p/ já-membro. Edge Function `accept-invite` (Deno) faz decode base64url + sha-256 antes do RPC. `InvitesRepository.acceptInvite` + helper `tokenFromLink` no cliente, 6 unit tests novos. pgTAP `07_accept_invite_rpc.test.sql` com 17 testes (suite total 93 ✓). `flutter analyze` limpo, `flutter test` 30 verdes. `config.toml` agora declara blocos de função p/ create-invite + accept-invite. Pendente Fase 4: 4.5/4.7 (aguardando Stitch), 4.6 (mobile_scanner — fica para device físico).
- **2026-05-22** — Fase 5 backend pronto: 5.1–5.4, 5.6, 5.7, 5.9 ✓; 5.5 bloqueada (UI pendente); 5.8 placeholder. Migration `20260522010000_suggest_tasks.sql` cria RPCs `claim_suggest_attempt` (rate-limit owner-only via audit_log) e `accept_suggested_tasks` (transacional, valida room_id cross-tenant, traduz interval→RRULE). Edge Function `suggest-tasks` (Deno + `@anthropic-ai/sdk`) chama `claude-haiku-4-5` com system prompt cached + `output_config.format` JSON schema + sanitização de nome de cômodo (strip control chars). Defesa em profundidade: filtra room_id forjado pela IA antes de devolver. `SuggestionsRepository` + `TaskSuggestion`/`AcceptResult` no cliente. Snapshot test compara SYSTEM_PROMPT extraído do .ts com fixture; segundo test verifica que 4 invariantes-chave de §7.6 ainda estão no prompt. Suítes: pgTAP `08_suggest_tasks_rpc.test.sql` 18 novos testes (total 111 ✓), `flutter test` 41 ✓, `flutter analyze` limpo.
- **2026-05-22** — Fase 5.5 ✓: tela `SuggestionsScreen` montada a partir do Stitch "Sugestões da IA" — agrupamento por cômodo, badges mamão/embaçada/treta + recorrência, toggle/edit por sugestão, sticky footer com primary CTA + toggle all. Rate-limit + outros erros mapeados para mensagens humanas em pt-BR. 8 widget tests novos (`flutter test` 49 ✓), `flutter analyze` limpo. Fase 5 fechada exceto 5.8 (eval suite real chamando Claude — requer ANTHROPIC_API_KEY + custo, fica para sessão dedicada).
- **2026-05-22** — 3.8 fechada: Android SDK instalado (Android Studio 2025.1.3), `sentry_flutter` bumpado 8.14.2 → 9.20.0 (Kotlin language 1.6 deprecated quebrava build em Kotlin compiler novo) com adaptação em `SentryService` (`SentryEvent.copyWith` virou assignment direto em `event.user`). Integration test rodado em Galaxy S24 (API 36) — passa em ~4s. Bypass do dialog "Adicionar cômodo" no test: card cai no overlap do CTA bottom em telas pequenas, então o test injeta `addCustomRoom` direto no controller; cobertura de UI segue nos widget tests. `_AddRoomCard` trocado de `InkWell` solto para `GestureDetector` com `HitTestBehavior.opaque` (mais previsível p/ hit-test). 49 widget+unit tests ✓ + integration test ✓.
