# Env Vars necessárias na Vercel (SMTP próprio)

Vá em: **Vercel → Project zapiacrm-teste → Settings → Environment Variables**

Adicione em **Production + Preview + Development**:

```
SMTP_HOST=mail.digitalfunnel.online
SMTP_PORT=465
SMTP_USER=zapiacrm@digitalfunnel.online
SMTP_PASS=WqeFx~muKsZZVm{t
SMTP_SENDER_EMAIL=zapiacrm@digitalfunnel.online
SMTP_SENDER_NAME=ZAPIACRM
PUBLIC_APP_URL=https://zapiacrm-teste.vercel.app
```

## ⚠️ Senha SMTP exposta

A senha SMTP (`WqeFx~muKsZZVm{t`) foi compartilhada em chat. **Recomendo rotacionar** após deploy:

1. Login no cPanel do digitalfunnel.online
2. Vá em **Email Accounts** → selecione `zapiacrm@digitalfunnel.online`
3. Clica **"Manage"** → **"Password & Authentication"**
4. Gera nova senha
5. Atualiza env var `SMTP_PASS` na Vercel
6. Faz redeploy (Settings → Deployments → último deploy → "..." → Redeploy)

## 🧪 Como testar fluxo end-to-end

### Pré-requisitos

1. ✅ Migration `20260705-otp-auth.sql` aplicada no Supabase (cria tabela `otp_codes`)
2. ✅ Env vars configuradas na Vercel (lista acima)
3. ✅ Deploy em produção (após último commit)
4. ✅ Senha SMTP do cPanel não foi trocada (ou trocou e atualizou na Vercel)

### Teste 1: Cadastro de master

1. Acessa `https://zapiacrm-teste.vercel.app/entrar`
2. Clica aba "Criar"
3. Digita email: `seu-email-real@gmail.com` (NÃO use `zapiacrm@digitalfunnel.online` porque é o sender)
4. Clica "Enviar código pra criar conta"
5. **Esperado:** Toast "Código enviado pro seu email!"
6. Vai no seu email (1-2 min)
7. Copia o código de 6 dígitos
8. Cola no app
9. **Esperado:** Auto-submit + redirect pra `/master/welcome`
10. Trigger `handle_new_user` promove você a super_admin
11. ✅ Tela mostra banner "🔐 Defina sua senha"
12. Clica → define senha → confirma
13. ✅ Pronto! Você é o master

### Teste 2: Logout e login (deve pedir código)

1. Clica "Sair" no painel master
2. Volta em `/entrar`
3. Aba "Entrar" (default)
4. Digita o mesmo email
5. Clica "Enviar código de acesso"
6. **Esperado:** Recebe email com código
7. Digita código
8. ✅ Deve logar automaticamente no painel

### Teste 3: Esqueci senha

1. Em `/entrar`, aba "Esqueci"
2. Digita email
3. Clica "Enviar código de reset"
4. **Esperado:** Email com código
5. Digita código
6. Digite nova senha
7. Clica "Redefinir senha"
8. ✅ Deve mostrar "Senha redefinida!" e voltar pra aba Entrar

## 🔍 Onde debugar se algo der errado

### Email não chega

1. Vai em **Vercel → Deployments → último deploy → Logs**
2. Procura por erros relacionados a "sendEmail" ou "SMTP"
3. Se ver "Authentication failed" → senha SMTP errada
4. Se ver "Connection timeout" → porta 465 bloqueada (improvável)
5. Se ver "ENOTFOUND" → host errado

### Trigger handle_new_user não promove

1. Vai em **Supabase → SQL Editor**
2. Roda: `SELECT * FROM public.user_roles;`
3. Se vazio → trigger não rodou
4. Verifica logs do Supabase → Database → Webhooks
5. Possível causa: migration não foi aplicada

### Magic link não funciona após OTP

1. Tela fica "Confirmando..." infinito
2. Vai em `/entrar/callback` e olha console
3. Provavelmente é problema no `generateLink`

## ✅ Checklist final

- [ ] Migration SQL aplicada no Supabase
- [ ] Env vars SMTP configuradas na Vercel (6 vars)
- [ ] Senha SMTP rotacionada (recomendado)
- [ ] Deploy em produção (já está)
- [ ] Teste 1 passou (cadastro master)
- [ ] Teste 2 passou (login)
- [ ] Teste 3 passou (reset)

## 📚 Documentação adicional

- Spec: `docs/superpowers/specs/2026-07-05-zapiacrm-auth-password-design.md`
- Plano: `docs/superpowers/plans/2026-07-05-smtp-otp-auth.md`
- Migration: `supabase/migrations/20260705-otp-auth.sql`
- Server-fns: `src/lib/auth-otp.ts`
- SMTP wrapper: `src/lib/smtp.ts`
- Componente: `src/components/auth/OtpInput.tsx`
- Tela: `src/routes/entrar.tsx`
