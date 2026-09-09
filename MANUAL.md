# MANUAL TECNICO — ZAPIACRM

> **Para:** Dev/empreendedor que comprou o codigo-fonte ZAPIACRM
> **Quando ler:** Apos checkout do codigo, antes do primeiro deploy
> **Resultado esperado:** Deploy funcional end-to-end em 2-4h

---

## Sumario

1. [Pre-deploy](#cap-1--pre-deploy-contas--custos)
2. [Deploy Vercel](#cap-2--deploy-vercel)
3. [Configurar Supabase](#cap-3--configurar-supabase)
4. [Variaveis de ambiente](#cap-4--variaveis-de-ambiente)
5. [SMTP Titan](#cap-5--smtp-titan)
6. [WhatsApp Evolution API](#cap-6--whatsapp-evolution-api)
7. [Billing (Kiwify/Cakto/PerfectPay)](#cap-7--billing-kiwifycakto-perfectpay)
8. [White-label (marca)](#cap-8--white-label-marca)
9. [Primeiro admin master](#cap-9--primeiro-admin-master)
10. [Troubleshooting](#cap-10--troubleshooting)
11. [FAQ do novo cliente](#cap-11--faq-do-novo-cliente)
12. [Custos mensais reais](#cap-12--custos-mensais-reais-para-1-instancia)

---

## Cap 1 — Pre-deploy (contas + custos)

### Contas que voce precisa criar (todas gratis, exceto VPS para Evolution)

| Conta | Site | Custo | Uso |
|-------|------|-------|-----|
| **Vercel** | vercel.com | Gratis (Hobby) | Hospeda o app |
| **Supabase** | supabase.com | Gratis (Free) | Banco + auth |
| **GitHub** | github.com | Gratis | Versionamento |
| **Titan Email** | titan.email | Gratis (500 emails/dia) | SMTP transacional |
| **Google AI Studio** | aistudio.google.com | Gratis (rate limit) | Gemini (IA) |
| **VPS para Evolution** | hostinger.com.br | ~R$ 30/mes | Hospeda a Evolution API |

> **Sobre Evolution API**: o software em si é **gratis e open source** (https://github.com/EvolutionAPI/evolution-api). O que voce paga é o **VPS** (servidor) onde ela roda 24/7. Cada cliente seu tera seu proprio VPS — nao da pra compartilhar Evolution entre clientes porque WhatsApp Multi-Device so suporta 1 numero por instancia.

### Tempo estimado

- Criar contas: 30-45 min
- Deploy basico: 1-2 horas
- Configurar billing/whatsapp: 1 hora
- Customizar marca: 30 min

### Fork do repositorio

```bash
# No GitHub: clique "Fork" em jeffersoncharles1007-lang/zapiacrm-easypanel-template
# Depois clone seu fork:
git clone https://github.com/SEU-USER/zapiacrm-easypanel-template
cd zapiacrm-easypanel-template
bun install
```

---

## Cap 2 — Deploy Vercel

### 2.1 — Importar projeto

1. Acesse https://vercel.com/new
2. Selecione "Import Git Repository"
3. Conecte seu fork
4. **Framework Preset:** TanStack Start (auto-detectado)
5. **Root Directory:** `.` (raiz)
6. **Build Command:** `bun run build:vercel` (ja configurado em `vercel.json`)
7. **Install Command:** `bun install --frozen-lockfile` (ja configurado)
8. **Output Directory:** deixar vazio (Nitro cuida)

### 2.2 — Configurar env vars iniciais (antes do primeiro deploy)

No painel Vercel: **Settings → Environment Variables**.

Adicione pelo menos estas 4 (o resto voce adiciona depois):

```
SUPABASE_URL                 = https://[seu-projeto].supabase.co
SUPABASE_PUBLISHABLE_KEY     = eyJhbGc... (anon key)
SUPABASE_SERVICE_ROLE_KEY    = eyJhbGc... (service_role)
SUPABASE_PROJECT_ID          = [seu-ref]
APP_ORIGIN                   = https://[seu-deploy].vercel.app
```

### 2.3 — Deploy

Clique **Deploy**. Primeiro build demora ~2-3 min. Acompanhe em **Deployments** → selecione → **Building**.

**Validação**: deployment termina com status **Ready**, URL gerada (ex: `zapiacrm-xyz.vercel.app`).

---

## Cap 3 — Configurar Supabase

### 3.1 — Criar projeto

1. Acesse https://supabase.com/dashboard
2. **New Project**:
   - Name: `zapiacrm-clienteX` (ou seu nome)
   - Database Password: **salve em gerenciador de senhas**
   - Region: **sa-east-1 (Sao Paulo)** ou **us-east-1 (Virginia)**
3. Aguarde ~2 min ate provisionar

### 3.2 — Rodar SQL de setup

1. No projeto, va em **SQL Editor** (menu lateral)
2. **New Query**
3. Copie TODO o conteudo de `SETUP_REPLICAVEL.sql` (26 KB)
4. Cole no editor
5. Clique **Run** (Ctrl+Enter)
6. Aguarde **~3-5 min** (são 25+ migrations consolidadas)
7. Resultado esperado: `Success. No rows returned` (DDL nao retorna dados)

### 3.3 — Validar setup

```sql
-- Deve retornar 34 tabelas
SELECT count(*) FROM information_schema.tables
WHERE table_schema = 'public';

-- Deve retornar 3 planos (starter/pro/business)
SELECT slug, nome, preco_cents FROM public.plan;

-- Deve retornar 1 linha
SELECT * FROM pg_publication WHERE pubname = 'supabase_realtime';
```

### 3.4 — Configurar Auth URL

**Authentication → URL Configuration**:

- **Site URL**: `https://[seu-deploy].vercel.app`
- **Redirect URLs** (uma por linha):
  ```
  https://[seu-deploy].vercel.app/entrar/callback
  https://[seu-deploy].vercel.app/entrar
  https://[seu-deploy].vercel.app/app/**
  https://[seu-deploy].vercel.app/master/**
  ```

Clique **Save**.

### 3.5 — Coletar credenciais

**Settings → API**:

```
SUPABASE_URL                  = https://[seu-projeto].supabase.co
SUPABASE_PROJECT_ID           = [seu-ref]
SUPABASE_PUBLISHABLE_KEY      = eyJ... (anon public)
SUPABASE_SERVICE_ROLE_KEY     = eyJ... (service_role - NAO expor)
```

---

## Cap 4 — Variaveis de ambiente

### 4.1 — Lista completa (18 vars)

Adicione no Vercel: **Settings → Environment Variables**. Marque **Production + Preview + Development** para cada.

#### Supabase (5 vars)

| Var | Origem | Obrigatoria |
|-----|--------|-------------|
| `SUPABASE_URL` | Supabase Dashboard → Settings → API | Sim |
| `SUPABASE_PUBLISHABLE_KEY` | Supabase Dashboard → API (anon) | Sim |
| `SUPABASE_SERVICE_ROLE_KEY` | Supabase Dashboard → API (service_role) | Sim |
| `SUPABASE_PROJECT_ID` | Ref do projeto (sem https://) | Sim |
| `POSTGRES_URL_NON_POOLING` | Supabase Dashboard → Settings → Database | Opcional (so build) |

#### VITE_* mirror (3 vars)

| Var | Origem |
|-----|--------|
| `VITE_SUPABASE_URL` | Mesmo de `SUPABASE_URL` |
| `VITE_SUPABASE_PUBLISHABLE_KEY` | Mesmo de `SUPABASE_PUBLISHABLE_KEY` |
| `VITE_SUPABASE_PROJECT_ID` | Mesmo de `SUPABASE_PROJECT_ID` |

> **Dica**: `scripts/vercel-build.mjs` ja mapeia automaticamente. Se setou as Supabase vars, pode pular.

#### Google Gemini (1 var)

| Var | Origem | Custo |
|-----|--------|-------|
| `GOOGLE_API_KEY` | https://aistudio.google.com/app/apikey | Gratis ate rate limit |

#### Evolution API WhatsApp (2 vars)

| Var | Origem |
|-----|--------|
| `EVOLUTION_API_URL` | URL publica da sua instancia Evolution |
| `EVOLUTION_API_KEY` | Key gerada no painel Evolution |

#### SMTP Titan (6 vars)

| Var | Valor exemplo |
|-----|---------------|
| `SMTP_HOST` | `mail.seudominio.com.br` |
| `SMTP_PORT` | `465` (SSL) ou `587` (TLS) |
| `SMTP_USER` | `noreply@seudominio.com.br` |
| `SMTP_PASS` | senha do email |
| `SMTP_SENDER_EMAIL` | mesmo do SMTP_USER |
| `SMTP_SENDER_NAME` | `Seu Produto` |

#### Billing webhooks (3 vars, OPCIONAIS)

| Var | Origem |
|-----|--------|
| `KIWIFY_WEBHOOK_TOKEN` | Painel Kiwify → Webhooks |
| `CAKTO_WEBHOOK_TOKEN` | Painel Cakto → Webhooks |
| `PERFECTPAY_WEBHOOK_TOKEN` | Painel PerfectPay → Webhooks |

#### App config (1 var)

| Var | Valor |
|-----|-------|
| `APP_ORIGIN` | `https://[seu-deploy].vercel.app` (sem `/` final) |

### 4.2 — Trigger redeploy

Apos adicionar/modificar env vars, faca redeploy:

```bash
vercel --prod deploy --yes
```

Ou no painel: **Deployments → "..." → Redeploy**.

---

## Cap 5 — SMTP Titan

### 5.1 — Criar conta Titan

1. https://titan.email → **Sign Up**
2. Confirme email
3. Escolha plano **Free** (500 emails/dia)

### 5.2 — Criar email de envio

1. **Email → Mailboxes → Add Mailbox**
2. Email: `noreply@seudominio.com.br`
3. Senha: gere forte e salve

### 5.3 — Configurar DNS (recomendado para evitar SPAM)

No painel do seu dominio (registro.br, Cloudflare, etc.):

**SPF** (TXT):
```
v=spf1 include:spf.titan.email ~all
```

**DKIM** (TXT): valor fornecido pelo Titan em **Email → Domains → DNS Records**

**DMARC** (TXT):
```
_dmarc.seudominio.com.br  TXT  "v=DMARC1; p=none; rua=admin@seudominio.com.br"
```

### 5.4 — Testar SMTP

```bash
curl https://[seu-deploy].vercel.app/api/debug/otp?to=seu-email@gmail.com
```

Resposta esperada: `{ "emailTest": { "ok": true } }`. Cheque sua caixa (e SPAM).

---

## Cap 6 — WhatsApp Evolution API

### 6.1 — Contratar VPS

Opcoes baratas (~R$ 30/mes):
- Hostinger VPS KVM 1 (Brasil)
- Contabo VPS S (Europa)
- DigitalOcean Droplet (US)

Requisitos minimos: 2 GB RAM, 1 vCPU, Ubuntu 22.04+

### 6.2 — Instalar Evolution API

SSH no VPS:

```bash
# Atualizar sistema
apt update && apt upgrade -y

# Instalar Docker
curl -fsSL https://get.docker.com | sh

# Rodar Evolution API
docker run -d \
  --name evolution \
  --restart always \
  -p 8080:8080 \
  -e AUTHENTICATION_API_KEY=GERE-UMA-KEY-FORTE-AQUI \
  atendai/evolution-api:v2

# Liberar porta no firewall (se usar ufw)
ufw allow 8080/tcp
```

### 6.3 — Configurar HTTPS (obrigatorio para WhatsApp)

Use Caddy (mais simples) ou Nginx + Certbot:

**Caddyfile**:
```
evolution.seudominio.com.br {
  reverse_proxy localhost:8080
}
```

```bash
apt install -y caddy
# Coloque o Caddyfile em /etc/caddy/Caddyfile
systemctl reload caddy
```

### 6.4 — Setar env vars no Vercel

```
EVOLUTION_API_URL = https://evolution.seudominio.com.br
EVOLUTION_API_KEY = [a-key-forte-gerada]
```

### 6.5 — Conectar WhatsApp

1. Acesse seu app: `https://[seu-deploy].vercel.app/entrar`
2. Faca login
3. Va em **Conexao** no menu lateral
4. Clique **Conectar WhatsApp**
5. Escaneie QR code com WhatsApp Business do cliente
6. Status muda para "conectado" em <30s

---

## Cap 7 — Billing (Kiwify/Cakto/PerfectPay)

### 7.1 — Escolher provedor

Todos funcionam. **Recomendacao**: Kiwify (mais usado no Brasil, melhor UX).

### 7.2 — Criar produto no provedor

**Exemplo Kiwify:**
1. Acesse https://kiwify.com.br
2. **Produtos → Novo produto**
3. Tipo: Assinatura recorrente
4. Preco: R$ 149 (Starter) / R$ 297 (Pro) / R$ 597 (Business)
5. **Anote o product_id** de cada plano

### 7.3 — Configurar webhook no provedor

**Kiwify:**
1. **Configuracoes → Webhooks**
2. URL: `https://[seu-deploy].vercel.app/api/public/billing/webhook?provider=kiwify&token=SEU-TOKEN-AQUI`
3. Eventos: `purchase_approved`, `subscription_canceled`, `refunded`, `chargeback`
4. **Anote o token** que voce definiu na URL

### 7.4 — Setar env var no Vercel

```
KIWIFY_WEBHOOK_TOKEN = [o-token-que-voce-definiu]
```

### 7.5 — Mapear produto → plano

O webhook identifica o plano via `productRef` (product_id). No Supabase SQL Editor:

```sql
-- Ver planos atuais
SELECT slug, nome, preco_cents FROM public.plan;

-- Adicionar/atualizar com product_id da Kiwify
UPDATE public.plan
SET checkout_url = 'https://pay.kiwify.com.br/[seu-produto-id]'
WHERE slug = 'starter';
```

O sistema vincula automaticamente via `findPlanByRef()` (veja `src/routes/api/public/billing/webhook.ts`).

### 7.6 — Testar webhook

```bash
curl -X POST "https://[seu-deploy].vercel.app/api/public/billing/webhook?provider=kiwify&token=SEU-TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "event": "purchase_approved",
    "buyer_email": "teste@exemplo.com",
    "product_id": "abc123",
    "subscription_id": "sub_test_001"
  }'
```

Resposta esperada: `{"ok": true}`. Checar em `/master/empresas` se a empresa foi criada.

---

## Cap 8 — White-label (marca)

Edite **um unico arquivo**: `src/config/brand.ts`.

```typescript
export const brand = {
  name: "SeuProduto",                        // <- mude
  tagline: "Sua IA atende WhatsApp 24h",      // <- mude
  headline: "SeuProduto — CRM + WhatsApp + IA",
  description: "SeuProduto: ...",
  twitterHandle: "@seuuser",
  primary: "#22C55E",                         // cor principal (HEX)
  primaryOklch: "0.72 0.18 152",
  logoIcon: "MessageSquareText",
};
```

Apos editar, faca commit + push:

```bash
git add src/config/brand.ts
git commit -m "brand: white-label para ClienteX"
git push origin main
```

Vercel redeploy automatico (se CI/CD estiver conectado) ou rode `vercel --prod deploy --yes`.

---

## Cap 9 — Primeiro admin master

O trigger `handle_new_user()` no banco automaticamente promove o **primeiro signup** a `super_admin`.

### Procedimento

1. Acesse `https://[seu-deploy].vercel.app/entrar`
2. Aba **Criar**
3. Digite **SEU email** (o que sera o admin)
4. **Enviar codigo** (recebe por email via Titan)
5. Digite codigo de 6 digitos
6. Sistema loga e cai em `/master/welcome`
7. Defina uma senha forte

### Se outra pessoa virou master antes

Promova manualmente via SQL Editor:

```sql
INSERT INTO public.user_roles (user_id, role)
SELECT id, 'super_admin'::app_role
FROM auth.users
WHERE email = 'SEU@EMAIL.COM'
ON CONFLICT (user_id, role) DO NOTHING;
```

---

## Cap 10 — Troubleshooting

### Erro: "SMTP nao configurado"

**Causa**: Variaveis `SMTP_*` faltando na Vercel.

**Solucao**: Adicione as 6 vars (Cap 5) e faca redeploy.

---

### Erro: Email nao chega apos signup

**Causa**: SMTP com problema de autenticacao, porta bloqueada, ou SPF/DKIM faltando.

**Solucao**:
1. `curl https://[deploy]/api/debug/otp?to=seu@email.com` — mostra erro especifico
2. Verifique `SMTP_PORT=465` (SSL) ou troque para `587` (TLS)
3. Verifique SPF/DKIM do dominio

---

### Erro: Webhook retorna 401 "token invalido"

**Causa**: `KIWIFY_WEBHOOK_TOKEN` (ou equivalente) nao foi setado na Vercel, ou esta diferente do que voce configurou no painel do provedor.

**Solucao**:
1. Compare o token na URL do webhook (painel provedor) com o valor em Vercel
2. Devem ser **exatamente iguais**
3. Redeploy apos ajustar

---

### Erro: WhatsApp nao conecta (QR code nao aparece)

**Causa**: Evolution API nao configurada ou nao acessivel.

**Solucao**:
1. `curl https://[evolution-url]/instance/connectionState/teste -H "apikey: [key]"`
2. Deve retornar JSON (200)
3. Se 404/timeout: Evolution nao esta rodando ou URL/Key errados

---

### Erro: IA Gemini retorna 429 (rate limit)

**Causa**: Muitas requisicoes em pouco tempo. Free tier tem limite.

**Solucao**:
1. Upgrade Gemini API tier (pago) em https://aistudio.google.com
2. Ou aguarde 1 min e tente novamente

---

### Erro: Build do Vercel falha

**Causa comum 1**: TypeScript error
**Solucao**: Rode `bun run build` local, leia o erro, corrija.

**Causa comum 2**: Variavel de ambiente faltando em build time
**Solucao**: Adicione a var no Vercel (lembre que `VITE_*` vars vao pro bundle, precisam existir no build).

**Causa comum 3**: Migracao nova no Supabase mas nao no codigo
**Solucao**: Sincronize `supabase/migrations/` com o banco rodando.

---

### Realtime nao funciona (mensagens nao aparecem sem F5)

**Causa**: Migration realtime nao aplicada.

**Solucao**:
```sql
-- Rodar no SQL Editor do Supabase
ALTER PUBLICATION supabase_realtime ADD TABLE
  contacts, conversations, messages, opportunities,
  whatsapp_instances, users;
```

---

### Pagina `/entrar` retorna 404

**Causa**: Auth URL config no Supabase nao inclui o dominio.

**Solucao**: Supabase Dashboard → Authentication → URL Configuration → adicionar o dominio.

---

---

## Cap 11 — FAQ do novo cliente

### "Posso compartilhar minha Evolution API com outros clientes?"

**Nao.** A Evolution API roda1 instancia WhatsApp Multi-Device por VPS. Cada cliente seu tera seu **proprio WhatsApp** (ou seja, cada cliente tem um numero diferente — nao faz sentido compartilhar). Cada cliente precisa do VPS dele.

### "Posso usar meu Supabase para varios clientes?"

**Nao.** Cada cliente tem o **proprio projeto Supabase** com seu proprio banco de dados. O RLS (Row Level Security) garante isolamento, mas na pratica cada deploy aponta para um Supabase separado.

### "Quanto custa rodar1 instancia minha?"

Ver **Cap 12 — Custos mensais reais** abaixo.

### "Posso hospedar em outro lugar que nao Vercel?"

**Sim.** O codigo roda em qualquer host que suporte Node.js + Nitro:
- **Easypanel / Coolify** (VPS proprio, ~R$ 30-50/mes)
- **Railway** (free tier limitado)
- **Fly.io** (free tier limitado)
- **ProximoML / Render** (com caveats)

Vercel Hobby tem 100GB bandwidth/mes (sobrevive ate 50 clientes). Se passar disso, faca upgrade para Vercel Pro ou migre para Easypanel.

### "Voces dao suporte?"

**Nao.** Este produto e **self-service**. Suporte human nao esta incluso no preco do codigo-fonte.

Recursos:
- Este `MANUAL.md` cobre 95% dos casos
- `/api/debug/otp` para debug SMTP
- Logs do Vercel + Supabase
- Use Claude/ChatGPT para debugar (cole o erro + contexto deste MANUAL)

### "Preciso de programador para deploy?"

**Nao obrigatorio.** O fluxo e:
1. Fork no GitHub (UI)
2. Import na Vercel (UI)
3. Setar env vars (UI, copy/paste)
4. Rodar SQL no Supabase (UI, copy/paste)
5. SSH no VPS para Docker (basico)

Tempo medio: 2-4h para quem nunca fez. Se travar, contrate um freelancer pontual (R$ 200-500).

### "Tem NF / recibo para comprar de voces?"

Depende do vendedor. Se voce compra de **Jefferson Charles**, solicite NF via email. Se compra via marketplace (Hotmart, Kiwify), a plataforma gera recibo automatico.

### "Tenho direito a updates gratis do codigo?"

**Sim**, enquanto o repositorio for publico. Voce pode fazer `git pull upstream main` no seu fork para receber updates do template original. Cuidado: pode gerar conflitos se voce customizou muito.

---

## Cap 12 — Custos mensais reais (para 1 instancia)

Esta e a conta que **voce (cliente)** precisa pagar todo mes para manter1 instancia do ZAPIACRM rodando:

| Item | Free tier pago? | Estimativa |
|------|-----------------|------------|
| Vercel Hobby | Gratis | R$ 0 (ate 100GB bandwidth) |
| Supabase Free | Gratis | R$ 0 (ate 500MB database, ~10-20 clientes finais) |
| Titan Email | Gratis | R$ 0 (ate 500 emails/dia) |
| Google Gemini | Gratis | R$ 0 (ate rate limit, geralmente sobra) |
| **VPS Evolution** (DigitalOcean / Hostinger / Contabo) | ~R$ 30/mes | **R$ 30-50** |
| Dominio proprio (opcional, mas recomendado) | Anual | ~R$ 3/mes (R$ 30-50/ano) |
| **TOTAL MINIMO** | | **~R$ 30-50/mes** |

### Quando sai do free tier?

- **Vercel**: > 100GB bandwidth/mes (improvavel com < 50 clientes)
- **Supabase**: > 500MB database (geralmente so depois de 20+ clientes ativos)
- **Titan**: > 500 emails/dia (so se tiver alto volume de cadastro)
- **Gemini**: requests demais (raro no free tier; upgrade para tier pago ~R$ 50/mes)

### Upgrade path

Se voce crescer alem do free tier:
- **Vercel Pro**: $20/mes (~R$ 110) — bandwidth ilimitado
- **Supabase Pro**: $25/mes (~R$ 140) — 8GB database
- **Gemini API tier 1**: ~$30/mes — 1000 req/min
- **Total upgrade**: ~R$ 280/mes (so se voce tiver > 50 clientes ativos)

### Comparacao com concorrentes SaaS

| Solucao SaaS | Custo/cliente/mes | ZAPIACRM self-hosted (seu) |
|---|---|---|
| Chatwoot | $19 (~R$ 100) | ~R$ 1-2/cliente (custo proporcional) |
| Pipedrive | $29 (~R$ 160) | R$ 0 (sem per-seat) |
| HubSpot Free | Gratis com limitacoes | **R$ 0 completo** |
| HubSpot Pro | $890/mes | N/A |
| ZAPIACRM (sua revenda) | R$ 149-597 (seu preco) | R$ 30 fixo/mes (seu custo) |

---

## Suporte self-service

Antes de pedir ajuda:
1. Releia este MANUAL no capitulo relevante
2. Cheque `/api/debug/otp` ou logs do Vercel
3. Pesquise a mensagem de erro no Google
4. Cole o erro no Claude/ChatGPT com contexto deste MANUAL

Boa sorte com seu deploy!