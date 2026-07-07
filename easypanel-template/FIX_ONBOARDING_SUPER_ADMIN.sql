-- ============================================================
-- CORREÇÃO DO ONBOARDING - PRIMEIRO USUÁRIO VIRA SUPER_ADMIN
-- Cole este SQL no SQL Editor do Supabase
-- ============================================================

-- 1) Substitui a função handle_new_user (versão correta)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  _exists boolean;
BEGIN
  -- Sempre cria o profile
  INSERT INTO public.profiles (user_id, email)
  VALUES (NEW.id, NEW.email)
  ON CONFLICT (user_id) DO NOTHING;

  -- Verifica se já existe algum super_admin
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles WHERE role = 'super_admin'::public.app_role
  ) INTO _exists;

  -- Se NÃO existe nenhum super_admin, este usuário VIRA!
  IF NOT _exists AND NEW.email IS NOT NULL THEN
    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.id, 'super_admin'::public.app_role)
    ON CONFLICT (user_id, role) DO NOTHING;

    -- Adiciona email à lista de super admins
    INSERT INTO public.app_config (id, super_admin_emails)
    VALUES (true, ARRAY[NEW.email])
    ON CONFLICT (id) DO UPDATE
      SET super_admin_emails = (
        SELECT ARRAY(SELECT DISTINCT unnest(public.app_config.super_admin_emails || ARRAY[NEW.email]))
      ),
      updated_at = now();
  END IF;

  RETURN NEW;
END $function$;

-- 2) Recria o trigger
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 3) Limpa emails legados (opcional - para ambiente novo não necessário)
-- UPDATE public.app_config SET super_admin_emails = '{}', updated_at = now() WHERE id = true;

-- 4) Confirmação
SELECT
  'Função handle_new_user atualizada!' AS status,
  (SELECT COUNT(*) FROM public.user_roles WHERE role = 'super_admin') AS total_super_admins,
  (SELECT super_admin_emails FROM public.app_config LIMIT 1) AS emails_super_admin;
