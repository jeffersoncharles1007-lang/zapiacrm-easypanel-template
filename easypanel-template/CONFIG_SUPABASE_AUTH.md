# 🔧 Configuração necessária no Supabase Dashboard

## 1. Adicionar URL de redirect para o magic link

1. Acesse: **https://app.supabase.com/project/SEU_PROJETO/auth/url-configuration**
   (ou: Authentication → URL Configuration)

2. Em **"Site URL"** coloque:
   ```
   https://zapiacrm-teste.vercel.app
   ```

3. Em **"Redirect URLs"** adicione (uma por linha):
   ```
   https://zapiacrm-teste.vercel.app/entrar/callback
   https://zapiacrm-teste.vercel.app/entrar
   https://zapiacrm-teste.vercel.app/app/**
   https://zapiacrm-teste.vercel.app/master/**
   http://localhost:3000/entrar/callback
   http://localhost:3000/entrar
   ```

4. Click **Save**

## 2. Habilitar Magic Link / OTP login

1. Acesse: **Authentication → Sign In/Up → Email**

2. Certifique-se que **"Enable Email Signup"** está ON

3. **"Confirm email"** = opcional (se ON, user precisa confirmar; se OFF, entra direto)

4. Clique em **"Email Template"** → personalize (opcional):
   - Subject: `Seu link de acesso ao {{ .SiteURL }}`
   - Body: HTML bonitinho com botão "Acessar minha conta"

## 3. Verificar provedor Email

1. **Authentication → Providers → Email**
2. **Confirm email toggle** → mantém ON para produção
3. **Secure email change** → ON

---

# 🔄 O fluxo após essa config:

```
✅ Cliente paga → webhook valida e ativa company
✅ Cliente recebe email "Bem-vindo, ative sua conta"
✅ Cliente clica no magic link → /entrar/callback
✅ Callback cria user (se não existir) + loga direto
✅ User cai em /master/welcome (se 1º user) ou /app/*
```

---

# 🆕 Sobre o webhook auto-criar usuário do cliente

Atualmente se `buyer_email` não tiver `auth.users`, o webhook só ativa a empresa mas o cliente não consegue entrar.

**Vou implementar essa lógica na billing.functions.ts:**
```typescript
// Quando webhook recebe compra
if (!existsAuthUser(buyer_email)) {
  // Cria user via admin.auth.createUser
  // Envia magic link via signInWithOtp
}
```

Quer que eu implemente essa melhoria?
