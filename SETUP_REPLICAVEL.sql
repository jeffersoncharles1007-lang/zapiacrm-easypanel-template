-- =============================================================================
-- ZAPIACRM — SETUP REPLICÁVEL (White-label)
--
-- COMO USAR:
--   1. Crie um projeto novo no Supabase (supabase.com).
--   2. Abra SQL Editor → New Query.
--   3. Cole ESTE arquivo INTEIRO e clique em Run.
--   4. Pronto: estrutura, RLS, triggers, plans default.
--   5. Configure em Authentication → URL Configuration:
--        Site URL:        https://SEU-PROJETO.vercel.app
--        Redirect URLs:   https://SEU-PROJETO.vercel.app/entrar/callback
--                         https://SEU-PROJETO.vercel.app/entrar
--   6. Em Vercel, configure as env vars (ver .env.example):
--        SUPABASE_URL
--        SUPABASE_PUBLISHABLE_KEY
--        VITE_SUPABASE_URL
--        VITE_SUPABASE_ANON_KEY
--        KIWIFY_WEBHOOK_TOKEN  (gerar no painel da Kiwify)
--        CAKTO_WEBHOOK_TOKEN    (gerar no painel da Cakto)
--        PERFECTPAY_WEBHOOK_TOKEN (gerar no painel da PerfectPay)
-- =============================================================================


-- ===== ENUMS ============================================================
DO $$ BEGIN
  CREATE TYPE public.app_role AS ENUM ('super_admin');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.tenant_role AS ENUM ('owner','admin','atendente');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.stage_tipo AS ENUM ('normal','ganho','perda');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.fin_tipo AS ENUM ('receita','despesa');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.fin_status AS ENUM ('pendente','pago','atrasado','cancelado');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE public.fin_forma AS ENUM ('pix','boleto','cartao','dinheiro','transferencia','outro');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;


-- ===== HELPERS ==========================================================
CREATE OR REPLACE FUNCTION public.tg_set_updated_at()
RETURNS trigger LANGUAGE plpgsql SET search_path = public AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$;


-- ===== TABELAS PRINCIPAIS ==============================================

CREATE TABLE IF NOT EXISTS public.app_config (
  id boolean PRIMARY KEY DEFAULT true,
  super_admin_emails text[] NOT NULL DEFAULT '{}',
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT app_config_singleton CHECK (id = true)
);

CREATE TABLE IF NOT EXISTS public.plan (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  slug text NOT NULL UNIQUE,
  nome text NOT NULL,
  descricao text,
  preco_cents int NOT NULL DEFAULT 0,
  moeda text NOT NULL DEFAULT 'BRL',
  intervalo text NOT NULL DEFAULT 'month' CHECK (intervalo IN ('month','year')),
  trial_days int NOT NULL DEFAULT 3,
  limite_mensagens int NOT NULL DEFAULT 1000,
  limite_instancias int NOT NULL DEFAULT 1,
  limite_usuarios int NOT NULL DEFAULT 2,
  limite_contatos int NOT NULL DEFAULT 1000,
  creditos_mensais integer NOT NULL DEFAULT 1000,
  creditos_trial integer NOT NULL DEFAULT 100,
  features jsonb NOT NULL DEFAULT '[]'::jsonb,
  destaque boolean NOT NULL DEFAULT false,
  ativo boolean NOT NULL DEFAULT true,
  ordem int NOT NULL DEFAULT 0,
  checkout_url text,
  paddle_product_id text,
  paddle_price_id text,
  stripe_product_id text,
  stripe_price_id text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.company (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  slug text NOT NULL UNIQUE,
  primary_color text NOT NULL DEFAULT '#22C55E',
  logo_url text,
  telefone text,
  status_cobranca text NOT NULL DEFAULT 'trial' CHECK (status_cobranca IN ('trial','ativo','suspenso','pendente','checkout_pending')),
  trial_ate timestamptz NOT NULL DEFAULT (now() + interval '14 days'),
  selected_plan_slug text,
  created_by uuid,
  tipo_pessoa text NOT NULL DEFAULT 'PJ' CHECK (tipo_pessoa IN ('PF','PJ')),
  cnpj_cpf text,
  razao_social text,
  nome_fantasia text,
  inscricao_estadual text,
  segmento text,
  porte text,
  site text,
  email_corporativo text,
  cep text, rua text, numero text, complemento text, bairro text, cidade text, estado text,
  pais text DEFAULT 'BR',
  onboarding_completed boolean NOT NULL DEFAULT false,
  onboarding_step int NOT NULL DEFAULT 0,
  financeiro_ativo boolean NOT NULL DEFAULT false,
  financeiro_dias_vencimento_padrao smallint NOT NULL DEFAULT 7,
  creditos_saldo integer NOT NULL DEFAULT 0,
  creditos_resetam_em timestamptz,
  creditos_origem text NOT NULL DEFAULT 'trial' CHECK (creditos_origem IN ('trial','plano','bonus')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  role app_role NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);

CREATE TABLE IF NOT EXISTS public.profiles (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email text,
  nome text,
  nome_completo text,
  cpf text,
  cargo text,
  telefone text,
  avatar_url text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.company_user (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  company_id uuid NOT NULL REFERENCES public.company(id) ON DELETE CASCADE,
  role tenant_role NOT NULL DEFAULT 'owner',
  ativo boolean NOT NULL DEFAULT true,
  forcar_troca_senha boolean NOT NULL DEFAULT false,
  convite_token text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, company_id)
);

CREATE TABLE IF NOT EXISTS public.subscription (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.company(id) ON DELETE CASCADE,
  plan_id uuid REFERENCES public.plan(id) ON DELETE SET NULL,
  provider text NOT NULL DEFAULT 'manual',
  status text NOT NULL DEFAULT 'trialing' CHECK (status IN ('trialing','active','past_due','canceled','incomplete','paused')),
  external_subscription_id text,
  external_customer_id text,
  buyer_email text,
  paddle_subscription_id text,
  paddle_customer_id text,
  stripe_subscription_id text,
  stripe_customer_id text,
  current_period_start timestamptz,
  current_period_end timestamptz,
  trial_ends_at timestamptz,
  cancel_at_period_end boolean NOT NULL DEFAULT false,
  canceled_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (company_id)
);

CREATE TABLE IF NOT EXISTS public.agent_config (
  company_id uuid PRIMARY KEY REFERENCES public.company(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  nome_agente text NOT NULL DEFAULT 'Atendente Virtual',
  nome_empresa text NOT NULL DEFAULT '',
  papel_objetivo text NOT NULL DEFAULT '',
  estilo_comunicacao text NOT NULL DEFAULT '',
  sobre_empresa text NOT NULL DEFAULT '',
  produtos_servicos text NOT NULL DEFAULT '',
  pode_fazer text NOT NULL DEFAULT '',
  nao_pode_fazer text NOT NULL DEFAULT '',
  telefone_transferencia text NOT NULL DEFAULT '',
  palavra_pausar text NOT NULL DEFAULT '/pausar',
  palavra_despausar text NOT NULL DEFAULT '/despausar',
  ai_provider text NOT NULL DEFAULT 'gemini',
  ai_model text NOT NULL DEFAULT 'google/gemini-2.5-flash',
  openai_api_key text NOT NULL DEFAULT '',
  anthropic_api_key text NOT NULL DEFAULT '',
  segundos_buffer int NOT NULL DEFAULT 8,
  responder_em_partes boolean NOT NULL DEFAULT true,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.whatsapp_instances (
  company_id uuid PRIMARY KEY REFERENCES public.company(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  instance_name text NOT NULL UNIQUE,
  numero text,
  status text NOT NULL DEFAULT 'disconnected',
  webhook_token text NOT NULL DEFAULT gen_random_uuid()::text,
  webhook_configured_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.mensagens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.company(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  contato_numero text NOT NULL,
  contato_nome text,
  direcao text NOT NULL CHECK (direcao IN ('entrada','saida')),
  autor text NOT NULL CHECK (autor IN ('ia','humano','contato')),
  texto text NOT NULL,
  whatsapp_message_id text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.crm_stage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.company(id) ON DELETE CASCADE,
  nome text NOT NULL,
  ordem int NOT NULL DEFAULT 0,
  cor text NOT NULL DEFAULT '#8AA89A',
  tipo stage_tipo NOT NULL DEFAULT 'normal',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.crm_cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.company(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  contato_numero text NOT NULL,
  contato_nome text,
  status text NOT NULL DEFAULT 'conversas',
  stage_id uuid REFERENCES public.crm_stage(id) ON DELETE SET NULL,
  valor numeric NOT NULL DEFAULT 0,
  origem text,
  owner_id uuid,
  tags text[] NOT NULL DEFAULT '{}',
  ultima_mensagem text,
  ultima_em timestamptz NOT NULL DEFAULT now(),
  observacao text,
  utm_source text,
  utm_medium text,
  utm_campaign text,
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (company_id, contato_numero)
);

CREATE TABLE IF NOT EXISTS public.contact_pause (
  company_id uuid NOT NULL REFERENCES public.company(id) ON DELETE CASCADE,
  contato_numero text NOT NULL,
  pausado boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (company_id, contato_numero)
);

CREATE TABLE IF NOT EXISTS public.billing_event_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  provider text NOT NULL,
  event_type text,
  external_id text,
  buyer_email text,
  matched_company_id uuid REFERENCES public.company(id) ON DELETE SET NULL,
  processed boolean NOT NULL DEFAULT false,
  error text,
  payload jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.audit_log (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid REFERENCES public.company(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  actor_email text,
  acao text NOT NULL,
  recurso text,
  detalhes jsonb DEFAULT '{}'::jsonb,
  ip text,
  user_agent text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.credit_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.company(id) ON DELETE CASCADE,
  delta integer NOT NULL,
  saldo_apos integer NOT NULL,
  motivo text NOT NULL,
  ref text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.message_template (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES public.company(id) ON DELETE CASCADE,
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  atalho text NOT NULL,
  texto text NOT NULL,
  UNIQUE (company_id, atalho),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);


-- ===== GRANTS ===========================================================
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

GRANT SELECT ON public.plan TO anon, authenticated;

GRANT SELECT, INSERT, UPDATE, DELETE ON
  app_config, plan, company, company_user, user_roles, profiles, subscription,
  agent_config, whatsapp_instances, mensagens, crm_stage, crm_cards,
  contact_pause, billing_event_log, audit_log, credit_ledger, message_template
TO authenticated, service_role;


-- ===== RLS =============================================================
ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE plan ENABLE ROW LEVEL SECURITY;
ALTER TABLE company ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_user ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_instances ENABLE ROW LEVEL SECURITY;
ALTER TABLE mensagens ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_stage ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_pause ENABLE ROW LEVEL SECURITY;
ALTER TABLE billing_event_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE message_template ENABLE ROW LEVEL SECURITY;


-- ===== SECURITY DEFINER HELPERS =========================================
CREATE OR REPLACE FUNCTION public.is_super_admin() RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'super_admin'::public.app_role
  );
$$;

CREATE OR REPLACE FUNCTION public.has_company_access(_company_id uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.company_user
    WHERE user_id = auth.uid() AND company_id = _company_id AND ativo = true
  );
$$;

CREATE OR REPLACE FUNCTION public.has_company_role(_company_id uuid, _roles text[]) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.company_user
    WHERE company_id = _company_id AND user_id = auth.uid() AND ativo = true
      AND role::text = ANY(_roles)
  );
$$;


-- ===== TRIGGER handle_new_user (auto-promove 1º usuário a super_admin) ==
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE _exists boolean;
BEGIN
  INSERT INTO public.profiles (user_id, email)
  VALUES (NEW.id, NEW.email) ON CONFLICT (user_id) DO NOTHING;

  SELECT EXISTS (
    SELECT 1 FROM public.user_roles WHERE role = 'super_admin'::public.app_role
  ) INTO _exists;

  IF NOT _exists AND NEW.email IS NOT NULL THEN
    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.id, 'super_admin'::public.app_role)
    ON CONFLICT (user_id, role) DO NOTHING;

    INSERT INTO public.app_config (id, super_admin_emails)
    VALUES (true, ARRAY[NEW.email])
    ON CONFLICT (id) DO UPDATE
      SET super_admin_emails = (
        SELECT ARRAY(SELECT DISTINCT unnest(public.app_config.super_admin_emails || ARRAY[NEW.email]))
      ), updated_at = now();
  END IF;

  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ===== TRIGGER: seed default stages por nova company ====================
CREATE OR REPLACE FUNCTION public.seed_default_stages() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  INSERT INTO public.crm_stage (company_id, nome, ordem, cor, tipo) VALUES
    (NEW.id, 'Conversas',  0, '#8AA89A', 'normal'),
    (NEW.id, 'Negociando', 1, '#FFB020', 'normal'),
    (NEW.id, 'Ganho',      2, '#22B85F', 'ganho'),
    (NEW.id, 'Perda',      3, '#FF5A5A', 'perda')
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS trg_company_seed_stages ON public.company;
CREATE TRIGGER trg_company_seed_stages
  AFTER INSERT ON public.company
  FOR EACH ROW EXECUTE FUNCTION public.seed_default_stages();


-- ===== TRIGGER: trial credits por nova company =========================
CREATE OR REPLACE FUNCTION public.tg_company_trial_credits() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = 'public' AS $$
DECLARE _qtd int;
BEGIN
  IF NEW.selected_plan_slug IS NOT NULL THEN
    SELECT creditos_trial INTO _qtd FROM public.plan WHERE slug = NEW.selected_plan_slug;
  END IF;
  IF _qtd IS NULL THEN _qtd := 50; END IF;
  NEW.creditos_saldo := _qtd;
  NEW.creditos_origem := 'trial';
  NEW.creditos_resetam_em := NEW.trial_ate;
  RETURN NEW;
END $$;

DROP TRIGGER IF EXISTS company_trial_credits ON public.company;
CREATE TRIGGER company_trial_credits
  BEFORE INSERT ON public.company
  FOR EACH ROW EXECUTE FUNCTION public.tg_company_trial_credits();


-- ===== POLICIES RLS ====================================================

DROP POLICY IF EXISTS app_config_all ON app_config;
CREATE POLICY app_config_all ON app_config FOR ALL TO authenticated
  USING (public.is_super_admin()) WITH CHECK (public.is_super_admin());

DROP POLICY IF EXISTS plan_select ON plan;
CREATE POLICY plan_select ON plan FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS plan_admin ON plan;
CREATE POLICY plan_admin ON plan FOR ALL TO authenticated
  USING (public.is_super_admin()) WITH CHECK (public.is_super_admin());

DROP POLICY IF EXISTS company_select ON company;
CREATE POLICY company_select ON company FOR SELECT TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(id));

DROP POLICY IF EXISTS company_insert ON company;
CREATE POLICY company_insert ON company FOR INSERT TO authenticated
  WITH CHECK (auth.uid() = created_by OR public.is_super_admin());

DROP POLICY IF EXISTS company_update ON company;
CREATE POLICY company_update ON company FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(id))
  WITH CHECK (public.is_super_admin() OR public.has_company_access(id));

DROP POLICY IF EXISTS company_delete ON company;
CREATE POLICY company_delete ON company FOR DELETE TO authenticated
  USING (public.is_super_admin());

DROP POLICY IF EXISTS company_user_select ON company_user;
CREATE POLICY company_user_select ON company_user FOR SELECT TO authenticated
  USING (public.is_super_admin() OR user_id = auth.uid() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS company_user_insert ON company_user;
CREATE POLICY company_user_insert ON company_user FOR INSERT TO authenticated
  WITH CHECK (
    public.is_super_admin()
    OR (user_id = auth.uid() AND EXISTS (
      SELECT 1 FROM public.company c WHERE c.id = company_user.company_id AND c.created_by = auth.uid()
    ))
  );

DROP POLICY IF EXISTS company_user_update ON company_user;
CREATE POLICY company_user_update ON company_user FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR public.has_company_role(company_id, ARRAY['owner','admin']))
  WITH CHECK (public.is_super_admin() OR public.has_company_role(company_id, ARRAY['owner','admin']));

DROP POLICY IF EXISTS company_user_delete ON company_user;
CREATE POLICY company_user_delete ON company_user FOR DELETE TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS user_roles_select ON user_roles;
CREATE POLICY user_roles_select ON user_roles FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_super_admin());

DROP POLICY IF EXISTS profiles_select ON profiles;
CREATE POLICY profiles_select ON profiles FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_super_admin());

DROP POLICY IF EXISTS profiles_update ON profiles;
CREATE POLICY profiles_update ON profiles FOR UPDATE TO authenticated
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS profiles_insert ON profiles;
CREATE POLICY profiles_insert ON profiles FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS subscription_select ON subscription;
CREATE POLICY subscription_select ON subscription FOR SELECT TO authenticated
  USING (public.is_super_admin() OR public.has_company_role(company_id, ARRAY['owner','admin']));

DROP POLICY IF EXISTS subscription_admin ON subscription;
CREATE POLICY subscription_admin ON subscription FOR ALL TO authenticated
  USING (public.is_super_admin()) WITH CHECK (public.is_super_admin());

DROP POLICY IF EXISTS agent_config_all ON agent_config;
CREATE POLICY agent_config_all ON agent_config FOR ALL TO authenticated
  USING (public.is_super_admin() OR public.has_company_role(company_id, ARRAY['owner','admin']))
  WITH CHECK (public.is_super_admin() OR public.has_company_role(company_id, ARRAY['owner','admin']));

DROP POLICY IF EXISTS whatsapp_all ON whatsapp_instances;
CREATE POLICY whatsapp_all ON whatsapp_instances FOR ALL TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id))
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS mensagens_all ON mensagens;
CREATE POLICY mensagens_all ON mensagens FOR ALL TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id))
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS crm_stage_all ON crm_stage;
CREATE POLICY crm_stage_all ON crm_stage FOR ALL TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id))
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS crm_cards_all ON crm_cards;
CREATE POLICY crm_cards_all ON crm_cards FOR ALL TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id))
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS contact_pause_all ON contact_pause;
CREATE POLICY contact_pause_all ON contact_pause FOR ALL TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id))
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS billing_event_log_admin_read ON billing_event_log;
CREATE POLICY billing_event_log_admin_read ON billing_event_log FOR SELECT TO authenticated
  USING (public.is_super_admin());

DROP POLICY IF EXISTS audit_log_admin_read ON audit_log;
CREATE POLICY audit_log_admin_read ON audit_log FOR SELECT TO authenticated
  USING (public.is_super_admin() OR public.has_company_role(company_id, ARRAY['owner','admin']));

DROP POLICY IF EXISTS ledger_owner_read ON credit_ledger;
CREATE POLICY ledger_owner_read ON credit_ledger FOR SELECT TO authenticated
  USING (public.is_super_admin() OR public.has_company_role(company_id, ARRAY['owner','admin']));

DROP POLICY IF EXISTS template_all ON message_template;
CREATE POLICY template_all ON message_template FOR ALL TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id))
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));


-- ===== LOCK DOWN =======================================================
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.seed_default_stages() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.tg_set_updated_at() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.tg_company_trial_credits() FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.is_super_admin() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.has_company_access(uuid) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.has_company_role(uuid, text[]) FROM PUBLIC, anon;


-- ===== SEED PLANS DEFAULT =============================================
INSERT INTO plan (slug, nome, descricao, preco_cents, trial_days, limite_mensagens, limite_usuarios, limite_contatos, creditos_mensais, creditos_trial, features, destaque, ordem)
VALUES
  ('starter', 'Starter', 'Ideal pra começar com WhatsApp e IA.', 9700, 3, 2000, 2, 1000, 2000, 100,
    '["1 WhatsApp","2 usuários","CRM Kanban","IA Gemini"]'::jsonb, false, 1),
  ('pro', 'Pro', 'Para times de vendas que precisam de mais.', 19700, 3, 10000, 8, 5000, 10000, 300,
    '["3 WhatsApp","8 usuários","CRM + Automações","IA Gemini, GPT, Claude"]'::jsonb, true, 2),
  ('business', 'Business', 'Alto volume com suporte prioritário.', 49700, 3, 50000, 30, 25000, 50000, 1000,
    '["10 WhatsApp","30 usuários","API + Webhooks","Suporte 24/7"]'::jsonb, false, 3)
ON CONFLICT (slug) DO NOTHING;


-- ===== SEED APP CONFIG (singleton) ====================================
INSERT INTO app_config (id, super_admin_emails)
VALUES (true, '{}'::text[])
ON CONFLICT (id) DO NOTHING;


-- =====================================================================
-- ✅ SETUP COMPLETO!
--
-- PRÓXIMOS PASSOS (SITE/INFRA):
-- 1. Authentication → URL Configuration → Site URL: https://seu-app.vercel.app
-- 2. Authentication → URL Configuration → Redirect URLs: .../entrar/callback
-- 3. Authentication → Sign In/Up → Email → Magic Link habilitado
-- 4. Vercel → Settings → Environment Variables → ver .env.example
-- 5. Primeiro cadastro = super_admin automático ✅
-- 6. Webhook billing → /api/public/billing/webhook (autocria user se não existir)
-- =====================================================================
