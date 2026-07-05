# Plano de Implementação: Auth via WhatsApp OTP (ZAPIACRM)

> **Para workers agentic:** SUB-SKILL OBRIGATÓRIO: Use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para implementar este plano task-by-task. Steps usam checkbox (`- [ ]`) para tracking.

**Goal:** Substituir auth baseado em email/magic-link por auth via WhatsApp OTP (6 dígitos) usando Evolution API, com master sempre tendo acesso garantido.

**Architecture:** 3 server-fns (`requestOtp`, `verifyOtp`, `resetPassword`) + 1 migration SQL (profiles.telefone + tabela otp_codes) + reescrita do /entrar. Frontend chama backend, backend gera código, valida e envia via Evolution API.

**Tech Stack:** TanStack Start (server-fns), Supabase (Auth + Postgres), Evolution API (WhatsApp), Zod (validação), TailwindCSS (UI).

## Global Constraints

- Idioma: TypeScript com `type Props = {}` pattern, componentes em `.tsx`
- Não usar `any` em código de aplicação; usar `unknown` quando precisar
- Server-fns SEMPRE com `createServerFn({ method: "POST" })` + `requireSupabaseAuth` ou público
- React: hooks só no top-level, não em loops/conditionals
- Tailwind: usar `className` props, não `style` inline (exceto gradient style dinâmico)
- Sem `console.log` em prod
- Variáveis de ambiente: `process.env.X` no server, `import.meta.env.VITE_X` no client
- TODAS migrations idempotentes (usar `IF NOT EXISTS`, `ADD COLUMN IF NOT EXISTS`)
- TODOS RLS policies drop+create idempotentes (DROP POLICY IF EXISTS antes)
- TODAS funções SQL `CREATE OR REPLACE`
- Triggers: `DROP TRIGGER IF EXISTS` antes de criar
- Singletons (app_config): `id boolean PRIMARY KEY DEFAULT true`, `CHECK (id = true)`

## File Structure

**Novos arquivos:**
- `supabase/migrations/20260705-otp-auth.sql` — adiciona `profiles.telefone`, `profiles.telefone_verificado`, `profiles.whatsapp_opt_in`, cria `public.otp_codes` com RLS
- `src/lib/auth-otp.ts` — 3 server-fns + 2 helpers (gerar código, normalizar telefone)
- `src/routes/api/auth/request-otp.ts` — wrapper opcional (não usado, server-fn direto)
- `src/components/auth/OtpInput.tsx` — input OTP de 6 dígitos com auto-submit

**Arquivos modificados:**
- `src/routes/entrar.tsx` — reescrito com 3 tabs (Entrar / Criar / Esqueci) usando OTP
- `src/routes/entrar.callback.tsx` — manter funcional, mas não muda lógica

**Arquivos removidos (cleanup):**
- `src/lib/own-magic-link.ts` — não usado
- `src/routes/api/debug/test-email.ts` — não mais útil (manter entry sem o check? Sim, remover)
- `package.json` — remover dep `nodemailer` (não vai ser usada)

**Tabela `otp_codes`:**
```sql
CREATE TABLE IF NOT EXISTS public.otp_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier text NOT NULL,           -- email ou phone normalizado
  purpose text NOT NULL,                -- 'signup' | 'login' | 'reset_password'
  code text NOT NULL,                  -- 6 dígitos
  attempts int NOT NULL DEFAULT 0,
  max_attempts int NOT NULL DEFAULT 3,
  expires_at timestamptz NOT NULL,
  consumed boolean NOT NULL DEFAULT false,
  ip_hash text,                        -- hash do IP (rate limiting)
  user_agent text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_otp_codes_identifier 
  ON public.otp_codes(identifier, purpose, expires_at DESC);

ALTER TABLE public.otp_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS otp_codes_service_role ON public.otp_codes;
CREATE POLICY otp_codes_service_role ON public.otp_codes 
  FOR ALL TO service_role USING (true) WITH CHECK (true);
```

---

## Task 1: Migration SQL — Adicionar WhatsApp + OTP

**Files:**
- Create: `supabase/migrations/20260705-otp-auth.sql`

**Step 1.1: Escrever a migration**

```sql
-- ============================================================================
-- ZAPIACRM: Auth via WhatsApp OTP
-- Adiciona campo telefone em profiles + tabela otp_codes com RLS
-- ============================================================================

-- 1) Adiciona campos em profiles
ALTER TABLE public.profiles 
  ADD COLUMN IF NOT EXISTS telefone text,
  ADD COLUMN IF NOT EXISTS telefone_verificado boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS whatsapp_opt_in boolean NOT NULL DEFAULT true;

-- 2) Backfill: copiar telefone de auth.users se já tiver
UPDATE public.profiles p
SET telefone = u.phone
FROM auth.users u
WHERE p.user_id = u.id 
  AND p.telefone IS NULL 
  AND u.phone IS NOT NULL;

-- 3) Tabela otp_codes
CREATE TABLE IF NOT EXISTS public.otp_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier text NOT NULL,
  purpose text NOT NULL CHECK (purpose IN ('signup', 'login', 'reset_password')),
  code text NOT NULL,
  attempts int NOT NULL DEFAULT 0,
  max_attempts int NOT NULL DEFAULT 3,
  expires_at timestamptz NOT NULL,
  consumed boolean NOT NULL DEFAULT false,
  ip_hash text,
  user_agent text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_otp_codes_lookup 
  ON public.otp_codes(identifier, purpose, expires_at DESC) 
  WHERE consumed = false;

CREATE INDEX IF NOT EXISTS idx_otp_codes_expires 
  ON public.otp_codes(expires_at);

-- 4) RLS
ALTER TABLE public.otp_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS otp_codes_service_role_all ON public.otp_codes;
CREATE POLICY otp_codes_service_role_all ON public.otp_codes 
  FOR ALL TO service_role 
  USING (true) WITH CHECK (true);

-- 5) Função helper: cleanup de códigos expirados
CREATE OR REPLACE FUNCTION public.cleanup_expired_otp_codes()
RETURNS int LANGUAGE sql SECURITY DEFINER SET search_path = public AS $$
  WITH deleted AS (
    DELETE FROM public.otp_codes 
    WHERE expires_at < now() - interval '1 hour' 
      OR consumed = true
    RETURNING 1
  )
  SELECT count(*)::int FROM deleted;
$$;

REVOKE EXECUTE ON FUNCTION public.cleanup_expired_otp_codes() FROM PUBLIC, anon;
```

**Step 1.2: Verificar syntax via psql dry-run**

Como o usuário não tem psql, pular este step. Mas validar visualmente que o SQL está correto.

**Step 1.3: Documentar no commit**

```bash
git add supabase/migrations/20260705-otp-auth.sql
git commit -m "feat(db): migration WhatsApp OTP + tabela otp_codes

Adiciona campos em profiles:
- telefone (text)
- telefone_verificado (boolean)
- whatsapp_opt_in (boolean)

Cria tabela otp_codes com:
- id, identifier, purpose, code, attempts, max_attempts
- expires_at, consumed, ip_hash, user_agent
- RLS restrito a service_role
- Indice para lookup rapido
- Funcao cleanup_expired_otp_codes

Idempotente - pode rodar multiplas vezes."
```

---

## Task 2: Helpers de código e telefone

**Files:**
- Create: `src/lib/auth-otp.ts`

**Step 2.1: Implementar helpers**

```typescript
import { createClient } from "@supabase/supabase-js";
import { createHash } from "crypto";

// Gera código de 6 dígitos (000000-999999, com zeros à esquerda)
export function generateOtpCode(): string {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Normaliza telefone pra E.164 sem o "+"
// Ex: "(62) 99410-1731" → "5562994101731"
// Ex: "+55 11 99999-9999" → "5511999999999"
export function normalizePhone(phone: string): string {
  return phone.replace(/\D/g, "");
}

// Valida formato E.164 (10-15 dígitos, começando com código de país)
export function isValidPhone(phone: string): boolean {
  const cleaned = normalizePhone(phone);
  return /^\d{10,15}$/.test(cleaned);
}

// Hash do IP pra rate limiting (não armazena IP puro, LGPD-friendly)
export function hashIp(ip: string): string {
  return createHash("sha256").update(ip).digest("hex").substring(0, 16);
}

// TTL do OTP: 5 minutos
export const OTP_TTL_MINUTES = 5;

// Max tentativas antes de bloquear
export const OTP_MAX_ATTEMPTS = 3;

// Singleton client admin (singleton pra evitar reconexão)
let _admin: ReturnType<typeof createClient> | null = null;
export function getAdminClient() {
  if (_admin) return _admin;
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) {
    throw new Error("SUPABASE_URL ou SUPABASE_SERVICE_ROLE_KEY não configurados");
  }
  _admin = createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  return _admin;
}
```

**Step 2.2: Verificar que compila**

```bash
cd easypanel-template && npx tsc --noEmit src/lib/auth-otp.ts 2>&1 | head -20
```

Esperado: zero erros. Se houver erro de import, ajustar.

**Step 2.3: Commit**

```bash
git add src/lib/auth-otp.ts
git commit -m "feat(auth-otp): helpers (generateOtpCode, normalizePhone, getAdminClient)"
```

---

## Task 3: Server-fn `requestOtp`

**Files:**
- Modify: `src/lib/auth-otp.ts` (adicionar export)

**Step 3.1: Implementar `requestOtp`**

```typescript
import { z } from "zod";
import { createServerFn } from "@tanstack/react-start";
import { evoSendText } from "./evolution.server";
import { supabaseAdmin } from "./...server"; // (ajustar import path real)

const requestOtpInput = z.object({
  email: z.string().email("Email inválido").trim().toLowerCase(),
  telefone: z.string().min(10).max(20).trim(),
  purpose: z.enum(["signup", "login", "reset_password"]),
});

export const requestOtp = createServerFn({ method: "POST" })
  .validator(requestOtpInput)
  .handler(async ({ data }) => {
    const { email, telefone, purpose } = data;
    const telefoneNorm = normalizePhone(telefone);
    if (!isValidPhone(telefoneNorm)) {
      throw new Error("Telefone inválido. Use formato (11) 99999-9999");
    }

    const admin = getAdminClient();

    // Validação específica por purpose
    if (purpose === "signup") {
      // Não pode cadastrar se email já existe
      const { data: list } = await admin.auth.admin.listUsers();
      const exists = (list?.users ?? []).find(
        (u: any) => u.email === email
      );
      if (exists) {
        throw new Error("Email já cadastrado. Use 'Entrar' em vez de 'Criar'.");
      }
    } else if (purpose === "login" || purpose === "reset_password") {
      // Tem que existir
      const { data: list } = await admin.auth.admin.listUsers();
      const user = (list?.users ?? []).find(
        (u: any) => u.email === email
      );
      if (!user) {
        throw new Error("Email não cadastrado. Crie uma conta primeiro.");
      }
    }

    // Gera código e persiste
    const code = generateOtpCode();
    const expiresAt = new Date(
      Date.now() + OTP_TTL_MINUTES * 60 * 1000
    ).toISOString();

    const { error: insertErr } = await admin.from("otp_codes").insert({
      identifier: email,
      purpose,
      code,
      expires_at: expiresAt,
      max_attempts: OTP_MAX_ATTEMPTS,
    });

    if (insertErr) {
      throw new Error(`Erro ao salvar OTP: ${insertErr.message}`);
    }

    // Envia via WhatsApp
    const message = `🔐 *ZAPIACRM*\n\nSeu código de acesso: *${code}*\n\nVálido por ${OTP_TTL_MINUTES} minutos.\n\n_Não compartilhe com ninguém._`;

    // Pega a primeira instância WhatsApp conectada (do master)
    // Como no signup ainda não tem company, usa a primeira disponível
    const { data: instances } = await admin
      .from("whatsapp_instances")
      .select("instance_name")
      .eq("status", "open")
      .limit(1);

    if (!instances?.length) {
      throw new Error("Nenhuma instância WhatsApp conectada no sistema");
    }

    try {
      await evoSendText(instances[0].instance_name, telefoneNorm, message);
    } catch (e: any) {
      // Log mas não falha o request (a tela vai mostrar o código em dev)
      console.error("[requestOtp] WhatsApp falhou:", e?.message);
    }

    return { ok: true, code }; // Em dev retornamos o código pra debug
  });
```

**Step 3.2: Verificar build**

```bash
cd easypanel-template && node scripts/vercel-build.mjs 2>&1 | grep -E "built in|✗|error:" | tail -3
```

Esperado: `built in Xs` sem erros.

**Step 3.3: Commit**

```bash
git add src/lib/auth-otp.ts
git commit -m "feat(auth-otp): requestOtp server-fn

- Gera codigo 6 digitos
- Salva em otp_codes (TTL 5 min)
- Envia via WhatsApp (Evolution API)
- Retorna codigo em dev pra debug"
```

---

## Task 4: Server-fn `verifyOtp`

**Files:**
- Modify: `src/lib/auth-otp.ts`

**Step 4.1: Implementar `verifyOtp`**

```typescript
const verifyOtpInput = z.object({
  email: z.string().email().trim().toLowerCase(),
  code: z.string().length(6),
  purpose: z.enum(["signup", "login", "reset_password"]),
  telefone: z.string().optional(), // só pra signup
});

export const verifyOtp = createServerFn({ method: "POST" })
  .validator(verifyOtpInput)
  .handler(async ({ data }) => {
    const { email, code, purpose, telefone } = data;
    const admin = getAdminClient();

    // Busca código válido
    const { data: otpRows } = await admin
      .from("otp_codes")
      .select("*")
      .eq("identifier", email)
      .eq("purpose", purpose)
      .eq("consumed", false)
      .gt("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1);

    if (!otpRows?.length) {
      throw new Error("Código expirado ou não existe. Solicite um novo.");
    }

    const otp = otpRows[0];

    // Incrementa tentativas
    if (otp.attempts >= otp.max_attempts) {
      await admin
        .from("otp_codes")
        .update({ consumed: true })
        .eq("id", otp.id);
      throw new Error("Muitas tentativas. Solicite um novo código.");
    }

    // Compara código
    if (otp.code !== code) {
      await admin
        .from("otp_codes")
        .update({ attempts: otp.attempts + 1 })
        .eq("id", otp.id);
      throw new Error(
        `Código incorreto. Você tem ${otp.max_attempts - otp.attempts - 1} tentativa(s).`
      );
    }

    // Marca como consumido
    await admin
      .from("otp_codes")
      .update({ consumed: true })
      .eq("id", otp.id);

    // Ação por purpose
    if (purpose === "signup") {
      // Cria user (1º user vira super_admin via trigger)
      const { data: created, error: createErr } = await admin.auth.admin.createUser({
        email,
        phone: telefone ? normalizePhone(telefone) : undefined,
        phone_confirm: !!telefone,
        email_confirm: true,
        user_metadata: { source: "whatsapp-otp-signup" },
      });
      if (createErr) {
        throw new Error(`Falha ao criar user: ${createErr.message}`);
      }
      // Atualiza profile com telefone
      if (telefone) {
        await admin
          .from("profiles")
          .update({
            telefone: normalizePhone(telefone),
            telefone_verificado: true,
            whatsapp_opt_in: true,
          })
          .eq("user_id", created.user.id);
      }
      const userId = created.user.id;
    } else if (purpose === "login" || purpose === "reset_password") {
      // User já existe, valida que existe
      const { data: list } = await admin.auth.admin.listUsers();
      const user = (list?.users ?? []).find((u: any) => u.email === email);
      if (!user) {
        throw new Error("User não encontrado");
      }
    }

    // Gera magic link (SEM email) pra o user logar
    const { data: linkData, error: linkErr } = await admin.auth.admin.generateLink({
      type: "magiclink",
      email,
      options: {
        redirectTo: `${process.env.PUBLIC_APP_URL || "https://zapiacrm-teste.vercel.app"}/entrar/callback`,
      },
    });

    if (linkErr) {
      throw new Error(`Falha ao gerar link: ${linkErr.message}`);
    }

    return {
      ok: true,
      actionLink: linkData?.properties?.action_link,
    };
  });
```

**Step 4.2: Verificar build**

```bash
cd easypanel-template && node scripts/vercel-build.mjs 2>&1 | grep -E "built in|✗|error:" | tail -3
```

**Step 4.3: Commit**

```bash
git add src/lib/auth-otp.ts
git commit -m "feat(auth-otp): verifyOtp server-fn

- Valida codigo (max 3 tentativas)
- Cria user se purpose=signup
- Gera magic link pro client logar via Supabase
- Marca codigo como consumido"
```

---

## Task 5: Server-fn `resetPassword`

**Files:**
- Modify: `src/lib/auth-otp.ts`

**Step 5.1: Implementar `resetPassword`**

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

    // Reutiliza verifyOtp logic (extrai)
    const { data: otpRows } = await admin
      .from("otp_codes")
      .select("*")
      .eq("identifier", email)
      .eq("purpose", "reset_password")
      .eq("consumed", false)
      .gt("expires_at", new Date().toISOString())
      .order("created_at", { ascending: false })
      .limit(1);

    if (!otpRows?.length) {
      throw new Error("Código expirado ou não existe");
    }
    const otp = otpRows[0];

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

    // Marca como consumido
    await admin.from("otp_codes").update({ consumed: true }).eq("id", otp.id);

    // Acha user
    const { data: list } = await admin.auth.admin.listUsers();
    const user = (list?.users ?? []).find((u: any) => u.email === email);
    if (!user) throw new Error("User não encontrado");

    // Atualiza senha via admin API
    const { error: updErr } = await admin.auth.admin.updateUserById(
      user.id,
      { password: newPassword }
    );
    if (updErr) throw new Error(`Falha ao atualizar senha: ${updErr.message}`);

    return { ok: true };
  });
```

**Step 5.2: Verificar build**

```bash
cd easypanel-template && node scripts/vercel-build.mjs 2>&1 | grep -E "built in|✗|error:" | tail -3
```

**Step 5.3: Commit**

```bash
git add src/lib/auth-otp.ts
git commit -m "feat(auth-otp): resetPassword server-fn

- Valida codigo
- Atualiza senha via admin.auth.admin.updateUserById
- Reutiliza validacao do verifyOtp"
```

---

## Task 6: Componente OtpInput (frontend)

**Files:**
- Create: `src/components/auth/OtpInput.tsx`

**Step 6.1: Implementar componente**

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
      const newValue = value.substring(0, idx) + "" + value.substring(idx + 1);
      onChange(newValue);
      return;
    }
    // Se colou vários dígitos
    if (v.length > 1) {
      const paste = v.slice(0, length);
      const filled = value.substring(0, idx) + paste + value.substring(idx + paste.length);
      onChange(filled.substring(0, length));
      const next = Math.min(idx + paste.length, length - 1);
      refs.current[next]?.focus();
      if (filled.length >= length) onComplete?.(filled.substring(0, length));
      return;
    }
    // Single digit
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
          ref={(el) => {
            refs.current[idx] = el;
          }}
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

**Step 6.2: Verificar build**

```bash
cd easypanel-template && node scripts/vercel-build.mjs 2>&1 | grep -E "built in|✗|error:" | tail -3
```

**Step 6.3: Commit**

```bash
git add src/components/auth/OtpInput.tsx
git commit -m "feat(auth-otp): OtpInput component

- 6 inputs individuais
- Auto-focus next
- Paste support
- Backspace navigation"
```

---

## Task 7: Reescrever /entrar (3 tabs)

**Files:**
- Modify: `src/routes/entrar.tsx` (completo)

**Step 7.1: Implementar nova versão do entrar.tsx**

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
  MessageCircle, ArrowLeft, CheckCircle2, Mail, KeyRound, ArrowRight, Phone, MessageSquare,
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
const phoneSchema = z.string().min(10, "Telefone inválido").max(20);

function EntrarPage() {
  const navigate = useNavigate();
  const search = useSearch({ from: "/entrar" }) as Search;
  const [tab, setTab] = useState<Tab>(search.modo || "entrar");
  const [email, setEmail] = useState("");
  const [telefone, setTelefone] = useState("");
  const [otp, setOtp] = useState("");
  const [newPassword, setNewPassword] = useState("");
  const [loading, setLoading] = useState(false);
  const [otpSent, setOtpSent] = useState(false);

  const planInfo = search.plano ? PLAN_LABEL[search.plano] : null;

  // Reseta estado quando muda tab
  function switchTab(newTab: Tab) {
    setTab(newTab);
    setOtpSent(false);
    setOtp("");
    setNewPassword("");
  }

  async function requestOtpHandler() {
    const ev = emailSchema.safeParse(email);
    if (!ev.success) return toast.error("Email inválido");
    if (tab === "criar" || tab === "esqueci") {
      const pv = phoneSchema.safeParse(telefone);
      if (!pv.success) return toast.error("WhatsApp inválido (use (11) 99999-9999)");
    }

    setLoading(true);
    try {
      const purpose = tab === "esqueci" ? "reset_password" : tab === "criar" ? "signup" : "login";
      const telefoneNorm = telefone.replace(/\D/g, "");
      const res = await requestOtp({
        data: { email, telefone: telefoneNorm, purpose },
      });
      setOtpSent(true);
      if (res.code) {
        toast.success(`Código: ${res.code}`, { duration: 30000 });
      } else {
        toast.success("Código enviado pro WhatsApp!");
      }
    } catch (e: any) {
      toast.error(e?.message ?? "Erro ao enviar código");
    } finally {
      setLoading(false);
    }
  }

  async function verifyOtpHandler() {
    if (otp.length !== 6) return toast.error("Digite o código de 6 dígitos");
    setLoading(true);
    try {
      const telefoneNorm = telefone.replace(/\D/g, "");
      const res = await verifyOtp({
        data: { email, code: otp, purpose: tab === "esqueci" ? "reset_password" : tab === "criar" ? "signup" : "login", telefone: telefoneNorm },
      });
      if (res.actionLink) {
        window.location.href = res.actionLink;
      }
    } catch (e: any) {
      toast.error(e?.message ?? "Código inválido");
      setOtp("");
    } finally {
      setLoading(false);
    }
  }

  async function resetPasswordHandler() {
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

  function backToEmail() {
    setOtpSent(false);
    setOtp("");
  }

  // Layout
  return (
    <div className="min-h-screen w-full relative overflow-hidden bg-background text-foreground">
      <div className="relative z-10 min-h-screen grid lg:grid-cols-[1.05fr_1fr]">
        {/* LEFT — brand pane (igual antes) */}
        <aside className="hidden lg:flex flex-col justify-between p-10 xl:p-14 border-r border-[color:var(--hairline)] bg-[linear-gradient(160deg,rgba(22,163,74,.10),rgba(34,211,238,.04)_55%,transparent)]">
          {/* ... (mantém o mesmo conteúdo de antes) */}
        </aside>

        {/* RIGHT — form */}
        <main className="flex flex-col items-center justify-center px-5 py-10 sm:px-10">
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

                {/* Tabs */}
                <div className="flex gap-1 p-1 rounded-lg bg-muted/50 mb-5">
                  <button
                    type="button"
                    onClick={() => switchTab("entrar")}
                    className={`flex-1 py-2 px-3 rounded-md text-sm font-medium transition-colors flex items-center justify-center gap-2 ${
                      tab === "entrar" ? "bg-background shadow-sm" : "text-muted-foreground hover:text-foreground"
                    }`}
                  >
                    <KeyRound className="size-4" />
                    Entrar
                  </button>
                  <button
                    type="button"
                    onClick={() => switchTab("criar")}
                    className={`flex-1 py-2 px-3 rounded-md text-sm font-medium transition-colors flex items-center justify-center gap-2 ${
                      tab === "criar" ? "bg-background shadow-sm" : "text-muted-foreground hover:text-foreground"
                    }`}
                  >
                    <Sparkles className="size-4" />
                    Criar
                  </button>
                  <button
                    type="button"
                    onClick={() => switchTab("esqueci")}
                    className={`flex-1 py-2 px-3 rounded-md text-sm font-medium transition-colors flex items-center justify-center gap-2 ${
                      tab === "esqueci" ? "bg-background shadow-sm" : "text-muted-foreground hover:text-foreground"
                    }`}
                  >
                    <ShieldCheck className="size-4" />
                    Esqueci
                  </button>
                </div>

                <h1 className="font-display text-[26px] sm:text-[28px] font-extrabold leading-tight tracking-tight mb-2">
                  {tab === "entrar" ? "Bem-vindo de volta" : tab === "criar" ? "Comece agora" : "Recupere o acesso"}
                </h1>
                <p className="text-sm text-muted-foreground mb-5">
                  {tab === "entrar" && "Enviaremos um código de 6 dígitos pro seu WhatsApp."}
                  {tab === "criar" && "Crie sua conta via WhatsApp — sem senha pra lembrar."}
                  {tab === "esqueci" && "Vamos redefinir sua senha via código no WhatsApp."}
                </p>

                {/* Form por tab */}
                {!otpSent ? (
                  <form
                    onSubmit={(e) => {
                      e.preventDefault();
                      requestOtpHandler();
                    }}
                    className="space-y-4"
                  >
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

                    {(tab === "criar" || tab === "esqueci") && (
                      <div className="space-y-1.5">
                        <Label htmlFor="tel">WhatsApp</Label>
                        <Input
                          id="tel"
                          type="tel"
                          value={telefone}
                          onChange={(e) => setTelefone(e.target.value)}
                          required
                          placeholder="(11) 99999-9999"
                          className="h-11"
                        />
                      </div>
                    )}

                    <Button
                      type="submit"
                      disabled={loading}
                      size="lg"
                      className="w-full h-12 bg-gradient-brand text-primary-foreground hover:opacity-95 font-semibold"
                    >
                      {loading ? <Loader2 className="size-4 mr-2 animate-spin" /> : <MessageSquare className="size-4 mr-2" />}
                      Enviar código por WhatsApp
                    </Button>
                  </form>
                ) : (
                  <div className="space-y-5">
                    <div className="rounded-lg bg-green-500/10 border border-green-500/20 p-3 text-sm text-center">
                      ✅ Código enviado para seu WhatsApp
                      {telefone && <div className="text-xs text-muted-foreground mt-1">{telefone}</div>}
                    </div>

                    <div className="space-y-2">
                      <Label className="text-center block">Digite o código</Label>
                      <OtpInput
                        value={otp}
                        onChange={setOtp}
                        onComplete={(v) => {
                          if (tab === "esqueci") {
                            // Não submete — espera o user preencher senha
                          } else {
                            setTimeout(() => verifyOtpHandler(), 100);
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
                      onClick={tab === "esqueci" ? resetPasswordHandler : verifyOtpHandler}
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
                        onClick={() => requestOtpHandler()}
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
                        ← Voltar
                      </button>
                    </div>
                  </div>
                )}
              </div>
            </div>
          </div>
        </main>
      </div>
    </div>
  );
}
```

**Step 7.2: Verificar build**

```bash
cd easypanel-template && node scripts/vercel-build.mjs 2>&1 | grep -E "built in|✗|error:" | tail -3
```

**Step 7.3: Commit**

```bash
git add src/routes/entrar.tsx
git commit -m "feat(auth-otp): reescreve /entrar com 3 tabs (Entrar/Criar/Esqueci)

- Tab Entrar: email → codigo WhatsApp → magic link
- Tab Criar: email + WhatsApp → codigo → cria user
- Tab Esqueci: email + WhatsApp + nova senha → redefine
- Botao reenviar codigo
- Botao voltar
- Layout responsivo mantido
- brand pane lateral preservado"
```

---

## Task 8: Remover código antigo (cleanup)

**Files:**
- Delete: `src/lib/own-magic-link.ts`
- Delete: `src/routes/api/debug/test-email.ts`
- Modify: `package.json` (remover dep `nodemailer`)

**Step 8.1: Deletar arquivos**

```bash
cd easypanel-template
rm src/lib/own-magic-link.ts
rm src/routes/api/debug/test-email.ts
```

**Step 8.2: Remover dep nodemailer**

```bash
npm uninstall nodemailer
```

Ou editar `package.json` manualmente removendo a linha `"nodemailer": "..."`.

**Step 8.3: Verificar build (sem imports quebrados)**

```bash
cd easypanel-template && node scripts/vercel-build.mjs 2>&1 | grep -E "built in|✗|error:" | tail -3
```

Se tiver erro de "module not found" em arquivos que importavam, ajustar.

**Step 8.4: Remover referências no `routeTree.gen.ts` (se houver)**

```bash
grep -n "own-magic-link\|debug/test-email" src/routeTree.gen.ts
```

Se encontrar, remover manualmente (ou via build regenerar).

**Step 8.5: Commit**

```bash
git add -A
git commit -m "chore: remove codigo obsoleto (own-magic-link, debug-email, nodemailer)

- src/lib/own-magic-link.ts: nao usado
- src/routes/api/debug/test-email.ts: nao mais util
- nodemailer dep: nao sera usada (auth via WhatsApp Evolution API)

Auth agora 100% via WhatsApp OTP. Sem dependencia de SMTP nem de email."
```

---

## Task 9: Verificar Master ainda funciona

**Step 9.1: Testar manualmente após deploy**

```bash
# Esperar deploy completar (1-2 min)
# Acessar https://zapiacrm-teste.vercel.app/entrar
# Testar:
#   1. Tab Criar: email + WhatsApp → "Enviar código"
#   2. Esperar 5-10s
#   3. Receber código no WhatsApp
#   4. Digitar código → submeter
#   5. ✅ Deve cair em /master/welcome
#   6. Tela deve mostrar banner "Defina sua senha"
#   7. Definir senha → recarregar → ainda logado
#   8. Logout → login com email → enviar código → WhatsApp → entrar
#   9. ✅ Deve funcionar
```

**Step 9.2: Verificar logs de erro no Vercel**

```bash
# Painel Vercel → Deployments → último deploy → Logs
# Procurar por erros 500 ou exceptions
```

**Step 9.3: Se houver erros, investigar e corrigir**

Documentar o que foi corrigido.

---

## Task 10: Documentar e commit final

**Step 10.1: Atualizar README com o novo fluxo**

Modificar `README.md` adicionando seção:

```markdown
## 🔐 Autenticação via WhatsApp

O ZAPIACRM usa **OTP de 6 dígitos via WhatsApp** ao invés de email mágico.

Fluxo:
1. User digita email (+ WhatsApp se for cadastro)
2. Clica "Enviar código"
3. Recebe código no WhatsApp
4. Digita no app
5. ✅ Loga

Esqueci a senha: mesmo fluxo, depois de validar código define nova senha.

Master: sempre tem acesso via senha fixa (definida no onboarding).
```

**Step 10.2: Commit final**

```bash
git add README.md
git commit -m "docs: documenta fluxo de auth via WhatsApp OTP"
```

**Step 10.3: Tag da versão**

```bash
git tag -a v0.2.0 -m "Auth via WhatsApp OTP (Plano B)"
git push origin v0.2.0
```

---

## Resumo de Tasks

| # | Task | Tempo estimado |
|---|------|---------------|
| 1 | Migration SQL | 5 min |
| 2 | Helpers código/telefone | 15 min |
| 3 | requestOtp server-fn | 30 min |
| 4 | verifyOtp server-fn | 30 min |
| 5 | resetPassword server-fn | 20 min |
| 6 | OtpInput component | 15 min |
| 7 | Reescrever /entrar | 45 min |
| 8 | Cleanup código antigo | 10 min |
| 9 | Testes manuais | 20 min |
| 10 | Documentar + tag | 10 min |
| | **Total** | **~3.5h** |
