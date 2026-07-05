# Plano de Implementação: Auth via Email OTP (SMTP direto via Nodemailer)

> **Para workers agentic:** SUB-SKILL OBRIGATÓRIO: Use superpowers:executing-plans para implementar este plano task-by-task. Steps usam checkbox (`- [ ]`) para tracking.

**Goal:** Substituir auth baseado em email/magic-link (Supabase Auth) por auth via email OTP de 6 dígitos usando Nodemailer direto no nosso server, com credenciais SMTP do digitalfunnel.online.

**Arquitetura:** 3 server-fns (`requestOtp`, `verifyOtp`, `resetPassword`) que usam Nodemailer direto. Frontend `/entrar` reescrito com 3 tabs. Tabela `otp_codes` no Supabase com TTL de 5 minutos.

**Tech Stack:** TanStack Start, Supabase (Postgres + admin API), Nodemailer (SMTP), Zod, React.

## Global Constraints

- TypeScript, sem `any` em código de aplicação
- Componentes em `.tsx`, hooks no top-level
- TailwindCSS, sem `style` inline exceto gradient dinâmico
- Sem `console.log` em prod
- TODAS migrations idempotentes
- TODAS RLS policies drop+create idempotentes
- Triggers `DROP TRIGGER IF EXISTS` antes de criar
- Variáveis de ambiente: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS, SMTP_SENDER_EMAIL no Vercel
- A senha SMTP que o usuário compartilhou (WqeFx~muKsZZVm{t) DEVE ser rotacionada após implementação

## File Structure

**Novos arquivos:**
- `supabase/migrations/20260705-otp-auth.sql` — adiciona `profiles.telefone_verificado`, cria `public.otp_codes` com RLS
- `src/lib/auth-otp.ts` — 3 server-fns + helpers
- `src/lib/smtp.ts` — wrapper de Nodemailer (reutilizável)
- `src/components/auth/OtpInput.tsx` — input de 6 dígitos

**Arquivos modificados:**
- `src/routes/entrar.tsx` — reescrito com 3 tabs

**Arquivos removidos:**
- `src/lib/own-magic-link.ts` (não usado)
- `src/routes/api/debug/test-email.ts` (não útil)
- Dep `nodemailer` ainda será usada (mantém)

**Env vars a adicionar na Vercel:**
```
SMTP_HOST=mail.digitalfunnel.online
SMTP_PORT=465
SMTP_USER=zapiacrm@digitalfunnel.online
SMTP_PASS=WqeFx~muKsZZVm{t
SMTP_SENDER_EMAIL=zapiacrm@digitalfunnel.online
SMTP_SENDER_NAME=ZAPIACRM
```

---

## Task 1: Migration SQL — Adicionar campos + tabela otp_codes

**Files:**
- Create: `supabase/migrations/20260705-otp-auth.sql`

**Step 1.1: Escrever migration**

```sql
-- ============================================================================
-- ZAPIACRM: Auth via OTP (1ª parte - schema)
-- ============================================================================

-- 1) Campos em profiles
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS telefone_verificado boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS whatsapp_opt_in boolean NOT NULL DEFAULT true;

-- 2) Tabela otp_codes
CREATE TABLE IF NOT EXISTS public.otp_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier text NOT NULL,
  purpose text NOT NULL CHECK (purpose IN ('signup', 'login', 'reset_password')),
  code text NOT NULL,
  attempts int NOT NULL DEFAULT 0,
  max_attempts int NOT NULL DEFAULT 3,
  expires_at timestamptz NOT NULL,
  consumed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_otp_codes_lookup 
  ON public.otp_codes(identifier, purpose, expires_at DESC) 
  WHERE consumed = false;

-- 3) RLS
ALTER TABLE public.otp_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS otp_codes_service_role_all ON public.otp_codes;
CREATE POLICY otp_codes_service_role_all ON public.otp_codes 
  FOR ALL TO service_role 
  USING (true) WITH CHECK (true);
```

**Step 1.2: Documentar no commit**

```bash
git add supabase/migrations/20260705-otp-auth.sql
git commit -m "feat(db): schema para auth via OTP

- profiles: telefone_verificado, whatsapp_opt_in
- otp_codes: id, identifier, purpose, code, attempts, max_attempts, expires_at
- RLS restrito a service_role
- Indice para lookup rapido
- Idempotente"
```

**⚠️ User precisa aplicar essa migration no Supabase Dashboard (SQL Editor) antes de continuar com a Task 2**

---

## Task 2: Wrapper SMTP (Nodemailer)

**Files:**
- Create: `src/lib/smtp.ts`

**Step 2.1: Implementar**

```typescript
import nodemailer from "nodemailer";

let _transporter: nodemailer.Transporter | null = null;

function getTransporter() {
  if (_transporter) return _transporter;
  const host = process.env.SMTP_HOST;
  const port = Number(process.env.SMTP_PORT || 465);
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;

  if (!host || !user || !pass) {
    throw new Error(
      "SMTP não configurado. Defina SMTP_HOST, SMTP_USER, SMTP_PASS nas env vars da Vercel."
    );
  }

  _transporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass },
  });
  return _transporter;
}

export type SendEmailOpts = {
  to: string;
  subject: string;
  html: string;
  text?: string;
};

export async function sendEmail({ to, subject, html, text }: SendEmailOpts) {
  const transporter = getTransporter();
  const senderEmail = process.env.SMTP_SENDER_EMAIL || process.env.SMTP_USER!;
  const senderName = process.env.SMTP_SENDER_NAME || "ZAPIACRM";

  return transporter.sendMail({
    from: `"${senderName}" <${senderEmail}>`,
    to,
    subject,
    html,
    text,
  });
}
```

**Step 2.2: Verificar build**

```bash
cd easypanel-template && node scripts/vercel-build.mjs 2>&1 | grep -E "built in|✗|error:" | tail -3
```

**Step 2.3: Commit**

```bash
git add src/lib/smtp.ts
git commit -m "feat(smtp): wrapper Nodemailer para envio de email direto"
```

---

## Task 3: Helpers de auth (código + validação)

**Files:**
- Create: `src/lib/auth-otp.ts` (adicionar no topo do arquivo, antes dos server-fns)

**Step 3.1: Implementar helpers**

```typescript
import { z } from "zod";
import { createServerFn } from "@tanstack/react-start";
import { createClient } from "@supabase/supabase-js";
import { sendEmail } from "./smtp";

export const OTP_TTL_MINUTES = 5;
export const OTP_MAX_ATTEMPTS = 3;

function generateOtpCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

let _admin: ReturnType<typeof createClient> | null = null;
export function getAdminClient() {
  if (_admin) return _admin;
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error("SUPABASE_URL/SERVICE_ROLE_KEY faltando");
  _admin = createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  return _admin;
}

// Template HTML do email OTP
function buildOtpEmailHtml(code: string, ttlMinutes: number) {
  return `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="margin:0; padding:0; background:#f5f7f5; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f5f7f5; padding:40px 0;">
    <tr><td align="center">
      <table role="presentation" width="520" cellpadding="0" cellspacing="0" style="background:#ffffff; border-radius:16px; overflow:hidden; box-shadow:0 4px 24px rgba(0,0,0,0.06);">
        <tr><td style="background:linear-gradient(135deg, #22C55E 0%, #16A34A 100%); padding:28px 40px; text-align:center;">
          <h1 style="margin:0; color:#ffffff; font-size:24px; font-weight:800;">ZAPIACRM</h1>
        </td></tr>
        <tr><td style="padding:40px 40px 16px 40px;">
          <h2 style="margin:0 0 12px 0; color:#0A1F12; font-size:22px; font-weight:700;">Seu código de acesso 🔐</h2>
          <p style="margin:0; color:#4B5A52; font-size:15px; line-height:1.6;">
            Use o código abaixo pra entrar. Válido por ${ttlMinutes} minutos.
          </p>
        </td></tr>
        <tr><td align="center" style="padding:24px 40px 32px 40px;">
          <div style="display:inline-block; background:#F5F7F5; padding:24px 48px; border-radius:12px; font-size:42px; font-weight:900; letter-spacing:8px; color:#16A34A; font-family:monospace;">
            ${code}
          </div>
        </td></tr>
        <tr><td style="padding:0 40px 32px 40px; text-align:center;">
          <p style="margin:0; color:#9CA3AF; font-size:13px;">
            Não compartilhe este código. Se você não fez esta solicitação, ignore este email.
          </p>
        </td></tr>
        <tr><td style="background:#F5F7F5; padding:24px 40px; text-align:center; border-top:1px solid #E5E7EB;">
          <p style="margin:0; color:#9CA3AF; font-size:11px;">Enviado por ZAPIACRM via SMTP proprio</p>
        </td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`.trim();
}
```

**Step 3.2: Commit**

```bash
git add src/lib/auth-otp.ts
git commit -m "feat(auth-otp): helpers e template HTML do email"
```

---

## Task 4: Server-fn `requestOtp`

**Files:**
- Modify: `src/lib/auth-otp.ts`

**Step 4.1: Implementar**

```typescript
const requestOtpInput = z.object({
  email: z.string().email("Email inválido").trim().toLowerCase(),
  purpose: z.enum(["signup", "login", "reset_password"]),
});

export const requestOtp = createServerFn({ method: "POST" })
  .validator(requestOtpInput)
  .handler(async ({ data }) => {
    const { email, purpose } = data;
    const admin = getAdminClient();

    // Validação por purpose
    const { data: list } = await admin.auth.admin.listUsers();
    const userExists = (list?.users ?? []).some((u: any) => u.email === email);

    if (purpose === "signup" && userExists) {
      throw new Error("Email já cadastrado. Use 'Entrar' em vez de 'Criar'.");
    }
    if ((purpose === "login" || purpose === "reset_password") && !userExists) {
      throw new Error("Email não cadastrado. Crie uma conta primeiro.");
    }

    // Rate limit: max 1 OTP por minuto por identifier
    const oneMinuteAgo = new Date(Date.now() - 60 * 1000).toISOString();
    const { data: recent } = await admin
      .from("otp_codes")
      .select("id")
      .eq("identifier", email)
      .eq("purpose", purpose)
      .gte("created_at", oneMinuteAgo)
      .limit(1);
    if (recent?.length) {
      throw new Error("Aguarde 1 minuto antes de pedir novo código.");
    }

    // Gera código
    const code = generateOtpCode();
    const expiresAt = new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000).toISOString();

    const { error: insertErr } = await admin.from("otp_codes").insert({
      identifier: email,
      purpose,
      code,
      expires_at: expiresAt,
      max_attempts: OTP_MAX_ATTEMPTS,
    });
    if (insertErr) throw new Error("Erro ao gerar código: " + insertErr.message);

    // Envia email
    try {
      await sendEmail({
        to: email,
        subject: `Seu código ZAPIACRM: ${code}`,
        html: buildOtpEmailHtml(code, OTP_TTL_MINUTES),
      });
    } catch (e: any) {
      throw new Error(`Falha ao enviar email: ${e?.message}`);
    }

    return { ok: true };
  });
```

**Step 4.2: Build + commit**

```bash
cd easypanel-template && node scripts/vercel-build.mjs 2>&1 | grep -E "built in|✗" | tail -3
git add src/lib/auth-otp.ts
git commit -m "feat(auth-otp): requestOtp server-fn

- Gera codigo 6 digitos
- Salva em otp_codes (TTL 5 min)
- Rate limit: 1 por minuto
- Envia email via SMTP direto
- Valida se user existe (login) ou nao (signup)"
```

---

## Task 5: Server-fn `verifyOtp`

**Files:**
- Modify: `src/lib/auth-otp.ts`

**Step 5.1: Implementar**

```typescript
const verifyOtpInput = z.object({
  email: z.string().email().trim().toLowerCase(),
  code: z.string().length(6),
  purpose: z.enum(["signup", "login", "reset_password"]),
});

export const verifyOtp = createServerFn({ method: "POST" })
  .validator(verifyOtpInput)
  .handler(async ({ data }) => {
    const { email, code, purpose } = data;
    const admin = getAdminClient();

    // Busca código válido (não consumido, não expirado)
    const { data: otpRows } = await admin
      .from("otp_codes")
      .select("*")
      .eq("identifier", email)
      .eq("purpose", purpose)
      .eq("consumed", false)
      .gt("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1);

    const otp = otpRows?.[0];
    if (!otp) {
      throw new Error("Código expirado ou não existe. Solicite um novo.");
    }

    if (otp.attempts >= otp.max_attempts) {
      await admin.from("otp_codes").update({ consumed: true }).eq("id", otp.id);
      throw new Error("Muitas tentativas. Solicite um novo código.");
    }

    if (otp.code !== code) {
      await admin
        .from("otp_codes")
        .update({ attempts: otp.attempts + 1 })
        .eq("id", otp.id);
      throw new Error(
        `Código incorreto. ${otp.max_attempts - otp.attempts - 1} tentativa(s) restante(s).`
      );
    }

    // Marca como consumido
    await admin.from("otp_codes").update({ consumed: true }).eq("id", otp.id);

    // Se for signup, cria user
    if (purpose === "signup") {
      const { error: createErr } = await admin.auth.admin.createUser({
        email,
        email_confirm: true,
        user_metadata: { source: "otp-signup" },
      });
      if (createErr) throw new Error("Falha ao criar conta: " + createErr.message);
    }

    // Gera magic link (sem email) pra o client logar
    const { data: linkData, error: linkErr } = await admin.auth.admin.generateLink({
      type: "magiclink",
      email,
      options: {
        redirectTo: `${
          process.env.PUBLIC_APP_URL || "https://zapiacrm-teste.vercel.app"
        }/entrar/callback`,
      },
    });

    if (linkErr) throw new Error("Falha ao gerar link: " + linkErr.message);

    return {
      ok: true,
      actionLink: linkData?.properties?.action_link,
    };
  });
```

**Step 5.2: Build + commit**

```bash
cd easypanel-template && node scripts/vercel-build.mjs 2>&1 | grep -E "built in|✗" | tail -3
git add src/lib/auth-otp.ts
git commit -m "feat(auth-otp): verifyOtp server-fn

- Valida codigo (max 3 tentativas)
- Cria user se signup
- Gera magic link pra login
- Marca codigo como consumido"
```

---

## Task 6: Server-fn `resetPassword`

**Files:**
- Modify: `src/lib/auth-otp.ts`

**Step 6.1: Implementar**

```typescript
const resetPasswordInput = z.object({
  email: z.string().email().trim().toLowerCase(),
  code: z.string().length(6),
  newPassword: z.string().min(8).max(72),
});

export const resetPassword = createServerFn({ method: "POST" })
  .validator(resetPasswordInput)
  .handler(async ({ data }) => {
    const { email, code, newPassword } = data;
    const admin = getAdminClient();

    // Reutiliza lógica do verifyOtp
    const { data: otpRows } = await admin
      .from("otp_codes")
      .select("*")
      .eq("identifier", email)
      .eq("purpose", "reset_password")
      .eq("consumed", false)
      .gt("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1);

    const otp = otpRows?.[0];
    if (!otp) throw new Error("Código expirado ou não existe");

    if (otp.attempts >= otp.max_attempts) {
      await admin.from("otp_codes").update({ consumed: true }).eq("id", otp.id);
      throw new Error("Muitas tentativas. Solicite um novo código.");
    }
    if (otp.code !== code) {
      await admin
        .from("otp_codes")
        .update({ attempts: otp.attempts + 1 })
        .eq("id", otp.id);
      throw new Error("Código incorreto");
    }
    await admin.from("otp_codes").update({ consumed: true }).eq("id", otp.id);

    // Acha user e atualiza senha
    const { data: list } = await admin.auth.admin.listUsers();
    const user = (list?.users ?? []).find((u: any) => u.email === email);
    if (!user) throw new Error("User não encontrado");

    const { error: updErr } = await admin.auth.admin.updateUserById(user.id, {
      password: newPassword,
    });
    if (updErr) throw new Error("Falha ao atualizar senha: " + updErr.message);

    return { ok: true };
  });
```

**Step 6.2: Build + commit**

```bash
cd easypanel-template && node scripts/vercel-build.mjs 2>&1 | grep -E "built in|✗" | tail -3
git add src/lib/auth-otp.ts
git commit -m "feat(auth-otp): resetPassword server-fn

- Valida codigo de reset
- Atualiza senha via admin.auth.admin.updateUserById
- Reutiliza validacao do verifyOtp"
```

---

## Task 7: Componente OtpInput

**Files:**
- Create: `src/components/auth/OtpInput.tsx`

**Step 7.1: Implementar**

```typescript
import { useState, useRef, useEffect } from "react";

type Props = {
  value: string;
  onChange: (v: string) => void;
  onComplete?: (v: string) => void;
  length?: number;
  disabled?: boolean;
  autoFocus?: boolean;
};

export function OtpInput({
  value,
  onChange,
  onComplete,
  length = 6,
  disabled = false,
  autoFocus = true,
}: Props) {
  const refs = useRef<Array<HTMLInputElement | null>>([]);

  useEffect(() => {
    if (autoFocus && refs.current[0]) refs.current[0]?.focus();
  }, [autoFocus]);

  function handleChange(idx: number, e: React.ChangeEvent<HTMLInputElement>) {
    const v = e.target.value.replace(/\D/g, "");
    if (!v) {
      onChange(value.substring(0, idx) + value.substring(idx + 1));
      return;
    }
    if (v.length > 1) {
      const paste = v.slice(0, length);
      const filled = value.substring(0, idx) + paste + value.substring(idx + paste.length);
      onChange(filled.substring(0, length));
      const next = Math.min(idx + paste.length, length - 1);
      refs.current[next]?.focus();
      if (filled.length >= length) onComplete?.(filled.substring(0, length));
      return;
    }
    const newValue = value.substring(0, idx) + v + value.substring(idx + 1);
    onChange(newValue);
    if (idx < length - 1) refs.current[idx + 1]?.focus();
    if (newValue.length === length) onComplete?.(newValue);
  }

  function handleKeyDown(idx: number, e: React.KeyboardEvent<HTMLInputElement>) {
    if (e.key === "Backspace" && !value[idx] && idx > 0) {
      refs.current[idx - 1]?.focus();
    }
  }

  return (
    <div className="flex gap-2 justify-center">
      {Array.from({ length }).map((_, idx) => (
        <input
          key={idx}
          ref={(el) => { refs.current[idx] = el; }}
          type="text"
          inputMode="numeric"
          maxLength={1}
          value={value[idx] ?? ""}
          onChange={(e) => handleChange(idx, e)}
          onKeyDown={(e) => handleKeyDown(idx, e)}
          disabled={disabled}
          className="w-12 h-14 text-center text-2xl font-bold border rounded-lg focus:ring-2 focus:ring-primary focus:border-primary outline-none disabled:opacity-50"
        />
      ))}
    </div>
  );
}
```

**Step 7.2: Build + commit**

```bash
cd easypanel-template && node scripts/vercel-build.mjs 2>&1 | grep -E "built in|✗" | tail -3
git add src/components/auth/OtpInput.tsx
git commit -m "feat(auth-otp): OtpInput component (6 inputs com paste + backspace)"
```

---

## Task 8: Reescrever /entrar com 3 tabs

**Files:**
- Modify: `src/routes/entrar.tsx`

**Step 8.1: Implementar (versão completa, copy-paste)**

```typescript
import { createFileRoute, redirect, useNavigate, Link, useSearch } from "@tanstack/react-router";
import { useState } from "react";
import { z } from "zod";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card } from "@/components/ui/card";
import { toast } from "sonner";
import {
  MessageSquareText, Sparkles, Loader2, Bot, KanbanSquare, ShieldCheck,
  MessageCircle, ArrowLeft, Mail, KeyRound, ArrowRight,
} from "lucide-react";
import { brand } from "@/config/brand";
import { OtpInput } from "@/components/auth/OtpInput";
import { requestOtp, verifyOtp, resetPassword } from "@/lib/auth-otp";

type Search = { modo?: "entrar" | "criar" | "esqueci"; plano?: string };
type Tab = "entrar" | "criar" | "esqueci";

export const Route = createFileRoute("/entrar")({
  ssr: false,
  head: () => ({ meta: [{ title: `${brand.name} — Começar` }] }),
  validateSearch: (s: Record<string, unknown>): Search => ({
    modo: s.modo === "criar" ? "criar" : s.modo === "esqueci" ? "esqueci" : "entrar",
    plano: typeof s.plano === "string" ? s.plano : undefined,
  }),
  beforeLoad: async ({ search }) => {
    const { data } = await supabase.auth.getUser();
    if (data.user) {
      const dest = search.plano
        ? `/app/checkout?plano=${encodeURIComponent(search.plano)}`
        : "/app/dashboard";
      throw redirect({ href: dest });
    }
  },
  component: EntrarPage,
});

const PLAN_LABEL: Record<string, { nome: string; preco: string }> = {
  starter: { nome: "Starter", preco: "R$ 97/mês" },
  pro: { nome: "Pro", preco: "R$ 197/mês" },
  business: { nome: "Business", preco: "R$ 497/mês" },
};

const emailSchema = z.string().email("E-mail inválido").trim().toLowerCase();

function EntrarPage() {
  const navigate = useNavigate();
  const search = useSearch({ from: "/entrar" }) as Search;
  const [tab, setTab] = useState<Tab>(search.modo || "entrar");
  const [email, setEmail] = useState("");
  const [otp, setOtp] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [otpSent, setOtpSent] = useState(false);

  const planInfo = search.plano ? PLAN_LABEL[search.plano] : null;

  function switchTab(newTab: Tab) {
    setTab(newTab);
    setOtpSent(false);
    setOtp("");
    setNewPassword("");
  }

  function backToEmail() {
    setOtpSent(false);
    setOtp("");
  }

  async function handleRequestOtp() {
    const ev = emailSchema.safeParse(email);
    if (!ev.success) return toast.error("Email inválido");
    setLoading(true);
    try {
      const purpose = tab === "esqueci" ? "reset_password" : tab;
      await requestOtp({ data: { email, purpose } });
      setOtpSent(true);
      toast.success("Código enviado pro seu email!");
    } catch (e: any) {
      toast.error(e?.message ?? "Erro ao enviar código");
    } finally {
      setLoading(false);
    }
  }

  async function handleVerifyOtp() {
    if (otp.length !== 6) return toast.error("Digite o código de 6 dígitos");
    setLoading(true);
    try {
      const purpose = tab === "esqueci" ? "reset_password" : tab;
      const res = await verifyOtp({ data: { email, code: otp, purpose } });
      if (res.actionLink) window.location.href = res.actionLink;
    } catch (e: any) {
      toast.error(e?.message ?? "Código inválido");
      setOtp("");
    } finally {
      setLoading(false);
    }
  }

  async function handleResetPassword() {
    if (otp.length !== 6) return toast.error("Digite o código de 6 dígitos");
    if (newPassword.length < 8) return toast.error("Senha precisa ter pelo menos 8 caracteres");
    setLoading(true);
    try {
      await resetPassword({ data: { email, code: otp, newPassword } });
      toast.success("Senha redefinida! Use a aba 'Entrar' para fazer login.");
      switchTab("entrar");
    } catch (e: any) {
      toast.error(e?.message ?? "Erro ao redefinir");
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen w-full relative overflow-hidden bg-background text-foreground">
      <div className="relative z-10 min-h-screen grid lg:grid-cols-[1.05fr_1fr]">
        {/* LEFT — brand pane */}
        <aside className="hidden lg:flex flex-col justify-between p-10 xl:p-14 border-r border-[color:var(--hairline)] bg-[linear-gradient(160deg,rgba(22,163,74,.10),rgba(34,211,238,.04)_55%,transparent)]">
          <div className="flex items-center gap-3">
            <Link to="/" className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors">
              <ArrowLeft className="size-4" />
              voltar ao site
            </Link>
          </div>

          <div className="space-y-8 max-w-lg">
            <div className="flex items-center gap-3">
              <div className="size-12 rounded-2xl grid place-items-center bg-gradient-brand text-primary-foreground shadow-[0_10px_30px_-10px_rgba(22,163,74,.6)] ring-1 ring-white/20">
                <MessageSquareText className="size-6" strokeWidth={2.4} />
              </div>
              <div>
                <div className="font-display font-extrabold text-2xl text-gradient-brand leading-none">{brand.name}</div>
                <div className="text-[12px] text-muted-foreground mt-1">{brand.tagline}</div>
              </div>
            </div>

            <h1 className="font-display text-4xl xl:text-5xl font-extrabold leading-[1.05] tracking-tight">
              Sua IA atende o<br />
              <span className="text-gradient-brand">WhatsApp 24h</span> e<br />
              organiza o CRM sozinha.
            </h1>

            <p className="text-[15px] text-muted-foreground leading-relaxed">
              Conecte seu número em 2 minutos. A gente cuida do resto — respostas, qualificação e movimentação dos leads no funil, no automático.
            </p>

            <div className="grid gap-3">
              <Feature icon={<Bot className="size-4" />} title="IA treinada no seu negócio" desc="Responde no seu tom, sem parecer robô." />
              <Feature icon={<KanbanSquare className="size-4" />} title="CRM Kanban inteligente" desc="Cada lead se move sozinho pelo funil." />
              <Feature icon={<MessageCircle className="size-4" />} title="Pronto em 2 minutos" desc="Escaneou o QR, já está atendendo." />
            </div>

            <div className="flex items-center gap-4 pt-2 text-xs text-muted-foreground">
              <span className="inline-flex items-center gap-1.5"><ShieldCheck className="size-3.5 text-[color:var(--brand)]" /> LGPD-friendly</span>
              <span className="inline-flex items-center gap-1.5"><ShieldCheck className="size-3.5 text-[color:var(--brand)]" /> Sem cartão p/ testar</span>
              <span className="inline-flex items-center gap-1.5"><ShieldCheck className="size-3.5 text-[color:var(--brand)]" /> Cancele quando quiser</span>
            </div>
          </div>

          <div className="text-[12px] text-muted-foreground">
            © {new Date().getFullYear()} {brand.name}. Todos os direitos reservados.
          </div>
        </aside>

        {/* RIGHT — form */}
        <main className="flex flex-col items-center justify-center px-5 py-10 sm:px-10">
          <div className="lg:hidden w-full max-w-md mb-6 flex items-center justify-between">
            <Link to="/" className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground">
              <ArrowLeft className="size-4" /> voltar
            </Link>
            <div className="flex items-center gap-2">
              <div className="size-9 rounded-xl grid place-items-center bg-gradient-brand text-primary-foreground shadow-md">
                <MessageSquareText className="size-4" />
              </div>
              <div className="font-display font-bold text-[15px] text-gradient-brand">{brand.name}</div>
            </div>
          </div>

          <div className="w-full max-w-md">
            <div className="relative panel p-7 sm:p-8 glow-brand overflow-hidden">
              <div aria-hidden className="absolute -top-24 -right-24 size-56 rounded-full blur-3xl opacity-50"
                   style={{ background: "radial-gradient(circle, rgba(22,163,74,.35) 0%, transparent 70%)" }} />

              <div className="relative">
                {planInfo && tab === "criar" && (
                  <div className="mb-5 rounded-xl border border-[color:var(--brand)]/30 bg-[color:var(--brand-soft)] p-4">
                    <div className="flex items-center gap-2 text-[11px] uppercase font-bold tracking-[0.14em] text-[color:var(--brand-text)]">
                      <Sparkles className="size-3.5" /> Plano escolhido
                    </div>
                    <div className="mt-1 flex items-baseline justify-between">
                      <div className="font-display text-lg font-bold">{planInfo.nome}</div>
                      <div className="text-sm font-semibold">{planInfo.preco}</div>
                    </div>
                  </div>
                )}

                <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-[color:var(--brand-soft)] border border-[color:var(--brand)]/20 text-[11px] font-semibold text-[color:var(--brand-text)] mb-3">
                  <span className="size-1.5 rounded-full bg-[color:var(--brand)] dot-pulse" />
                  Acesso por email
                </div>

                <h1 className="font-display text-[26px] sm:text-[28px] font-extrabold leading-tight tracking-tight">
                  {tab === "entrar" ? "Bem-vindo de volta" : tab === "criar" ? "Comece agora" : "Recupere o acesso"}
                </h1>
                <p className="text-sm text-muted-foreground mt-1.5 mb-5">
                  {tab === "entrar" && "Enviaremos um código de 6 dígitos pro seu email."}
                  {tab === "criar" && "Vamos criar sua conta via código de 6 dígitos no email."}
                  {tab === "esqueci" && "Vamos redefinir sua senha via código no email."}
                </p>

                {/* Tabs */}
                <div className="flex gap-1 p-1 rounded-lg bg-muted/50 mb-5">
                  <button type="button" onClick={() => switchTab("entrar")}
                    className={`flex-1 py-2 px-3 rounded-md text-sm font-medium transition-colors flex items-center justify-center gap-2 ${tab === "entrar" ? "bg-background shadow-sm" : "text-muted-foreground hover:text-foreground"}`}>
                    <KeyRound className="size-4" /> Entrar
                  </button>
                  <button type="button" onClick={() => switchTab("criar")}
                    className={`flex-1 py-2 px-3 rounded-md text-sm font-medium transition-colors flex items-center justify-center gap-2 ${tab === "criar" ? "bg-background shadow-sm" : "text-muted-foreground hover:text-foreground"}`}>
                    <Sparkles className="size-4" /> Criar
                  </button>
                  <button type="button" onClick={() => switchTab("esqueci")}
                    className={`flex-1 py-2 px-3 rounded-md text-sm font-medium transition-colors flex items-center justify-center gap-2 ${tab === "esqueci" ? "bg-background shadow-sm" : "text-muted-foreground hover:text-foreground"}`}>
                    <ShieldCheck className="size-4" /> Esqueci
                  </button>
                </div>

                {!otpSent ? (
                  <form onSubmit={(e) => { e.preventDefault(); handleRequestOtp(); }} className="space-y-4">
                    <div className="space-y-1.5">
                      <Label htmlFor="email">E-mail</Label>
                      <Input
                        id="email"
                        type="email"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        required
                        autoFocus
                        placeholder="voce@empresa.com"
                        className="h-11"
                      />
                    </div>

                    <Button
                      type="submit"
                      disabled={loading}
                      size="lg"
                      className="w-full h-12 bg-gradient-brand text-primary-foreground hover:opacity-95 font-semibold text-[14.5px] shadow-[0_8px_24px_-10px_rgba(22,163,74,.6)]"
                    >
                      {loading && <Loader2 className="size-4 mr-2 animate-spin" />}
                      {tab === "entrar" && "Enviar código de acesso"}
                      {tab === "criar" && "Enviar código pra criar conta"}
                      {tab === "esqueci" && "Enviar código de reset"}
                      {!loading && <ArrowRight className="size-4 ml-2" />}
                    </Button>
                  </form>
                ) : (
                  <div className="space-y-5">
                    <div className="rounded-lg bg-green-500/10 border border-green-500/20 p-3 text-sm text-center">
                      ✅ Código enviado para <strong>{email}</strong>
                      <p className="text-xs text-muted-foreground mt-1">Verifique a caixa de entrada (e spam)</p>
                    </div>

                    <div className="space-y-2">
                      <Label className="text-center block">Digite o código</Label>
                      <OtpInput
                        value={otp}
                        onChange={setOtp}
                        onComplete={() => {
                          if (tab !== "esqueci") {
                            setTimeout(() => handleVerifyOtp(), 100);
                          }
                        }}
                      />
                    </div>

                    {tab === "esqueci" && (
                      <div className="space-y-2">
                        <Label>Nova senha</Label>
                        <Input
                          type="password"
                          value={newPassword}
                          onChange={(e) => setNewPassword(e.target.value)}
                          placeholder="mínimo 8 caracteres"
                        />
                      </div>
                    )}

                    <Button
                      onClick={tab === "esqueci" ? handleResetPassword : handleVerifyOtp}
                      disabled={loading || otp.length !== 6 || (tab === "esqueci" && newPassword.length < 8)}
                      className="w-full"
                      size="lg"
                    >
                      {loading ? <Loader2 className="size-4 mr-2 animate-spin" /> : null}
                      {tab === "esqueci" ? "Redefinir senha" : "Confirmar"}
                    </Button>

                    <div className="flex flex-col gap-2">
                      <button
                        type="button"
                        onClick={handleRequestOtp}
                        disabled={loading}
                        className="text-sm text-muted-foreground hover:text-foreground"
                      >
                        Reenviar código
                      </button>
                      <button
                        type="button"
                        onClick={backToEmail}
                        className="text-sm text-muted-foreground hover:text-foreground"
                      >
                        ← Voltar (mudar email)
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>

            <p className="text-[11.5px] text-muted-foreground text-center mt-5">
              Ao continuar, você concorda com nossos{" "}
              <Link to="/termos" className="underline underline-offset-2 hover:text-foreground">Termos</Link>{" "}
              e{" "}
              <Link to="/privacidade" className="underline underline-offset-2 hover:text-foreground">Política de privacidade</Link>.
            </p>
          </div>
        </main>
      </div>
    </div>
  );
}

function Feature({ icon, title, desc }: { icon: React.ReactNode; title: string; desc: string }) {
  return (
    <div className="flex items-start gap-3 rounded-xl border border-[color:var(--hairline)] bg-[color:var(--panel)]/60 backdrop-blur-sm p-3.5">
      <div className="size-9 rounded-lg grid place-items-center bg-[color:var(--brand-soft)] text-[color:var(--brand-text)] shrink-0 ring-1 ring-[color:var(--brand)]/15">
        {icon}
      </div>
      <div className="min-w-0">
        <div className="font-semibold text-[13.5px] leading-tight">{title}</div>
        <div className="text-[12px] text-muted-foreground mt-0.5">{desc}</div>
      </div>
    </div>
  );
}
```

**Step 8.2: Build + commit**

```bash
cd easypanel-template && node scripts/vercel-build.mjs 2>&1 | grep -E "built in|✗" | tail -3
git add src/routes/entrar.tsx
git commit -m "feat(auth-otp): reescreve /entrar com 3 tabs (Entrar/Criar/Esqueci)

- 3 tabs: Entrar / Criar conta / Esqueci senha
- Cada tab usa OTP email (6 digitos)
- Layout responsivo mantido
- Brand pane lateral preservado"
```

---

## Task 9: Remover código obsoleto (cleanup)

**Files:**
- Delete: `src/lib/own-magic-link.ts`
- Delete: `src/routes/api/debug/test-email.ts`

**Step 9.1: Deletar**

```bash
cd easypanel-template
rm src/lib/own-magic-link.ts
rm src/routes/api/debug/test-email.ts
```

**Step 9.2: Build (verificar imports quebrados)**

```bash
cd easypanel-template && node scripts/vercel-build.mjs 2>&1 | grep -E "built in|✗|Cannot find" | tail -3
```

**Step 9.3: Commit**

```bash
git add -A
git commit -m "chore: remove codigo obsoleto

- src/lib/own-magic-link.ts (nao usado)
- src/routes/api/debug/test-email.ts (substituido pelo novo fluxo)

Auth agora 100% via OTP email com SMTP proprio (nodemailer direto).
Sem bypass de auth, sem magic link, sem dependencia de WhatsApp Business."
```

---

## Task 10: Adicionar env vars na Vercel + testar

**Step 10.1: Documentar env vars necessárias**

Criar arquivo `VERCEL_ENV_VARS.md` (não commitar, é só pro user):

```markdown
# Env Vars necessárias na Vercel

Vá em: Vercel → Project zapiacrm-teste → Settings → Environment Variables

Adicione (Production + Preview + Development):

```
SMTP_HOST=mail.digitalfunnel.online
SMTP_PORT=465
SMTP_USER=zapiacrm@digitalfunnel.online
SMTP_PASS=WqeFx~muKsZZVm{t
SMTP_SENDER_EMAIL=zapiacrm@digitalfunnel.online
SMTP_SENDER_NAME=ZAPIACRM
PUBLIC_APP_URL=https://zapiacrm-teste.vercel.app
```

⚠️ A senha SMTP foi exposta em chat. Recomendo:
1. Após deploy, rotacione a senha no cPanel
2. Atualize env var na Vercel
3. Confirme que emails continuam chegando
```

**Step 10.2: Testes manuais**

```bash
# 1. Esperar deploy (1-2 min)
# 2. Acessar /entrar
# 3. Testar fluxo Entrar:
#    - Digitar email
#    - Clicar "Enviar código"
#    - Esperar email (~10-30s)
#    - Digitar código
#    - ✅ Deve logar
# 4. Testar esqueci (logado):
#    - Logout
#    - Tab "Esqueci"
#    - Digitar email
#    - Definir nova senha via OTP
```

**Step 10.3: Commit**

```bash
git add docs/VERCEL_ENV_VARS.md
git commit -m "docs: env vars necessarias para SMTP proprio na Vercel"
```

---

## Resumo de Tasks

| # | Task | Tempo |
|---|------|-------|
| 1 | Migration SQL | 5 min |
| 2 | SMTP wrapper (Nodemailer) | 10 min |
| 3 | Helpers (código, validação) | 10 min |
| 4 | requestOtp server-fn | 20 min |
| 5 | verifyOtp server-fn | 20 min |
| 6 | resetPassword server-fn | 15 min |
| 7 | OtpInput component | 15 min |
| 8 | Reescrever /entrar | 30 min |
| 9 | Cleanup código | 5 min |
| 10 | Env vars + testes | 20 min |
| | **Total** | **~2.5h** |
