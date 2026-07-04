# 🚀 ZAPIACRM — CRM + WhatsApp + IA

Sistema de CRM com WhatsApp (Evolution API) e Inteligência Artificial para automação de vendas.
Feito para rodar no **Vercel** (aplicação) + **Supabase** (banco/auth), na conta do próprio cliente.

> **Você é dono do código.** Depois do deploy, pode editar, colocar sua marca e customizar à vontade.

---

## ⚡ Colocar no ar (~15 min, sem servidor nem terminal)

### 1️⃣ Clone o projeto no seu Vercel

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/jeffersoncharles1007-lang/zapiacrm-easypanel-template&env=GOOGLE_CLIENT_ID,GOOGLE_CLIENT_SECRET,EVOLUTION_API_URL,EVOLUTION_API_KEY&envDescription=Credenciais%20fornecidas%20na%20compra%20(WhatsApp%20e%20Google))

- Faça login com o **seu GitHub** → o Vercel copia o repositório para a sua conta (**o código passa a ser seu**).
- Quando pedir as variáveis, **cole os 4 valores que recebeu na compra**:
  `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `EVOLUTION_API_URL`, `EVOLUTION_API_KEY`.

### 2️⃣ Conecte o banco (Supabase) — 1 clique

No projeto criado no Vercel:
1. Aba **Storage** (ou **Integrations**) → **Supabase** → **Connect**.
2. O Vercel cria um projeto Supabase **na sua conta** e injeta as chaves automaticamente
   (`SUPABASE_URL`, anon key, service role, `POSTGRES_URL_NON_POOLING`).
3. Vá em **Deployments → Redeploy**. No build, as **tabelas são criadas sozinhas**
   (24 migrations aplicadas automaticamente).

### 3️⃣ Acesse e crie sua conta admin

- Abra a URL que o Vercel gerou (ou aponte seu domínio em **Settings → Domains**; HTTPS é automático).
- Clique em **Criar conta** — o primeiro cadastro vira o administrador.
- WhatsApp e Google Agenda **já vêm funcionando** (credenciais compartilhadas).

**Pronto. Sistema no ar.** 🎉

---

## 🔑 Variáveis de ambiente

| Variável | Quem fornece | Segredo? |
|---|---|---|
| `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `SUPABASE_SERVICE_ROLE_KEY`, `POSTGRES_URL_NON_POOLING` | Integração Supabase (automático) | — |
| `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET` | Você recebe na compra | Secret é sim |
| `EVOLUTION_API_URL` / `EVOLUTION_API_KEY` | Você recebe na compra | Key é sim |
| `VITE_PAYMENTS_CLIENT_TOKEN` | Opcional (Paddle) | sim |
| `GOOGLE_API_KEY` / `OPENAI_API_KEY` / `ANTHROPIC_API_KEY` | Opcional — configure depois no painel | sim |

As variáveis `VITE_*` são geradas automaticamente no build (`scripts/vercel-build.mjs`).

---

## 🧱 Como funciona por baixo

- **App:** TanStack Start (React + Vite + Nitro), buildado com `NITRO_PRESET=vercel`.
- **Banco/Auth:** Supabase (Postgres + GoTrue + PostgREST + Realtime), operado pelo Supabase.
- **Migrations:** `supabase/migrations/*.sql` aplicadas no build por `scripts/migrate.mjs` (idempotente).
- **WhatsApp:** Evolution API central (compartilhada).
- **IA:** Google Gemini / OpenAI / Anthropic (chaves opcionais, configuráveis no painel).

---

## 💻 Rodar localmente (opcional, para desenvolvedores)

```bash
npm install
cp .env.example .env.local   # preencha os valores
npm run migrate              # aplica as migrations no seu Supabase
npm run dev
```

---

## 🎨 Colocar sua marca (white-label)

Tudo num arquivo só: **`src/config/brand.ts`**. Trocar ali renomeia e recolore o app inteiro
(aba do navegador, meta tags/SEO, landing page, painel, gráficos e cor primária da UI):

```ts
export const brand = {
  name: "SUA MARCA",                 // nome exibido em todo o app
  headline: "...",                   // subtítulo do <title>/SEO
  description: "...",                 // meta description / compartilhamento
  twitterHandle: "@suamarca",
  primary: "#16A34A",                // cor primária (UI + gráficos)
  logoIcon: "MessageCircle",         // ícone (lucide-react)
};
export const supportWhatsapp = "55...";  // WhatsApp de suporte no rodapé/erros
```

Marca **por empresa** (multi-tenant): cada empresa pode ter logo e cor próprios pelo painel
(`company.logo_url` / `company.primary_color`), que sobrescrevem o padrão acima.

> Strings **técnicas** que NÃO mudam com a marca (de propósito, para não quebrar integrações):
> nome interno das instâncias na Evolution (`zapiacrm_<id>`) e os headers de webhook
> (`X-ZAPIACRM-Signature`). São contrato de protocolo — só altere se souber o impacto.

---

## 📊 Requisitos

- Conta **Vercel** (free serve para começar; domínio próprio pode exigir plano pago).
- Conta **Supabase** (free: 500MB de banco; Pro conforme o uso).

---

Copyright © ZAPIACRM.
