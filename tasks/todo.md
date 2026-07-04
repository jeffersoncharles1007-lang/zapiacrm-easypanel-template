# ZAPIACRM — Plano de Implementação (Modelo B: Vercel + Supabase)

**Objetivo:** Vender o sistema como código pronto (white-label). Cliente forka → "Deploy to Vercel" →
Supabase provisiona sozinho → migrations rodam automáticas → app no ar em ~15 min.
WhatsApp (Evolution) e Google Agenda ficam com credenciais COMPARTILHADAS do Jefferson.
Pós-venda: zero suporte de infra (Supabase/Vercel operam o backend).

**Decisões travadas:**
- Backend operado por Supabase Cloud (conta do cliente)
- App hospedado no Vercel (conta do cliente)
- Evolution API: chave FIXA/compartilhada (não muda por cliente)
- Google OAuth (Agenda): credenciais FIXAS/compartilhadas (não muda por cliente)
- Login principal = e-mail/senha (Google é só integração, não bloqueia)

---

## FASE 0 — Segurança (URGENTE, antes de tornar o repo vendável)

- [ ] Remover segredos commitados: `credentials.env`, token Docker Hub em `build-and-push.sh`,
      chave Evolution hardcoded em `docker-compose.yml`, token Paddle em `.env.production`
- [ ] Limpar o histórico do git (git-filter-repo/BFG) — segredos já estão em commits antigos
- [ ] ROTACIONAR as credenciais expostas (token Docker Hub, Google secret) — já vazaram em repo público
- [ ] Adicionar `.env*` e `credentials.env` ao `.gitignore`

## FASE 1 — App rodar no Vercel (risco técnico nº1)

- [ ] Configurar `NITRO_PRESET=vercel` no build (via `vercel.json` env ou Project Settings)
- [ ] Criar `vercel.json` (build command, output, framework)
- [ ] Mapear VITE_* em build-time: a integração Supabase seta `SUPABASE_URL`/keys;
      criar shim que espelha p/ `VITE_SUPABASE_URL`, `VITE_SUPABASE_PROJECT_ID`, `VITE_SUPABASE_PUBLISHABLE_KEY`
- [ ] **Deploy de teste real** numa conta Vercel (validar SSR + rotas /api) ← ponto de verificação

## FASE 2 — Provisionamento automático do Supabase

- [ ] Documentar/configurar a integração Vercel↔Supabase (cria projeto + injeta env)
- [ ] Runner de migrations idempotente: aplica os 24 arquivos de `supabase/migrations/`
      via connection string do Postgres (`POSTGRES_URL_NON_POOLING`) no build/first-run
- [ ] Adicionar dependência mínima (`pg`) só para o runner
- [ ] Testar: projeto Supabase vazio → migrations aplicadas → tabelas criadas

## FASE 3 — Credenciais compartilhadas (Evolution + Google) sem vazar

- [ ] Definir entrega: cliente cola 2 valores secretos no deploy (EVOLUTION_API_KEY,
      GOOGLE_CLIENT_SECRET) — fornecidos por você em privado na venda
- [ ] Valores NÃO-secretos (EVOLUTION_API_URL, GOOGLE_CLIENT_ID) entram como default no botão Deploy
- [ ] (Opção futura) "config broker" seu p/ rotação sem o cliente colar nada

## FASE 4 — Botão "Deploy to Vercel" + onboarding

- [ ] Botão Deploy no README com lista de env vars (secretas pedidas, resto default)
- [ ] README de venda: passo a passo do cliente (fork → deploy → domínio → conta admin)
- [ ] (Opção) Ponte de callback do Google num domínio seu, p/ não cadastrar cada domínio no Console

## FASE 5 — White-label (rebranding fácil)

- [ ] Centralizar marca (nome, logo, cores) num único arquivo de config
- [ ] Documentar como o cliente troca a marca

## FASE 6 — Limpeza

- [ ] Mover artefatos de VPS (Dockerfile, docker-compose*, install*.sh) p/ `deploy/vps-legacy/`
      ou remover — evitar confusão com o caminho Vercel
- [ ] Corrigir README (Paddle, não Stripe)

---

## Pontos que precisam de decisão sua
1. **Entrega dos 2 segredos** (Evolution key + Google secret): cliente cola no deploy (recomendado)
   vs config broker seu. → definir na Fase 3.
2. **Ponte de callback do Google**: fazer agora (zero trabalho futuro) vs cadastrar domínio por cliente.

## Ordem de teste (verificação)
Fase 1 (deploy sobe) → Fase 2 (migrations criam tabelas) → criar conta admin (auth funciona) →
testar CRM (rest/realtime) → testar WhatsApp (Evolution compartilhada) → testar Google Agenda.

## Review — estado em 04/07/2026

### ✅ Feito por mim (no working tree, ainda NÃO commitado)
- **Fase 0:** segredos removidos de `.env.production`, `docker-compose.yml`, `build-and-push.sh`;
  `.gitignore` reforçado (`.env.*`, `.vercel/`); `credentials.env` apagado do disco.
- **Fase 1:** `vercel.json` + `scripts/vercel-build.mjs` (mapeia SUPABASE_*→VITE_*, roda migration, build).
  **Build validado localmente com `NITRO_PRESET=vercel` → gerou `.vercel/output` correto.** ✔
- **Fase 2:** `scripts/migrate.mjs` (runner idempotente das 24 migrations) + `pg` no package.json.
- **Fase 3:** `.env.example` reescrito separando auto/segredo/opcional.
- **Fase 4:** `README.md` reescrito com botão "Deploy to Vercel" + onboarding do cliente.
- **Fase 6:** artefatos de VPS movidos p/ `deploy/vps-legacy/`.

### ⛔ Depende de VOCÊ (não posso fazer daqui)
1. **ROTACIONAR os segredos vazados** (repo público): token Docker Hub, `GOOGLE_CLIENT_SECRET`,
   chave Evolution, token Paddle. Remover do working tree não basta — já estão no histórico.
2. **Limpar o histórico do git** (git-filter-repo/BFG) e `git push --force`. É destrutivo → sua decisão.
3. **Deploy de teste real** na sua conta Vercel + conectar a integração Supabase +
   confirmar que as migrations rodam no build contra um projeto Supabase novo.
4. Entregar os 4 valores (GOOGLE_CLIENT_ID/SECRET, EVOLUTION_API_URL/KEY) ao cliente na venda.
5. (Opcional) Renomear o repo de `zapiacrm-easypanel-template` p/ algo limpo (ex: `zapiacrm`).

### ⏳ Pendente (posso fazer depois, se quiser)
- **Fase 5 (white-label):** centralizar marca (nome/logo/cores) num arquivo de config.
- **Ponte de callback do Google** num domínio seu (p/ não cadastrar domínio por cliente).

