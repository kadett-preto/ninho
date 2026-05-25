# CLAUDE.md — Ninho

> Guia operacional para agentes (Claude Code, Cursor, Devin) trabalhando neste repositório. Complementa o `IDEA.md` (fonte da verdade do produto) e o `TASKS.md` (estado atual do MVP). Quando este arquivo divergir do `IDEA.md`, o `IDEA.md` ganha — atualize este aqui também.

---

## 1. O que é Ninho

App mobile (Flutter + Supabase) para casais/colegas/famílias dividirem tarefas domésticas de forma justa e acolhedora. Tom **pacificador**, nunca punitivo. Detalhes completos: `IDEA.md` §0–§5.

Glossário rápido (`IDEA.md` §3):
- **Ninho** = espaço compartilhado (tabela `environments` no banco; UI sempre fala "ninho").
- **Cômodo** = `rooms`. Tamanho P/M/G + foto opcional.
- **Morador** = `users` membros do ninho. Papéis: `owner`/`member`.
- **Task** = `tasks`. Dificuldades: `mamão` / `embaçada` / `treta`.
- **Poeira na pá** = moeda interna (`dust_ledger`). Recompensa 5/15/40.
- **Streak** = sequência diária; por usuário e por ninho.

---

## 2. Design — Stitch + DESIGN.md

**Toda UI vem do Stitch.** Antes de implementar tela, sempre conferir:

- **Projeto Stitch:** `16698352297286313348` (Google Stitch — fonte da verdade visual).
- **`DESIGN.md`** (raiz do repo): tokens canônicos extraídos do Stitch — paleta "Harmonia Lar" (terracota/sage/sand/cream), tipografia Montserrat, spacing 8px, radius 24px em cards / 16px em botões. Esses tokens já estão refletidos em `lib/ui/core/{colors,typography,spacing,theme}.dart` — reutilizar, não duplicar.

**Telas disponíveis hoje no Stitch (use MCP `mcp__stitch__get_screen` para puxar HTML):**

| Tela | screenId |
|---|---|
| Bem-vindo (welcome) | `e0bf331d60d74733b78eda11d4066784` |
| Login | `da7482c384b3458691f90a0410263593` |
| Consentimento de Privacidade | `62ba94bf407a4ee99741805d3bf4edab` |
| Configurar Ambiente — Passo 1 | `b1f403ab07fb4f8fb897b569b9b35bca` |
| Configurar Ambiente — Passo 2 | `316955e4d6294c91b32a8c684fb6151e` |
| Configurar Ambiente — Passo 3 | `24ba2ea47dc049aebdef81bf729ea399` |
| Detalhes do Cômodo — Cozinha | `578c4ea8a2654b10b5accdb70cc81d44` |
| Sugestões da IA | `10485bb86c9040658544e1afe99d9dd9` |
| Convidar Parceiro | `a36ab0c9bb9849c8aad916f159c32536` |
| Aceitar Convite (Convite com Logo Animado) | `14083929657446416935` |
| Convite Expirado | `18283400647997996900` |
| Início (Home) | `63345f0e4cd44e0fbc15ef27f70c8cc9` |
| Gerenciamento de Tarefas | `55659509c4af477ea18567f8519ac5a5` |
| Criar Tarefa | `36b5246bf0744fe4878f4a57ba90d84b` |
| Detalhes da Tarefa | `309bf756f62a4f23afec37c474dc7002` |
| Confirmação de Tarefa | `d73dc74d40c5425b91bb017fab82b593` |
| Mural do Ambiente (Feed) | `5a57a56c0a2e41a0ad5b185827798f95` |
| Detalhe da Foto — Mural | `7f0a41702d9842d9b34d38fccbabb8ab` |
| Loja da Poeira | `7bdc5123d9a84cdd93f313024fccd516` / `05972ff2fe2b41e696166ba9d8c5f9df` |
| Perfil do Usuário — Marina | `620c0c86988d41b5bbda558ea787d1b4` |
| Configurações da Conta | `6ce6cc12a0eb4eada6121d2eba3f55ec` |
| Configurações do Ambiente | `00cead6f615e494d844da464d3905604` |
| Lista de Membros | `db4f6fd8644941638e82b519fce72d6e` |
| Gerenciar Cômodos | `85eaccfbc93d413d80f37d7471cb5ff4` |
| Configurar Horários de Notificação | `dde54107f2b54a4abe97fc3de2349c90` |
| Configurar Notificações — Desativado | `c0969501314f450eb2f6733017193ef5` |
| Prévia de Notificações | `6db3c3a815624853aa44689e843d14c9` |
| Transferir Propriedade | `f10b6a24123d449ba8200ce848fc1021` |
| Exportar Meus Dados | `8c521a3908d84436a161038dca39a239` |
| Excluir Conta | `c56e7ed4352347bcb448bb158b0a08af` |
| Streak Pessoal Animado | `bce605e4f31b474b855da413b961c168` |
| Streak do Ambiente Animado | `9901241b817b41bdb50d262854b5539e` |

Se uma tela do `IDEA.md` §4.4 não está aqui, **sinalizar** ao usuário em vez de inventar UI.

**Workflow para implementar tela:**
1. `mcp__stitch__get_screen` → HTML do screenId acima.
2. Extrair estrutura/spacing; mapear cores/tipografia para tokens já em `lib/ui/core/`.
3. Implementar em `lib/ui/features/<feature>/` espelhando o Stitch.
4. Onde Flutter limitar (animação, a11y), comentar curto + sinalizar.

---

## 3. Arquitetura do código

```
lib/
  data/
    repositories/   # acesso a tabelas Supabase + Edge Functions
    services/       # supabase_client, auth, sentry, posthog, room_photo
  domain/
    models/         # tipos puros (Room, RoomSize, RoomPhotoDraft)
  ui/
    core/           # theme, colors, typography, spacing, routes, app
    features/
      onboarding/   # splash, onboarding cards, welcome
      auth/         # login, lgpd_consent
      setup/        # wizard 3 passos (step1/2/3 + controller + scaffold)
      home/         # home placeholder
supabase/
  migrations/       # SQL timestampadas (5 base + hardening)
  functions/        # Edge Functions Deno (create-environment ativo)
  tests/database/   # pgTAP — RLS + RPC + storage
test/               # widget + unit tests
integration_test/   # flutter drive (roda em Android device real ou web+chromedriver)
test_driver/        # driver para integration_test
```

Padrões:
- State management: `ChangeNotifier` + `provider` (sem Riverpod/Bloc).
- Roteamento: `go_router` com `ShellRoute` para escopar controllers (`SetupController` é o exemplo).
- Repositórios pegam `SupabaseService.client` direto. Sem DI framework.
- Comentários só onde o *porquê* não é óbvio — explicar invariante de RLS, decisão de design contraintuitiva. Não narrar *o quê*.

---

## 4. Dev local — rodar o app + Supabase

### Rodar o app

**Web — sempre porta 5454** (Supabase Auth Google OAuth callback aponta pra `http://localhost:5454/`; outra porta = `redirect_uri_mismatch`):

```bash
flutter run -d chrome --web-port=5454
```

**Android físico** — device homologado em dev: **Galaxy S24 (SM S928B)**, device id `RQCX9030HBH`, Android 16 (API 36):

```bash
flutter devices                   # confirma device visível
flutter run -d RQCX9030HBH        # ou outro device id
```

Se device não aparecer: cabo USB de dados + depuração USB ligada + autorizar prompt no aparelho. Pré-requisito: Android Studio com SDK instalado e `flutter doctor --android-licenses` aceito.

**Integration test no Android** (~4s no Galaxy S24):

```bash
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/setup_flow_test.dart \
  -d RQCX9030HBH
```

### Supabase

- **Projeto remoto:** `ninho-dev` (region sa-east). Credenciais fora do repo (`.env` local + GitHub Secrets).
- **Dev local:** `supabase start` sobe stack completa.
- **Auth:** Google OAuth ativo (callback fixo em `http://localhost:5454/` no web). Apple adiado (precisa Apple Dev $99/ano — task 2.5).
- **RLS é obrigatório.** Toda tabela com `environment_id` tem policies por papel. Tabelas sensíveis (invites/audit/notification/dust/transfers/streaks) bloqueiam INSERT/UPDATE/DELETE de client.
- **Storage:** bucket privado `room-photos`, signed upload URLs por `{environment_id}/...`. EXIF strip no cliente antes do upload.
- **Edge Functions (Deno):** `create-environment`, `create-invite`, `accept-invite`, `suggest-tasks` em produção. Padrão: revalidar `auth.uid()` é membro do `environment_id` antes de qualquer ação (§7.1).

```bash
supabase start                 # dev local
supabase db reset              # replay migrations + seed
supabase test db               # pgTAP suite
supabase functions serve       # Edge Functions local
supabase db push               # aplicar migrations no remoto
```

---

## 5. Segurança — não-negociável

Atalhos para `IDEA.md` §7:
- **§7.1** RLS multi-tenant em toda tabela com `environment_id`. Testes pgTAP positivos *e* negativos (Alice/Bob/Carol).
- **§7.3** Convites: token ≥128 bits, hash no DB, TTL 7d, one-time use, revogável, rate-limited.
- **§7.4** Storage: signed URLs, TTL curto, validação tipo/tamanho, EXIF strip.
- **§7.5** Nada de PII em logs/Sentry. Trigger `log_lgpd_consent` em `audit_log` append-only.
- **§7.6** Prompt injection: dados do usuário sempre como variável, nunca interpolados como instrução. Output da IA nunca executa código nem decide autorização.
- **§7.7** Zero segredo no repo. Chaves da Claude API só em Edge Function — nunca no cliente Flutter.

**Quando estiver em dúvida entre rápido e seguro: seguro vence + sinalizar trade-off.**

---

## 6. Testes — não-negociável

Pirâmide (`IDEA.md` §8):
- **Unit** (`flutter_test`): lógica pura — streak, poeira, validações. Exemplo: `test/setup_controller_test.dart`.
- **Widget** (`flutter_test`): cada tela crítica. Exemplo: `test/widget_test.dart`.
- **Integration** (`integration_test/`): fluxos críticos (onboarding completo). Precisa `chromedriver` rodando em `:4444` para `flutter drive -d web-server`.
- **pgTAP** (`supabase/tests/database/`): RLS por tabela (positivo + negativo), RPC transacional, Storage. Roda em CI via `supabase test db`.
- **Snapshot prompts + eval IA** (Fase 5+).

Toda PR introduz testes para o que adicionou. Sem teste = código incompleto.

CI:
- `.github/workflows/flutter-ci.yml` — format/analyze/test/coverage.
- `.github/workflows/db-ci.yml` — `supabase start` + `supabase test db` se mudar migrations/tests/config.

Pre-commit (local, espelha o gate de format do CI):
- `.githooks/pre-commit` roda `dart format --set-exit-if-changed` só nos `.dart` staged.
- Instala uma vez por checkout: `bash scripts/install_hooks.sh` (seta `core.hooksPath=.githooks`).
- Bypass de emergência: `git commit --no-verify` (CI ainda bloqueia, evitar).

---

## 7. Convenções de copy

- **"Ninho"** sempre como nome de produto. Banco usa `environment` por compat — UI fala "ninho".
- Tom acolhedor, sem hostilidade nem competição agressiva.
- Termos: "moradores", "cuidar do ninho", "poeira na pá", "mamão/embaçada/treta".
- pt-BR é padrão; en chega na Fase 12.

---

## 8. Workflow esperado por task

1. Ler seção do `IDEA.md` correspondente.
2. Conferir Stitch (tabela §2 acima) — se faltar, sinalizar.
3. Atualizar `TASKS.md` (status `[~]` ao iniciar, `[x]` ao concluir, `[!]` se bloqueada). Decisão registrada como entrada em "Histórico de Mudanças".
4. Implementar respeitando arquitetura §3 + tokens §2.
5. Escrever testes (§6) na mesma PR.
6. Considerar segurança aplicável (§5).
7. Antes de commit: rodar `flutter analyze` + `flutter test` + (se SQL) `supabase test db`. Revisar diff.
8. Commit pequeno e descritivo (Conventional Commits — repo já usa esse estilo).

---

## 9. Estado atual (snapshot — verificar `TASKS.md` para fonte da verdade)

- **Fase 0** ✓ — Setup + Supabase dev + Sentry + PostHog (consent-gated).
- **Fase 1** ✓ — 13 tabelas, RLS, 40 pgTAP testes verdes, migrations no remoto, CI db.
- **Fase 2** ✓ pragmaticamente — Splash + Login Google + LGPD + Logout + go_router. Apple adiado.
- **Fase 3** ✓ — Wizard 3 passos, foto opcional com EXIF strip, Edge Function `create-environment` + RPC transacional. Pendente fino: integration test depende de `chromedriver`.
- **Próximo:** Fase 4 — Convites (Stitch "Convidar Parceiro" já disponível).

---

## 10. Princípios (curtos)

- Pacificador antes de gamificado.
- Multi-tenant via RLS — nunca confiar só na camada de app.
- Design vem do Stitch — agente não inventa UI.
- Segurança e testes não são "fase 2".
- Sinalize dúvida; nunca assuma silenciosamente.

---

## 11. Como usar este arquivo

- Inclua no contexto de toda sessão.
- Referencie seções (`IDEA.md` §X, `CLAUDE.md` §Y) ao pedir implementação.
- Quando decisão estrutural mudar, atualize aqui antes de pedir nova implementação.
- Se uma tela for adicionada/removida do Stitch, atualize a tabela em §2.
