# 📧 Templates de Email do Supabase

Templates HTML prontos pra colar no Supabase Auth. Todos com a identidade visual do **ZAPIACRM** (verde WhatsApp #22C55E + tipografia clean + email-responsivo).

## 🚀 Como aplicar (5 min por template)

### Acessar o painel do Supabase

```
https://app.supabase.com/project/SEU_PROJETO/auth/templates
```

Você verá 4 templates no menu lateral:

- Confirm signup
- **Magic Link** ← mais importante
- Change Email Address
- **Reset Password** ← segundo mais importante

### Para cada template:

1. **Clique no template** (ex: "Magic Link")
2. **Subject** → Cole do `<!-- TEMPLATE -->` no topo do HTML
3. **Body (HTML)** → Clique em "<> Source" ou "Edit as code" → Cole tudo do arquivo
4. **Save** (botão no topo)

## 📋 Mapa de arquivos

| Arquivo | Template no Supabase | Subject sugerido |
|---------|---------------------|------------------|
| `magic-link.html` | **Magic Link / OTP** | `Seu link de acesso ao {{ .BrandName }}` |
| `confirm-signup.html` | **Confirm signup** | `Bem-vindo ao {{ .BrandName }} — confirme seu email` |
| `reset-password.html` | **Reset Password** | `Redefina sua senha — {{ .BrandName }}` |

## 🎨 Customizações disponíveis

Cada template usa variáveis dinâmicas que o Supabase preenche automaticamente:

| Variável | O que vira |
|----------|-----------|
| `{{ .BrandName }}` | Nome configurado em Auth → Custom → Brand name |
| `{{ .SiteURL }}` | URL do app (ex: `zapiacrm-teste.vercel.app`) |
| `{{ .ConfirmationURL }}` | Link único de ação (magic link, reset, etc) |
| `{{ .Email }}` | Email do destinatário |
| `{{ .Token }}` | Token puro (caso queira montar URL custom) |

## 💡 Configurar o nome "ZAPIACRM" nos emails (Alternativa A)

Antes de salvar os templates:

1. Vai em **Authentication → Sign In/Up → Branding** (ou similar)
2. **Site Name** = `ZAPIACRM`
3. **Sender Name** = `ZAPIACRM` ← muda de "Supabase Auth" pra "ZAPIACRM"
4. **Sender Address** fica `noreply@mail.app.supabase.io` (não dá pra mudar sem SMTP custom)
5. Save

Agora o destinatário vê:

```
De:  ZAPIACRM <noreply@mail.app.supabase.io>
Ass:  Seu link de acesso ao ZAPIACRM
```

## 🧪 Como testar depois de colar

1. Acessa `https://seu-app.vercel.app/entrar`
2. Digita teu email
3. Clica "Enviar link de acesso"
4. Verifica caixa de entrada + spam
5. Email deve chegar **com a cara do ZAPIACRM** (logo, botão verde, footer)

## 🎁 Bônus: como personalizar logo no email

Os templates atuais usam um **SVG inline** (ícone de chat verde). Pra usar um logo real (PNG/JPG):

1. Hospeda o logo em algum lugar (Supabase Storage é bom)
2. Substitui o bloco:

```html
<div style="background: rgba(255,255,255,0.2); width: 40px; height: 40px; ...">
  <svg ...>...</svg>
</div>
```

Por:

```html
<img src="https://SEU-PROJETO.supabase.co/storage/v1/object/public/email/logo.png" 
     alt="ZAPIACRM" width="40" height="40" 
     style="border-radius: 8px; display: block;" />
```

## 📌 Quando você for replicar pra um cliente

O nome da marca nos templates será diferente (ex: "ClimaCRM"). Pra fazer replicável:

1. Copia essa pasta `supabase-templates/` pro novo clone
2. **Find & Replace** global: `ZAPIACRM` → `MarcaDoCliente`
3. **Find & Replace** global: `#22C55E` → `#CorPrimariaDoCliente`
4. Cola no Supabase do novo projeto

Boa sorte! 🚀
