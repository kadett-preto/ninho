# Ninho

App mobile (Flutter) de divisão de tarefas domésticas. Tom acolhedor, gamificação moderada.

Spec do produto: [`IDEA.md`](./IDEA.md). Plano de execução: [`TASKS.md`](./TASKS.md).

## Stack
- **Mobile:** Flutter / Dart
- **Backend:** Supabase (Postgres + Auth + Storage + Realtime + RLS) + Edge Functions (Deno)
- **IA:** Claude API (geração de tasks, notificações personalizadas, resumo semanal)
- **Push:** FCM (Android) + APNs (iOS)
- **Observabilidade:** Sentry, PostHog

## Setup local

Pré-requisitos:
- Flutter SDK (`flutter --version` deve responder)
- Conta Supabase (projeto dev)

```bash
cp .env.example .env
# preencha SUPABASE_URL e SUPABASE_ANON_KEY
flutter pub get
flutter run
```

## Testes

```bash
flutter analyze
flutter test
```

Padrão: cobertura ≥70% global, ≥90% módulos de segurança (auth/RLS/convites/ownership). Ver `IDEA.md` §8.

## Segurança

Diretrizes em `IDEA.md` §7. Resumo:
- RLS obrigatório em toda tabela com `environment_id`.
- Segredos nunca no repo — usar `.env` (gitignored) e Supabase Vault.
- Claude API só via Edge Function — nunca embarcada no cliente.
- Fotos: signed URLs com TTL curto + strip EXIF.

## Design

Fonte da verdade: Google Stitch. Antes de implementar tela, peça o link/export correspondente. Ver `IDEA.md` §2.

## Estrutura

```
.
├── IDEA.md            # spec do produto
├── TASKS.md           # plano de execução
├── README.md          # este arquivo
├── .env.example       # template de variáveis (copiar para .env)
├── .agents/           # skills locais de agentes (Flutter)
└── (Flutter scaffold após Fase 0.1)
```
