# Ninho

App mobile (Flutter) de divisão de tarefas domésticas. Tom acolhedor, gamificação moderada.

Spec do produto: [`IDEA.md`](./IDEA.md). Plano de execução: [`TASKS.md`](./TASKS.md). Guia operacional para agentes: [`CLAUDE.md`](./CLAUDE.md).

## Stack
- **Mobile:** Flutter / Dart (channel stable, ≥ 3.44)
- **Backend:** Supabase (Postgres + Auth + Storage + Realtime + RLS) + Edge Functions (Deno)
- **IA:** Claude API (geração de tasks, notificações personalizadas, resumo semanal)
- **Push:** FCM (Android) + APNs (iOS)
- **Observabilidade:** Sentry (`^9.20.0`), PostHog (consent-gated)
- **Design:** Google Stitch — projeto `16698352297286313348` (ver `CLAUDE.md` §2)

## Setup local

### Pré-requisitos
- Flutter SDK (`flutter --version`)
- Conta Supabase (projeto dev)
- Para rodar em **Android** físico: Android Studio + Android SDK + `adb` no PATH (Android Studio instala tudo via Setup Wizard). Aceitar licenças: `flutter doctor --android-licenses`.
- Para rodar **web**: Chrome instalado.

### Configuração

```bash
cp .env.example .env
# preencha SUPABASE_URL e SUPABASE_ANON_KEY (+ SENTRY_DSN/POSTHOG_API_KEY se quiser)
flutter pub get
```

## Rodar o app

### Web (porta fixa 5454)

Sempre use a porta `5454` — é a usada nos redirects do Supabase Auth (Google OAuth) e em validações manuais:

```bash
flutter run -d chrome --web-port=5454
```

Abre em `http://localhost:5454/`. O callback OAuth do Google está configurado pra `http://localhost:5454/` no Supabase dev.

### Android físico

Device homologado durante desenvolvimento: **Galaxy S24 (SM S928B)** — ID `RQCX9030HBH`, Android 16 (API 36).

```bash
flutter devices                          # confirma device visível
flutter run -d RQCX9030HBH               # ou outro device id
```

Se `flutter devices` não mostrar o aparelho:
1. Cabo USB de dados (não só carga).
2. Depuração USB ligada (Ajustes → Opções do desenvolvedor).
3. Autorizar prompt "Permitir depuração USB" no aparelho (marcar "Sempre permitir").
4. `flutter doctor -v` deve listar Android toolchain sem `✗`.

### iOS

Adiado para pré-release (precisa Apple Developer $99/ano — task 2.5 em `TASKS.md`).

## Testes

```bash
flutter analyze                                                            # lint
flutter test                                                               # unit + widget
flutter test --coverage && dart run scripts/check_flutter_coverage.dart     # coverage gates
supabase test db                                                           # pgTAP (RLS, RPCs, Storage)
ENV_FILE=.env bash scripts/staging_smoke.sh                                # smoke remoto

# integration test (device físico, ~4s no Galaxy S24):
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/setup_flow_test.dart \
  -d RQCX9030HBH
```

Padrão: cobertura Dart ≥70% global, ≥90% na superfície mobile sensível
(auth/convites/ownership/LGPD). RLS/RPC/Storage seguem cobertos por pgTAP em
`supabase test db`. Ver `IDEA.md` §8.

Deploy multiambiente (`staging` = `ninho-dev`, `production` = `ninho-prod`) fica
em GitHub Actions. Runbook: [`docs/DEPLOYMENT.md`](docs/DEPLOYMENT.md).

## Supabase

```bash
supabase start                 # sobe stack local (db + auth + storage + edge runtime)
supabase db reset              # replay migrations + seed
supabase test db               # pgTAP
supabase functions serve       # Edge Functions local
supabase db push               # aplicar migrations no projeto remoto ninho-dev
```

Projeto remoto: `ninho-dev` (region sa-east). Credenciais fora do repo (`.env` local + GitHub Secrets).

## Segurança

Diretrizes em `IDEA.md` §7. Resumo:
- RLS obrigatório em toda tabela com `environment_id`.
- Segredos nunca no repo — usar `.env` (gitignored) e Supabase Vault.
- Claude API só via Edge Function — nunca embarcada no cliente.
- Fotos: signed URLs com TTL curto + strip EXIF.
- Convites: token 256 bits, hash no banco, TTL 7d, one-time use, rate-limited.

## Design

Fonte da verdade: Google Stitch (`16698352297286313348`). Tokens em `DESIGN.md` (paleta Harmonia Lar, Montserrat, spacing 8px, radius 24px). Tela por tela mapeada em `CLAUDE.md` §2. Antes de implementar UI, sempre buscar a tela no Stitch — não inventar.

## Estrutura

```
.
├── IDEA.md                       # spec do produto (fonte da verdade)
├── TASKS.md                      # plano de execução + histórico
├── CLAUDE.md                     # guia operacional para agentes
├── DESIGN.md                     # tokens do Stitch (cores/tipografia/spacing)
├── README.md                     # este arquivo
├── .env.example                  # template de variáveis (copiar para .env)
├── lib/
│   ├── data/{repositories,services}/
│   ├── domain/models/
│   └── ui/{core,features}/
├── supabase/
│   ├── migrations/               # SQL timestampadas
│   ├── functions/                # Edge Functions (Deno)
│   └── tests/database/           # pgTAP
├── test/                         # unit + widget tests
├── integration_test/             # flutter drive (device real)
└── test_driver/                  # driver para integration_test
```

## Troubleshooting

- **Build Android falha com `Language version 1.6 no longer supported`**: dependência usa Kotlin antigo. Bump da dep ou pin de Kotlin (último caso pego: `sentry_flutter` 8.x — resolvido com upgrade pra 9.x).
- **Web OAuth dá redirect_uri_mismatch**: porta diferente de 5454. Sempre rodar `flutter run -d chrome --web-port=5454`.
- **`flutter devices` não mostra Android**: rodar `adb devices`; se nada aparecer, conferir cabo + depuração USB + prompt de autorização no aparelho.
