# ZAPIACRM

**CRM + WhatsApp + IA em um so lugar.** White-label para voce revender como servico.

![Status](https://img.shields.io/badge/status-production-brightgreen)
![Custo](https://img.shields.io/badge/custo-R$%2030%2Fm%C3%AAs-blue)
![Stack](https://img.shields.io/badge/stack-TanStack%20%2B%20Supabase-blueviolet)

---

## O que e

ZAPIACRM e um SaaS completo de **automacao comercial** que combina:

- **CRM Kanban** (pipeline de leads)
- **WhatsApp integrado** (via Evolution API — gratis e open source)
- **IA generativa** (Gemini) que responde clientes automaticamente
- **Billing automatico** (Kiwify/Cakto/PerfectPay)
- **Multi-tenant com RLS** (cada cliente em area isolada)
- **White-label** (voce troca nome, cor, logo em 1 arquivo)

Voce compra o codigo-fonte, deploya na sua infra, e revende como seu proprio produto para PMEs brasileiras.

---

## Para quem e

Voce e:
- Dono de agencia de marketing/comunicacao
- Consultor de vendas
- Empreendedor SaaS
- Operadora de consorcio, imobiliaria, clinica

E quer oferecer aos seus clientes um sistema tipo "Chatwoot + Pipedrive + GPT" sem pagar $$$ por usuario.

---

## Como funciona (em 3 passos)

### 1. Deploy
Faca fork deste repo, conecte na Vercel, configure env vars (18 vars), rode o SQL. **2-4 horas no total.**

### 2. Customize
Edite `src/config/brand.ts` com nome, cor, logo do seu produto. Faz push. Pronto.

### 3. Venda
Cada cliente = 1 instancia deployada. Cobre R$ 149/mes (Starter), R$ 297/mes (Pro), R$ 597/mes (Business). Suporte self-service com este MANUAL.

---

## Preco de revenda sugerido

| Plano | Usuarios | Mensagens/mes | IA credits | **Preco sugerido** |
|-------|----------|---------------|------------|---------------------|
| Starter | 2 | 2.000 | 100 | **R$ 149/mes** |
| Pro | 8 | 10.000 | 300 | **R$ 297/mes** |
| Business | 30 | 50.000 | 1.000 | **R$ 597/mes** |

### Matematica da sua receita

| Clientes ativos | Receita | Custo operacional | **Lucro** |
|-----------------|---------|-------------------|-----------|
| 5 | R$ 745 | R$ 100 | **R$ 645** |
| 10 | R$ 1.490 | R$ 150 | **R$ 1.340** |
| 20 | R$ 2.980 | R$ 250 | **R$ 2.730** |
| 50 | R$ 7.450 | R$ 500 | **R$ 6.950** |

**Custo fixo**: R$ 30/mes (VPS Evolution) + Supabase Free + Vercel Free = R$ 0 a R$ 100/mes.

---

## Stack tecnologico

| Camada | Tecnologia |
|--------|-----------|
| Frontend + SSR | TanStack Start (React 19 + Vite + Nitro) |
| Banco + Auth | Supabase (Postgres + RLS) |
| WhatsApp | Evolution API (self-hosted, open source) |
| IA | Google Gemini |
| Email | SMTP (Titan, Gmail, etc.) |
| Pagamento | Kiwify / Cakto / PerfectPay |
| Deploy | Vercel (Hobby) |

---

## Como comecar

1. Leia o **[MANUAL.md](MANUAL.md)** (single source of truth tecnico)
2. Use o **[CHECKLIST-PRE-DEPLOY.md](CHECKLIST-PRE-DEPLOY.md)** para nao esquecer nada
3. Siga o **Cap 2 → Cap 9** do MANUAL na ordem

### TL;DR para deploy
```bash
# 1. Fork + clone
git clone https://github.com/SEU-USER/zapiacrm-easypanel-template
cd zapiacrm-easypanel-template

# 2. Instalar deps
bun install

# 3. Conectar Vercel (via UI ou CLI)
vercel link

# 4. Setar env vars (18 vars - ver .env.example)

# 5. Deploy
vercel --prod deploy --yes
```

---

## Suporte

Este e um produto **self-service**. Suporte human nao esta incluido.

**Recursos de ajuda**:
- [MANUAL.md](MANUAL.md) — 10 capitulos cobrindo tudo
- [CHECKLIST-POS-DEPLOY.md](CHECKLIST-POS-DEPLOY.md) — testes apos deploy
- `/api/debug/otp` — endpoint para debug SMTP
- Logs do Vercel: Project → Deployments → Logs
- Logs do Supabase: Project → Logs

**Comunidade**: Use o CLAUDE/ChatGPT para debugar — cole o erro + contexto deste MANUAL.

---

## Roadmap

- [ ] OpenAI / Anthropic providers (hoje so Gemini)
- [ ] Google Calendar integration (codigo existe, falta config)
- [ ] Stripe (alem dos gateways BR)
- [ ] Mobile app (React Native)
- [ ] Multi-tenant compartilhado (1 deploy para N clientes)

---

## Licenca

Uso comercial livre. Voce pode:
- Modificar e revender como seu proprio produto
- Cobrar assinatura dos seus clientes finais
- White-label com sua marca

Voce **NAO pode**:
- Revender o codigo-fonte em si (apenas como produto final)
- Remover atribuicao ao codigo original em forks publicos

---

## Historico

- **v1.1.0** (2026-09-08): Build script unificado, env vars consolidadas, docs self-service
- **v1.0.0** (2026-07-06): Release inicial com auth + WhatsApp + IA + billing

---

**Comece agora**: [MANUAL.md](MANUAL.md) → Cap 1