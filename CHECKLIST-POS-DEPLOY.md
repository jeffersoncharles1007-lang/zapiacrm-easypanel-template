# CHECKLIST POS-DEPLOY - ZAPIACRM

Execute estes testes APOS o deploy, antes de anunciar para clientes.

## TESTES FUNCIONAIS

### Autenticacao
- [ ] Site carrega em `https://seudominio.com.br` (cadeado verde, HTTPS)
- [ ] Pagina `/entrar` mostra 3 abas (Entrar / Criar / Esqueci)
- [ ] Criar conta com email valido funciona
- [ ] Email de boas-vindas chega em menos de 2 minutos (via Titan)
- [ ] Login com email + senha funciona apos cadastro
- [ ] Logout funciona

### Painel Master (primeiro user = admin)
- [ ] Apos cadastro, cai em `/master/painel` ou `/master/welcome`
- [ ] `/master/empresas` lista vazia
- [ ] `/master/planos` mostra 3 planos (Starter/Pro/Business) vindos do seed
- [ ] `/master/configuracoes` mostra webhooks URLs

### WhatsApp
- [ ] `/app/conexao` mostra QR code
- [ ] Escanear QR com WhatsApp real conecta
- [ ] Status muda para "conectado" em <30s
- [ ] Mensagem de teste enviada para o numero conectado eh registrada em `/app/conversas`

### Agente IA (Gemini)
- [ ] Responder uma mensagem do contato via UI dispara resposta automatica
- [ ] Resposta chega no WhatsApp real em <10s
- [ ] Resposta faz sentido contextual (nao "lorem ipsum")

### Billing (se configurou webhook)
- [ ] Webhook URL aparece em `/master/configuracoes`
- [ ] Testar compra de R$ 1 no Kiwify/Cakto
- [ ] Webhook chega e ativa empresa (checar `subscription` no Supabase)
- [ ] Empresa aparece em `/master/empresas`

---

## SEGURANCA

### HTTPS
- [ ] Site usa HTTPS
- [ ] Certificado SSL valido (Vercel faz automatico)
- [ ] HTTP redireciona para HTTPS

### Variaveis de Ambiente
- [ ] Todas as 18 vars configuradas na Vercel
- [ ] Valores sensiveis (SMTP_PASS, *_WEBHOOK_TOKEN) criptografados
- [ ] `SUPABASE_SERVICE_ROLE_KEY` NAO aparece em nenhum bundle client-side

### RLS (Row Level Security)
- [ ] `SETUP_REPLICAVEL.sql` aplicou 57 policies
- [ ] Teste: usuario A nao ve dados de empresa B
- [ ] Webhook de billing valida token (sem `KIWIFY_WEBHOOK_TOKEN`, requests dao 401)

### SMTP
- [ ] Email chega em <2min apos signup
- [ ] Email NAO cai em SPAM
- [ ] SPF/DKIM configurados (recomendado mas opcional)

---

## PERFORMANCE

- [ ] Homepage carrega em <2 segundos
- [ ] Login funciona sem delay perceptivel
- [ ] Painel master carrega rapido
- [ ] Imagens otimizadas (Vercel faz automatico)

---

## MOBILE

- [ ] Site carrega em celular real
- [ ] Menu hamburger funciona
- [ ] Formularios usaveis no touch
- [ ] WhatsApp recebe notificacoes push

---

## REALTIME

- [ ] Migration `20260616130000_enable_realtime.sql` aplicada
- [ ] `SELECT * FROM pg_publication WHERE pubname = 'supabase_realtime'` retorna 1 linha com as 6 tabelas
- [ ] Nova mensagem WhatsApp aparece em `/app/conversas` sem F5

---

## VALIDACAO FINAL - PODE ANUNCIAR?

Quando TODOS os testes Core estao ✅, voce pode comecar a vender.

### Core (obrigatorio)
- [ ] Login funciona
- [ ] Cadastro funciona
- [ ] Email chega
- [ ] Painel master acessivel
- [ ] WhatsApp conecta
- [ ] Webhook billing ativa empresa (se for vender como SaaS)

### Recomendado
- [ ] Dominio customizado (nao `.vercel.app`)
- [ ] SMTP com SPF/DKIM configurado
- [ ] Backups automaticos do Supabase ativos

### Nice to have
- [ ] Google Analytics
- [ ] Sentry para error tracking
- [ ] Webhook de cancelamento testado

**Se core esta OK:** pode anunciar.
**Se recomendado esta faltando:** arrisque anunciar com aviso de "beta".
**Se core esta quebrado:** NAO anuncie. Volte e corrija.