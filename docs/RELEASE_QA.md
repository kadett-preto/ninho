# Release QA

This checklist records manual QA for `TASKS.md` 14.5 and visual parity for
14.6. Run it once on Android and once on iOS before release.

## Devices

| Platform | Device | OS | Build | Tester | Date | Result |
|---|---|---|---|---|---|---|
| Android | Galaxy S24 / `RQCX9030HBH` | Android 16 / API 36 | Debug | Codex | 2026-05-24 | Automated smoke pass; manual QA pending |
| iOS | TBD | TBD |  |  |  | Blocked: Apple Developer account |

## Preflight

- Device has a clean install of the app.
- Supabase target is the intended environment.
- Google Auth works for the target environment.
- Push config is present for the platform being tested.
- Camera permission can be granted.
- Network failure can be simulated or tested with airplane mode.

## Critical Flows

Mark each item `pass`, `fail`, or `blocked`.

Automated Android coverage on 2026-05-24:

- `integration_test/setup_flow_test.dart`: pass on `RQCX9030HBH`
- `integration_test/release_critical_flows_test.dart`: pass on `RQCX9030HBH`
- `integration_test/home_dashboard_test.dart`: pass on `RQCX9030HBH`

These tests cover the high-risk navigation and repository-fake release flows.
They do not replace the manual checklist below.

| Area | Flow | Expected result | Android | iOS | Notes |
|---|---|---|---|---|---|
| Auth | Splash -> login -> Google sign-in -> LGPD | User reaches setup or home without loop | Not run | Blocked |  |
| Setup | Create ninho with default rooms | Environment and membership are created | Not run | Blocked |  |
| Rooms | Add, edit, delete room as owner | Owner changes persist; member cannot edit | Not run | Blocked |  |
| Invites | Create invite, scan QR, preview, accept | Invite is one-time, joins ninho, opens tour | Not run | Blocked |  |
| Suggestions | Generate IA suggestions and accept selected tasks | Valid tasks are created in correct rooms | Not run | Blocked | Requires `ANTHROPIC_API_KEY` |
| Home | Today list and stats | Only today's assigned/open tasks appear | Not run | Blocked |  |
| Tasks | Filter, create, edit, archive | List updates and archived task disappears | Not run | Blocked |  |
| Completion | Complete task with photo | Completion, dust, feed event, private photo all work | Not run | Blocked |  |
| Feed | Timeline, photo detail, report/remove | Feed refreshes; moderation actions are role-gated | Not run | Blocked |  |
| Shop | Transfer task item | Dust is debited and transfer is visible in history | Not run | Blocked |  |
| Notifications | Preferences and token registration | Preferences persist; no crash if push unavailable | Not run | Blocked |  |
| Profile | Export data, leave ninho, transfer ownership | Sensitive flows require explicit confirmation | Not run | Blocked |  |
| Account | Delete account soft-delete | User signs out; owner handoff/archive behavior is correct | Not run | Blocked |  |
| Offline | Launch and refresh while offline | App shows recoverable error states | Not run | Blocked |  |

## Visual Parity Against Stitch

Use `CLAUDE.md` section 2 as the screen inventory. Compare spacing, typography,
colors, hierarchy, and empty/error states. Known exceptions must be recorded
below instead of silently accepted.

| Stitch screen | App route | Android | iOS | Notes |
|---|---|---|---|---|
| Bem-vindo | `/welcome` | Not run | Blocked |  |
| Login | `/login` | Not run | Blocked |  |
| Consentimento de Privacidade | `/consent` | Not run | Blocked |  |
| Configurar Ambiente — Passo 1 | `/setup/step1` | Not run | Blocked |  |
| Configurar Ambiente — Passo 2 | `/setup/step2` | Not run | Blocked |  |
| Configurar Ambiente — Passo 3 | `/setup/step3` | Not run | Blocked |  |
| Sugestões da IA | `/suggestions` | Not run | Blocked |  |
| Convidar Parceiro | `/invite/setup`, `/invite` | Not run | Blocked |  |
| Aceitar Convite | `/i/:token` | Not run | Blocked |  |
| Início | `/home` | Not run | Blocked |  |
| Gerenciamento de Tarefas | `/tasks` | Not run | Blocked |  |
| Criar Tarefa | `/tasks/new` | Not run | Blocked |  |
| Detalhes da Tarefa | `/tasks/:taskId` | Not run | Blocked |  |
| Confirmação de Tarefa | `/tasks/:taskId/complete` | Not run | Blocked |  |
| Mural do Ambiente | `/feed` | Not run | Blocked |  |
| Detalhe da Foto — Mural | `/feed/:eventId` | Not run | Blocked |  |
| Loja da Poeira | `/shop` | Not run | Blocked |  |
| Perfil do Usuário | `/profile` | Not run | Blocked |  |
| Configurações do Ambiente | `/profile/environment` | Not run | Blocked |  |
| Lista de Membros | `/profile/environment/members` | Not run | Blocked |  |
| Gerenciar Cômodos | `/profile/environment/rooms` | Not run | Blocked |  |
| Configurar Horários de Notificação | `/settings/notifications` | Not run | Blocked |  |
| Transferir Propriedade | `/profile/transfer-ownership` | Not run | Blocked |  |
| Exportar Meus Dados | `/profile/export` | Not run | Blocked |  |
| Excluir Conta | `/profile/delete` | Not run | Blocked |  |

## Known Blockers

- iOS QA and Apple Auth require Apple Developer account setup.
- IA behavioral baselines require `ANTHROPIC_API_KEY` in the shell.
- Full production deploy requires GitHub Environment secrets and production
  reviewers.
