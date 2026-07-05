# Sistema de Autenticação Plano A — Password-Based (sem dependência de SMTP)

**Data:** 2026-07-05
**Status:** Design (aguardando aprovação)

## Contexto

O ZAPIACRM usa Supabase Auth que envia magic link por email. O SMTP custom configurado (digitalfunnel.online) não está enviando emails — testes mostram que a INBOX do zapiacrm@digitalfunnel.online está vazia após cadastros.

Tentativas anteriores de "bypass" criaram **vulnerabilidades críticas de impersonation** (qualquer pessoa com o email podia logar como o user). Estas vulnerabilidades foram revertidas (commit 82d09d4).

**Decisão:** Eliminar dependência de email para autenticação. Email fica só para "esqueci senha" (admin master reseta manualmente se precisar).

## Princípios

1. **Segurança em primeiro lugar** — nenhum bypass de auth que pule email
2. **Master sempre consegue entrar** — define senha no primeiro acesso
3. **Cliente tem fluxo claro** — email + senha para entrar
4. **Email é opcional** — apenas para reset (e mesmo assim, admin master pode resetar manualmente)

## Mudanças

### 1. Tela `/entrar` reescrita

**Layout:** única tela com email + senha + botões

```
┌────────────────────────────────────────────┐
│  🟢 ZAPIACRM                                  │
│                                              │
│  Email: [___________________________]       │
│  Senha: [___________________________]       │
│                                              │
│  [Entrar]   [Criar conta]                    │
│                                              │
│  Esqueci a senha (admin reseta)              │
└────────────────────────────────────────────┘
```

**Modos:**
- `modo=entrar` (default): campos email+senha
- `modo=criar`: campos email+senha+confirmar

### 2. Mudanças no fluxo `/entrar`

| Ação | Comportamento |
|------|---------------|
| Submit "Entrar" | `supabase.auth.signInWithPassword({email, password})` |
| Submit "Criar" | `supabase.auth.signUp({email, password, options: {emailRedirectTo: callback}})` |
| Forgot password | Mostra mensagem: "Contate o admin master para resetar sua senha" |

### 3. Server-fn `setUserPassword` (pro master)

Já existe em `src/lib/master-password.ts`. **Manter como está.**

**Endpoint:** POST `/api/master/set-password` (autenticado, só super_admin)
- Admin pode setar senha do próprio user
- Bypass via admin API, **sem precisar de email**

### 4. Modificação do trigger `handle_new_user`

**Antes:**
```sql
IF NOT _exists AND NEW.email IS NOT NULL THEN
  INSERT INTO public.user_roles (user_id, role) VALUES (...);
END IF;
```

**Depois:** Manter igual. Não muda nada no trigger. O trigger continua promovendo 1º user a super_admin.

### 5. Onboarding master (rota `/master/welcome`)

**Mantém** a tela de boas-vindas com:
- Banner proeminente: "🔐 Defina sua senha"
- Botão: "Definir senha agora"
- Após definir, libera acesso ao painel

### 6. Remoção de código quebrado

**REMOVER** (em commit único):
- `src/routes/api/debug/test-email.ts` (não mais útil)
- `src/lib/own-magic-link.ts` (não mais usado)
- `src/lib/master-aux.ts` (se existir)
- `package.json` dep `nodemailer` (não vai ser usada)

**MANTER**:
- `src/lib/master-password.ts` (essencial pro fluxo de senha master)
- `src/routes/master/set-password.tsx` (rota de definição de senha)

## Fluxo do Usuário Master

```
1. /entrar (default modo=entrar)
2. User digita email + senha
3. Clica "Criar conta" (se ainda não tem) ou "Entrar"
4. Trigger handle_new_user promove 1º user a super_admin
5. User vai pra /master/welcome
6. Tela mostra banner: "🔐 Defina sua senha AGORA"
7. User clica → preenche senha 2x → salva
8. Trigger atualiza senha
9. /master/welcome confirma: "Senha definida! Pode usar 'Entrar com senha'"
10. ✅ User pode Sair e voltar usando email+senha (SEM precisar de email)
```

## Fluxo do Cliente

```
1. /entrar (modo=entrar) ou /entrar?modo=criar
2. Digita email + senha + confirma
3. Clica "Criar conta"
4. signUp → user criado (com email_confirm=true se Supabase permitir)
5. /app/onboarding wizard (5 etapas)
6. ✅ Pode logar depois com email+senha
7. Esqueceu senha? "Contate o admin master"
```

## Arquivos modificados/criados

| Arquivo | Mudança |
|---------|---------|
| `src/routes/entrar.tsx` | Reescrito: campos email+senha+confirmar |
| `src/lib/master-password.ts` | Mantido (sem mudança) |
| `src/routes/master/welcome.tsx` | Mantido (sem mudança) |
| `src/routes/master/set-password.tsx` | Mantido (sem mudança) |
| `src/lib/own-magic-link.ts` | **REMOVER** |
| `src/routes/api/debug/test-email.ts` | **REMOVER** |
| `package.json` | Remover `nodemailer` |

## Risco de segurança

**Risco anterior (revertido):** Qualquer pessoa com email + API poderia logar.
**Risco novo:** Zero. Senha é obrigatória pra entrar.

## Testes manuais

1. ✅ Master cadastra com email+senha → loga no master
2. ✅ Master sai → entra de novo com email+senha
3. ✅ Master vai em /master/welcome → vê banner "Defina sua senha"
4. ✅ Master define senha → banner some
5. ✅ Master faz logout → entra com email+senha
6. ✅ Cliente cadastra → entra no app
7. ✅ Cliente tenta "Esqueci senha" → vê mensagem "Contate admin"

## Deploy

- 1 commit com todas as mudanças
- 1 deploy na Vercel
- Teste manual end-to-end
- Tempo estimado: 1h

## O que NÃO entra no escopo

- ❌ Recuperação de senha por email (cliente tem que pedir pro admin)
- ❌ Verificação de email obrigatória (vai depender do Supabase Auth config)
- ❌ Magic link (removido completamente)
- ❌ Tela "esqueci minha senha" funcional (vai só mostrar mensagem)
- ❌ 2FA
- ❌ OAuth (Google, Facebook, etc)

Esses itens podem ser adicionados em versões futuras, **quando o SMTP estiver funcionando**.
