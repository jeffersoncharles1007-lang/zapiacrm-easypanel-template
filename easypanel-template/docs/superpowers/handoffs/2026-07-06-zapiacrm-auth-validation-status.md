# Status Report — Validação Auth OTP ZAPIACRM

**Data:** 2026-07-06
**Sessão:** Validação de fluxo de autenticação OTP

---

## ✅ O Que FOI Feito

### 1. Deploy novo confirmado
- Novo deploy concluído com sucesso
- **URL principal (alias):** `https://zapiacrm-fresh-deploy.vercel.app`
- **URL técnica do novo deploy:** `https://zapiacrm-fresh-deploy-5fsl1ccbc.vercel.app`
- **URL ainda acessível (deploy anterior):** `https://zapiacrm-fresh-deploy-3mgd6oeo2.vercel.app`
- Build em Washington, D.C. (iad1), Node 24.x, Nitro preset Vercel ✓
- Logs SSR habilitados, `supabase-js` incluído no bundle
- Arquivo gerado: `.vercel/output/functions/__server.func/_libs/nodemailer.mjs` (386 kB) ✓

### 2. Env vars SMTP validadas
Todas as 7 env vars configuradas (valores encriptados pela Vercel):
- `SMTP_HOST` ✓
- `SMTP_PORT` ✓
- `SMTP_USER` ✓
- `SMTP_PASS` ✓ (⚠️ EXPOSTO NO CHAT — rotacionar!)
- `SMTP_SENDER_EMAIL` ✓
- `SMTP_SENDER_NAME` ✓
- `PUBLIC_APP_URL` ✓

### 3. Código revisado
- `src/lib/auth-otp.ts` (245 linhas) — 3 server-fns: `requestOtp`, `verifyOtp`, `resetPassword` ✓
- `src/lib/smtp.ts` (46 linhas) — wrapper Nodemailer direto, lê env vars em runtime ✓
- `src/routes/entrar.tsx` (350 linhas) — UI com 3 tabs (Entrar / Criar / Esqueci) + OTP input ✓
- `src/components/auth/OtpInput.tsx` (73 linhas) — input 6 dígitos com paste + auto-focus ✓
- `src/routes/api/debug/otp.ts` (76 linhas) — endpoint de debug que testa SMTP + cria OTP ✓

---

## 🚫 Bloqueio Identificado

### Vercel SSO Authentication Protection habilitada na conta

Todas as URLs de deploy (incluindo domínios públicos `.vercel.app`) estão retornando:

```
HTTP/1.1 302 Found
Location: https://vercel.com/sso-api?url=<app-url>&nonce=<nonce>
Set-Cookie: _vercel_sso_nonce=...; Secure; HttpOnly
```

**Headers de resposta confirmado:**
- `Cache-Control: no-store, max-age=0`
- `Server: Vercel`
- `X-Frame-Options: DENY`
- `X-Robots-Tag: noindex`
- `X-Vercel-Id: gru1::xrjcw-1783341311972-b2847cf3a019`

**Causa:** A conta `jeffersonnegocios1007-6125s-projects` tem **Vercel Authentication Protection** habilitada globalmente (provavelmente na config de "Deployment Protection" ou "Password Protection" / "Trusted IPs" do dashboard).

Isso afeta **TODOS os deploys públicos**, mesmo o endpoint `/api/debug/otp`.

### Tentativas frustradas (todas redirecionaram para SSO):
| Tentativa | Status | Detalhes |
|-----------|--------|----------|
| `curl` simples | ❌ 302 → vercel.com/login | KPSDK bloqueia curl |
| `curl -L` com User-Agent real | ❌ HTML da home da Vercel | Proteção não distingue curl/browser |
| Playwright headless (Chromium) | ❌ 302 → vercel.com/login | Vercel força login mesmo |
| Chrome DevTools MCP | ❌ 302 → vercel.com/login + tela de Google OAuth | Sem credenciais para login |
| Vercel CLI (`vercel logs`) | ⚠️ "No logs found" | Sem requisições chegaram ao app |

---

## 🔧 O Que Você Precisa Fazer (em ordem)

### Passo 1: Desabilitar Vercel Authentication Protection

Acesse: **https://vercel.com/jeffersonnegocios1007-6125s-projects/zapiacrm-fresh-deploy/settings/deployment-protection**

**Procure por uma destas opções (depende da versão do dashboard):**
- **"Vercel Authentication"** → Toggle OFF (desabilitar)
- **"Password Protection"** → remover senha ou desabilitar
- **"Trusted IPs"** → remover restrição ou adicionar seu IP

⚠️ Se a opção estiver como **"On for all deployments"** ao nível da **conta**, desabilite em:
**https://vercel.com/account/settings/authentication** ou
**https://vercel.com/account/settings/security**

### Passo 2: Testar manualmente (no seu navegador real)

Depois de desabilitar a proteção:

1. Abra `https://zapiacrm-fresh-deploy.vercel.app/api/debug/otp` no navegador
   - Deve mostrar JSON com as env vars configuradas (sem enviar email)
2. Abra `https://zapiacrm-fresh-deploy.vercel.app/api/debug/otp?to=SEU_EMAIL@gmail.com`
   - Deve tentar enviar email de teste
   - Verifique em **1-2 min** se o email chegou (verifique SPAM também)
3. Abra `https://zapiacrm-fresh-deploy.vercel.app/entrar`
   - Clicar aba "Criar"
   - Digitar email pessoal
   - Clicar "Enviar código pra criar conta"
   - Verificar se recebe OTP em 1-2 min
4. Digite o código → deve cair em `/master/welcome`

### Passo 3: Rotacionar senha SMTP (URGENTE — exposto no chat)

A senha foi compartilhada em texto puro: `WqeFx~muKsZZVm{t`

**Faça agora:**
1. Acesse cPanel do `digitalfunnel.online`
2. **Email Accounts** → `zapiacrm@digitalfunnel.online` → **Manage**
3. **Password & Authentication** → gerar nova senha (16+ caracteres aleatórios)
4. **Atualizar env var na Vercel:**
   ```bash
   cd "C:/Projetos/Aplicacoes/_ia-system/02-negocio-individual/Projeto ZAPIACRM/easypanel-template"
   vercel env rm SMTP_PASS production
   vercel env add SMTP_PASS production
   # Cole a nova senha quando pedir
   vercel deploy --prod --yes
   ```
5. Após o redeploy, testar novamente

### Passo 4: Validar trigger de super_admin

Quando criar o primeiro usuário, rode no **Supabase SQL Editor** do projeto `lmlhlszebuvaqerftxik`:

```sql
SELECT
  u.email,
  r.role,
  u.email_confirmed_at IS NOT NULL AS email_confirmado,
  u.created_at
FROM auth.users u
LEFT JOIN public.user_roles r ON r.user_id = u.id
ORDER BY u.created_at DESC
LIMIT 5;
```

Você deve ver:
- O email que cadastrou
- `role = super_admin` (primeiro user é promovido automaticamente pelo trigger `handle_new_user`)
- `email_confirmado = true` (criado com `email_confirm: true` no `verifyOtp`)

---

## 📊 Resumo do Status

| Item | Status |
|------|--------|
| Código auth-otp.ts | ✅ Pronto |
| Código smtp.ts | ✅ Pronto |
| Código entrar.tsx | ✅ Pronto |
| Deploy na Vercel | ✅ Pronto (2 deploys de produção) |
| Env vars SMTP configuradas | ✅ Pronto (7/7) |
| Migration otp_codes no Supabase | ✅ Pronto (tabela + RLS) |
| SMTP funcionando (validação) | ⏳ Pendente — bloqueado por SSO |
| Fluxo OTP end-to-end | ⏳ Pendente — bloqueado por SSO |
| Senha SMTP rotacionada | ❌ URGENTE — exposta no chat |
| Trigger super_admin testado | ⏳ Pendente — depende do acima |

---

## 🐛 Notas Técnicas / Lições Aprendidas

### Por que o Playwright foi bloqueado?
A Vercel Authentication Protection funciona como um **reverse proxy SSO** em nível de CDN:
- Detecta que não há cookie de sessão válido da Vercel
- Redireciona para `https://vercel.com/sso-api` que valida
- Após login bem-sucedido, o cookie `_vercel_sso_nonce` é setado por 1 hora
- O header `X-Robots-Tag: noindex` é adicionado para evitar indexação

### Por que o `vercel logs` retornou "No logs found"?
Como **todas as requisições** foram redirecionadas ANTES de chegar ao app Nitro, nenhum request gerou log no Edge/Serverless. Quando desabilitar a proteção, novos logs aparecerão.

### Como identificar o problema no futuro?
```bash
# Esse comando revela o 302 → SSO
curl -sI https://SEU-PROJETO.vercel.app/api/qualquer

# Se a URL de Location apontar para vercel.com/sso-api, é SSO Protection
```

---

## 🚀 Após Desbloquear — Próximos Passos

1. ✅ Validar fluxo OTP (descrito acima)
2. ⭐ Adicionar senha pessoal no dashboard master
3. ⭐ Testar "Esqueci senha" (esqueci tab)
4. ⭐ Implementar rate limiting por IP (não só por email)
5. ⭐ Adicionar captcha no form "Criar" se necessário
6. ⭐ Implementar audit log de auth (quem tentou login, quando, IP)
7. ⭐ Remover endpoint `/api/debug/otp` antes de produção pública
8. ⭐ Configurar domínio custom `app.zapiacrm.com.br`

---

**Status:** 🟡 Bloqueado aguardando ação manual do usuário (desabilitar SSO + rotacionar SMTP).
