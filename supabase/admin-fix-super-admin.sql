-- =====================================================================
-- ZAPIACRM - Script para resolver bloqueio de super admin
--
-- PROBLEMA: O trigger handle_new_user() so cria super admin se
-- NAO houver nenhum. Como a migration 20260616143152 criou 2
-- super admins fixos (luis.bedinot@gmail.com + UUID 5d59803b...),
-- nenhum novo signup esta virando super admin.
--
-- ESCOLHA UMA das 2 opcoes abaixo e execute no SQL Editor do
-- Supabase Dashboard.
-- =====================================================================

-- =====================================================================
-- OPCAO A (RECOMENDADA): Definir SEU email como super admin fixo
-- =====================================================================
-- Isso adiciona seu email na lista super_admin_emails.
-- Quando voce fizer LOGIN (nao signup) com esse email,
-- a funcao is_super_admin() vai retornar true.

-- PASSO 1: Adicionar seu email na lista
UPDATE app_config
SET super_admin_emails = (
  SELECT ARRAY(SELECT DISTINCT unnest(
    public.app_config.super_admin_emails || ARRAY['SEU-EMAIL-AQUI@gmail.com']
  ))
),
updated_at = now()
WHERE id = true;

-- PASSO 2: Se o user ja existe, vincular como super admin direto
INSERT INTO public.user_roles (user_id, role)
SELECT id, 'super_admin'::public.app_role
FROM auth.users
WHERE email = 'SEU-EMAIL-AQUI@gmail.com'
ON CONFLICT (user_id, role) DO NOTHING;

-- PASSO 3: Verificar que funcionou
SELECT
  u.email,
  ur.role,
  ac.super_admin_emails
FROM auth.users u
LEFT JOIN public.user_roles ur ON ur.user_id = u.id AND ur.role = 'super_admin'
CROSS JOIN public.app_config ac
WHERE u.email = 'SEU-EMAIL-AQUI@gmail.com';

-- Esperado: 1 linha com role='super_admin' e seu email na lista

-- =====================================================================
-- OPCAO B (MAIS INVASIVA): Deletar todos os super admins antigos
-- =====================================================================
-- Faz com que o PROXIMO signup vire super admin automaticamente
-- (comportamento "primeiro cadastro" do trigger).

-- DESCOMENTE as 3 linhas abaixo para usar:

-- DELETE FROM public.user_roles WHERE role = 'super_admin';
-- UPDATE public.app_config SET super_admin_emails = '{}' WHERE id = true;
-- UPDATE public.app_config SET updated_at = now() WHERE id = true;

-- Depois execute qualquer signup e o primeiro vira super admin.

-- =====================================================================
-- VERIFICACAO: Ver estado atual
-- =====================================================================

-- Lista todos os super admins atuais
SELECT
  u.id,
  u.email,
  u.created_at,
  ur.role,
  ur.created_at AS role_created_at
FROM public.user_roles ur
JOIN auth.users u ON u.id = ur.user_id
WHERE ur.role = 'super_admin'
ORDER BY ur.created_at ASC;

-- Lista a config global
SELECT
  id,
  super_admin_emails,
  updated_at
FROM public.app_config
WHERE id = true;
