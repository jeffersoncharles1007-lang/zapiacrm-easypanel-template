# CHECKLIST PRE-DEPLOY - ZAPIACRM

Use este checklist antes de comecar o deploy. Marque cada item conforme completa.

## CONTAS QUE VOCE PRECISA CRIAR

### 1. Vercel (Frontend + Edge)
- [ ] Conta criada em https://vercel.com/signup
- [ ] Email confirmado
- [ ] Conta do GitHub conectada a Vercel
- [ ] Fork do repositorio `jeffersoncharles1007-lang/zapiacrm-easypanel-template` feito

### 2. Supabase (Banco + Auth)
- [ ] Conta criada em https://supabase.com/dashboard
- [ ] Projeto novo criado
- [ ] Regiao escolhida: **sa-east-1 (Sao Paulo)** ou **us-east-1 (Virginia)**
- [ ] Senha do banco salva em gerenciador de senhas
- [ ] Anotado:
  - [ ] `SUPABASE_URL`: `https://[seu-projeto].supabase.co`
  - [ ] `SUPABASE_PROJECT_ID`: ref do projeto
  - [ ] `SUPABASE_PUBLISHABLE_KEY` (anon key)
  - [ ] `SUPABASE_SERVICE_ROLE_KEY` (NUNCA expor no frontend)

### 3. SMTP Titan (Email transacional)
- [ ] Conta criada em https://titan.email (free tier: 500 emails/dia)
- [ ] Email criado (ex: `noreply@seudominio.com.br`)
- [ ] SMTP habilitado e testado
- [ ] Credenciais salvas: host, porta (465), user, senha

### 4. Google Gemini (IA)
- [ ] API key gerada em https://aistudio.google.com/app/apikey (gratis ate rate limit)

### 5. Evolution API (WhatsApp)
- [ ] VPS contratado (Hostinger, Contabo, DigitalOcean - ~R$ 30/mes)
- [ ] Docker instalado no VPS
- [ ] Evolution API rodando (ver MANUAL.md cap 6) — software **gratis e open source** (github.com/EvolutionAPI/evolution-api), o que voce paga e o **VPS** que roda ela 24/7
- [ ] API key gerada no painel Evolution

### 6. Webhook de pagamento (opcional mas recomendado)
- [ ] Conta em Kiwify, Cakto OU PerfectPay (escolha 1)
- [ ] Produto/plano criado no painel
- [ ] Token de webhook gerado

### 7. GitHub (Versionamento)
- [ ] Fork do repo `zapiacrm-easypanel-template` criado na sua conta
- [ ] Vercel conectado ao seu fork (NAO ao upstream)

### 8. Dominio (Opcional mas recomendado)
- [ ] Dominio registrado (registro.br, namecheap)
- [ ] DNS configurado para apontar para Vercel

---

## FERRAMENTAS LOCAIS QUE VOCE PRECISA

- [ ] **Node.js 18+** instalado (https://nodejs.org)
- [ ] **Bun** instalado (https://bun.sh) - usado pelo build
- [ ] **Git** instalado
- [ ] **VS Code** ou editor similar
- [ ] **Vercel CLI**: `npm i -g vercel`
- [ ] **Terminal funcional** (PowerShell, bash, zsh)

---

## VALIDACOES ANTES DO DEPLOY

### Supabase OK
- [ ] Projeto criado
- [ ] `SETUP_REPLICAVEL.sql` rodado com sucesso (em SQL Editor)
- [ ] `SELECT * FROM pg_publication WHERE pubname = 'supabase_realtime'` retorna 1 linha
- [ ] Auth URL config:
  - Site URL: `https://[seu-deploy].vercel.app`
  - Redirect URLs inclui `/entrar/callback`

### SMTP testado
- [ ] Email de teste enviado pelo painel Titan
- [ ] Email recebido (nao caiu em spam)

### Evolution API testada
- [ ] `curl https://[sua-evolution]/instance/connectionState/[nome]` retorna 200
- [ ] API key reconhecida

### Vercel pronto
- [ ] Fork do repo importado
- [ ] Build command configurado: `bun run build:vercel`
- [ ] Framework: detectado como TanStack Start

---

## CUSTOS ESPERADOS (Free Tier)

| Item | Custo |
|------|-------|
| Vercel Hobby | Gratis (100GB bandwidth/mes) |
| Supabase Free | Gratis (500MB database) |
| Titan Email | Gratis (500 emails/dia) |
| Google Gemini | Gratis (ate rate limit) |
| Evolution API (VPS) | ~R$ 30/mes |
| Dominio (opcional) | R$ 30-50/ano |
| **Total inicial** | ~R$ 30/mes |

---

## QUANDO VOCE PODE COMECAR

Quando TODOS estes itens estao marcados:
- [ ] Todas as 6 contas criadas
- [ ] Todas as ferramentas instaladas
- [ ] Supabase com `SETUP_REPLICAVEL.sql` aplicado
- [ ] 2-4 horas livres sem interrupcao

**Se algum item NAO esta marcado:** volte e complete antes de prosseguir.

---

## PROXIMO PASSO

Siga o `MANUAL.md` cap 2 (Deploy Vercel) em diante.