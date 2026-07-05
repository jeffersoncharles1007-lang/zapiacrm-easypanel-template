# Sistema de Autenticação Plano B — WhatsApp OTP (com Evolution API)

**Data:** 2026-07-05
**Status:** Design (aguardando aprovação)
**Atualiza:** Plano A (password-based) com nova abordagem via WhatsApp

## Contexto

- SMTP custom (digitalfunnel.online) não está enviando emails
- Evolution API (WhatsApp) JÁ ESTÁ FUNCIONANDO no deploy
- White-label precisa funcionar sem depender de SMTP externo
- Tentativas anteriores de bypass de auth criaram vulnerabilidades (revertidas)

**Decisão final:** Usar **WhatsApp OTP de 6 dígitos** como método principal de auth, enviado via Evolution API.

## Princípios

1. **Segurança em primeiro lugar** — sem bypass de auth
2. **WhatsApp primeiro** (não email) — usa Evolution API que já funciona
3. **Master sempre tem acesso** — define senha no onboarding como backup
4. **Email é fallback** — usado se WhatsApp falhar

## Fluxo de cadastro (2 etapas)

### Etapa 1: Email + WhatsApp

```
┌────────────────────────────────────┐
│  🟢 ZAPIACRM — Criar conta          │
│                                      │
│  Email:      [_______________]       │
│  WhatsApp:   [55 11 9 9999-9999]    │
│                                      │
│  [Enviar código]                    │
└────────────────────────────────────┘
```

**Backend:**
1. Valida formato email + WhatsApp (com mascara automática)
2. Verifica se email/WhatsApp já existem no Supabase
3. Gera código OTP de 6 dígitos (válido por 5 minutos)
4. Salva OTP em memória (ou Redis em prod)
5. Envia via WhatsApp: "Seu código ZAPIACRM: 123456. Válido por 5 minutos."

### Etapa 2: Confirma código + cria conta

```
┌────────────────────────────────────┐
│  🟢 ZAPIACRM — Confirmação          │
│                                      │
│  Enviamos código pro: (62) 9****-9999│
│                                      │
│  Código: [_ _ _ _ _ _]              │
│                                      │
│  [Confirmar]                        │
│                                      │
│  Não recebeu? [Reenviar]            │
└────────────────────────────────────┘
```

**Backend:**
1. Verifica se código tá válido
2. Cria user via `supabase.auth.admin.createUser({email, phone, phone_confirm: true})`
3. Associa WhatsApp ao profile do user
4. Loga o user automaticamente
5. Redireciona pro /master/welcome (master) ou /app/checkout (cliente)

## Fluxo de login (mesmo se session expirou)

```
1. User acessa /entrar
2. Digita email (e/ou WhatsApp)
3. Clica "Entrar"
4. Backend gera novo código OTP
5. Envia por WhatsApp
6. User digita código
7. ✅ Loga
```

## Fluxo de "esqueci minha senha"

```
1. User clica "Esqueci minha senha" em /entrar
2. Digita email
3. Backend envia código OTP por WhatsApp (cadastrado previamente)
4. User digita código
5. Tela: "Defina nova senha"
6. Backend atualiza senha via supabase.auth.updateUserByPassword
7. ✅ Pode logar com nova senha
```

## Banco de dados

### Migration nova: `add_whatsapp_to_profiles`

```sql
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS telefone text,
  ADD COLUMN IF NOT EXISTS telefone_verificado boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS whatsapp_opt_in boolean NOT NULL DEFAULT true;

-- Backfill: tentar extrair telefone de auth.users (se já tiver)
UPDATE public.profiles p
SET telefone = u.phone
FROM auth.users u
WHERE p.user_id = u.id AND p.telefone IS NULL;
```

### Migration nova: `create_otp_codes`

```sql
CREATE TABLE IF NOT EXISTS public.otp_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier text NOT NULL,           -- email ou phone
  code text NOT NULL,                  -- 123456
  purpose text NOT NULL,                -- 'signup' | 'login' | 'reset_password'
  attempts int NOT NULL DEFAULT 0,
  expires_at timestamptz NOT NULL,
  consumed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX idx_otp_codes_identifier ON public.otp_codes(identifier, purpose, created_at DESC);
CREATE INDEX idx_otp_codes_expires ON public.otp_codes(expires_at);

-- Limpa códigos expirados automaticamente (a cada hora)
ALTER TABLE public.otp_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS otp_codes_all ON public.otp_codes;
CREATE POLICY otp_codes_all ON public.otp_codes FOR ALL TO service_role USING (true) WITH CHECK (true);
```

## Server Functions

### 1. `requestOtp` (POST `/api/auth/request-otp`)

```typescript
Input: { 
  email: string, 
  telefone: string,  // "5511999999999" (só dígitos)
  purpose: 'signup' | 'login' | 'reset_password'
}

Output: { ok: true, code: '123456' }  // código retornado pra debug

Lógica:
1. Valida formato
2. Verifica se email existe (pra login/reset) ou não existe (pra signup)
3. Gera código 6 dígitos
4. Salva em otp_codes (TTL 5 min)
5. Envia via WhatsApp: `await sendWhatsApp(telefone, "Seu código ZAPIACRM: 123456")`
6. Retorna ok
```

### 2. `verifyOtp` (POST `/api/auth/verify-otp`)

```typescript
Input: {
  identifier: string,        // email ou phone
  code: string,              // "123456"
  purpose: 'signup' | 'login' | 'reset_password'
  telefone?: string          // se signup, pra salvar
}

Output: {
  ok: true,
  actionLink: string,        // magic link gerado via admin.generateLink
  email: string,
  userId: string
}

Lógica:
1. Busca código válido em otp_codes
2. Verifica tentativas (max 3)
3. Se signup: cria user com createUser({email, phone, phone_confirm: true})
4. Se login/reset: valida user existe
5. Gera magic link via admin.generateLink (SEM email, só pra session)
6. Marca OTP como consumido
7. Retorna actionLink pro client
```

### 3. `sendWhatsApp` (helper privado)

```typescript
async function sendWhatsApp(to: string, message: string) {
  // Usa a função existente em src/lib/evolution.functions.ts
  // Se não existir, cria a integração
  return await evolutionSendText({ number: to, text: message });
}
```

### 4. `resetPassword` (POST `/api/auth/reset-password`)

```typescript
Input: { email: string, code: string, newPassword: string }

Lógica:
1. Verifica OTP válido
2. Chama supabase.auth.admin.updateUserById(userId, { password: newPassword })
3. Marca OTP como consumido
4. Retorna ok
```

## Frontend Changes

### `/entrar` reescrito (single page com tabs)

```
Tab 1: Entrar
  Email: [...]
  [Enviar código] → abre modal/painel com input OTP

Tab 2: Criar conta
  Email: [...]
  WhatsApp: [55 11 ...]
  [Enviar código] → modal/painel confirma código
  → após confirmar, loga e vai pro /app/onboarding ou /master/welcome
```

Tab 3: Esqueci senha
  Email: [...]
  [Enviar código]
  → modal/painel com:
    - Input código
    - Input nova senha
    - Botão "Redefinir"
```

## Arquivos modificados

| Arquivo | Mudança |
|---------|---------|
| `src/lib/own-magic-link.ts` | **REMOVER** (não vai usar) |
| `src/routes/api/debug/test-email.ts` | **REMOVER** (não vai usar) |
| `package.json` | Remover `nodemailer` (não vai usar) |
| `src/routes/entrar.tsx` | Reescrito: tabs (Entrar/Criar/Esqueci) com OTP |
| `src/lib/auth-otp.ts` | **NOVO**: 3 server-fns (request, verify, reset) |
| `src/lib/evolution.functions.ts` | Garantir que `sendText` funciona |
| `supabase/migrations/20260705-add-whatsapp.sql` | **NOVO**: profiles.telefone + tabela otp_codes |

## Fluxo detalhado do Master (1º user)

```
1. User cadastra email + WhatsApp em /entrar
2. Sistema valida formato
3. Envia OTP pro WhatsApp via Evolution API
4. User recebe "Seu código ZAPIACRM: 123456"
5. Digita no app
6. Backend: valida OTP + cria user (email_confirm=true)
7. Trigger handle_new_user: 1º user → super_admin automático
8. ✅ Loga e vai pro /master/welcome
9. Master define senha em /master/set-password (OPCIONAL mas recomendado)
10. Pronto
```

**Para próximas vezes:**
- User vai em /entrar
- Digita email
- Clica "Enviar código"
- Recebe OTP no WhatsApp
- Digita → entra

## Risco de segurança

| Antes (vulnerável) | Depois (seguro) |
|---------------------|------------------|
| Qualquer pessoa com email + API fazia login | Precisa de WhatsApp + código de 6 dígitos |
| Sem limite de tentativas | Max 3 tentativas por código |
| OTP nunca expira | OTP expira em 5 min |
| Sem proteção contra força bruta | Tabela `otp_codes.attempts` limita |

## Testes

1. ✅ Master cadastra com WhatsApp → recebe OTP → entra
2. ✅ Master sai → entra de novo com email → recebe novo OTP → entra
3. ✅ Cliente cadastra → entra
4. ✅ Cliente esquece senha → recebe código no WhatsApp → redefine
5. ✅ Tentativa com código errado 3x → bloqueia (mostra "aguarde 5 min")
6. ✅ 2 números de WhatsApp diferentes pra ver que cada um recebe seu código

## Deploy

- Migration no Supabase primeiro (add-whatsapp.sql)
- 1 commit com código
- 1 deploy na Vercel
- Testes manuais
- Tempo estimado: 2h

## O que NÃO entra

- ❌ Email como método principal (só fallback se WhatsApp falhar)
- ❌ Magic link (removido completamente)
- ❌ Login com password (só no reset)
- ❌ 2FA
- ❌ OAuth social
- ❌ SMS (só WhatsApp)

## Próximo passo (após aprovação)

1. Você revisa e aprova essa spec
2. Eu implemento + deploy
3. Testamos juntos
4. Se funcionar, documentamos como white-label
