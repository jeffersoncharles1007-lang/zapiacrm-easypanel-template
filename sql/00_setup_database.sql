-- =============================================================================
-- ZAPIACRM - SETUP COMPLETO DO BANCO DE DADOS
-- Versao: 2.1 - Corrigida para Supabase (sem RAISE NOTICE fora de bloco DO)
-- Execute DEPOIS de rodar o 00_cleanup.sql com sucesso
-- =============================================================================

-- =============================================================================
-- PARTE 1: ENUMS (criar primeiro, sem dependencias)
-- =============================================================================
-- [ETAPA 1/10] Criando ENUMS...

DO $$ BEGIN
  CREATE TYPE app_role AS ENUM ('super_admin');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE tenant_role AS ENUM ('owner','admin','atendente');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE stage_tipo AS ENUM ('normal','ganho','perda');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE fin_tipo AS ENUM ('receita','despesa');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE fin_status AS ENUM ('pendente','pago','atrasado','cancelado');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE fin_forma AS ENUM ('pix','boleto','cartao','dinheiro','transferencia','outro');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE campaign_status AS ENUM ('rascunho','agendada','enviando','pausada','concluida','cancelada');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE campaign_target_status AS ENUM ('pendente','enviado','falhou','pulado');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- =============================================================================
-- PARTE 2: FUNCOES HELPER BASICAS (sem dependencias de tabelas)
-- =============================================================================
-- [ETAPA 2/10] Criando funcoes helper...

CREATE OR REPLACE FUNCTION tg_set_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- =============================================================================
-- PARTE 3: TABELAS BASE (tabelas que NAO dependem de outras do sistema)
-- =============================================================================
-- [ETAPA 3/10] Criando tabelas base...

CREATE TABLE IF NOT EXISTS app_config (
  id boolean PRIMARY KEY DEFAULT true,
  super_admin_emails text[] NOT NULL DEFAULT '{}',
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT app_config_singleton CHECK (id = true)
);

CREATE TABLE IF NOT EXISTS plan (
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

CREATE TABLE IF NOT EXISTS company (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nome text NOT NULL,
  slug text NOT NULL UNIQUE,
  primary_color text NOT NULL DEFAULT '#22C55E',
  logo_url text,
  telefone text,
  status_cobranca text NOT NULL DEFAULT 'trial',
  trial_ate timestamptz NOT NULL DEFAULT (now() + interval '14 days'),
  selected_plan_slug text,
  created_by uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
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
  creditos_origem text NOT NULL DEFAULT 'trial' CHECK (creditos_origem IN ('trial','plano','bonus'))
);

CREATE TABLE IF NOT EXISTS user_roles (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  role app_role NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, role)
);

CREATE TABLE IF NOT EXISTS profiles (
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

CREATE TABLE IF NOT EXISTS company_user (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  company_id uuid NOT NULL REFERENCES company(id) ON DELETE CASCADE,
  role tenant_role NOT NULL DEFAULT 'owner',
  ativo boolean NOT NULL DEFAULT true,
  forcar_troca_senha boolean NOT NULL DEFAULT false,
  convite_token text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, company_id)
);

CREATE TABLE IF NOT EXISTS subscription (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES company(id) ON DELETE CASCADE,
  plan_id uuid REFERENCES plan(id) ON DELETE SET NULL,
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
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS crm_stage (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES company(id) ON DELETE CASCADE,
  nome text NOT NULL,
  ordem int NOT NULL DEFAULT 0,
  cor text NOT NULL DEFAULT '#8AA89A',
  tipo stage_tipo NOT NULL DEFAULT 'normal',
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS produto (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  company_id uuid NOT NULL REFERENCES company(id) ON DELETE CASCADE,
  nome text NOT NULL,
  preco numeric NOT NULL DEFAULT 0,
  descricao text,
  ativo boolean NOT NULL DEFAULT true,
  ordem int NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now()
);

-- =============================================================================
-- PARTE 4: TABELAS DO MOTOR (dependem de company e profiles)
-- =============================================================================
-- [ETAPA 4/10] Criando tabelas do motor...

CREATE TABLE IF NOT EXISTS agent_config (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  company_id uuid NOT NULL,
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
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS whatsapp_instances (
  user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  company_id uuid NOT NULL,
  instance_name text NOT NULL UNIQUE,
  numero text,
  status text NOT NULL DEFAULT 'disconnected',
  webhook_token text NOT NULL DEFAULT gen_random_uuid()::text,
  webhook_configured_at timestamptz,
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS mensagens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  company_id uuid NOT NULL,
  numero text NOT NULL,
  contato_nome text,
  direcao text NOT NULL CHECK (direcao IN ('entrada','saida')),
  autor text NOT NULL CHECK (autor IN ('ia','humano','contato')),
  texto text NOT NULL,
  whatsapp_message_id text,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS crm_cards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  company_id uuid NOT NULL,
  numero text NOT NULL,
  nome text,
  status text NOT NULL DEFAULT 'conversas',
  stage_id uuid,
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
  UNIQUE (company_id, numero)
);

CREATE TABLE IF NOT EXISTS contact_pause (
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  company_id uuid NOT NULL,
  numero text NOT NULL,
  pausado boolean NOT NULL DEFAULT false,
  updated_at timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, numero)
);

-- =============================================================================
-- PARTE 5: SEED DATA - APP CONFIG
-- =============================================================================
-- [ETAPA 5/10] Inserindo seed data...

INSERT INTO app_config (id, super_admin_emails) VALUES (true, '{}')
ON CONFLICT (id) DO NOTHING;

-- =============================================================================
-- PARTE 6: FUNCOES SECURITY DEFINER (dependem das tabelas acima)
-- =============================================================================
-- [ETAPA 6/10] Criando funcoes de seguranca...

CREATE OR REPLACE FUNCTION is_super_admin()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = auth.uid() AND role = 'super_admin'::public.app_role
  );
$$;

CREATE OR REPLACE FUNCTION has_company_access(_company_id uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.company_user
    WHERE user_id = auth.uid() AND company_id = _company_id AND ativo = true
  );
$$;

CREATE OR REPLACE FUNCTION has_company_role(_company_id uuid, _roles text[])
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.company_user
    WHERE company_id = _company_id
      AND user_id = auth.uid()
      AND ativo = true
      AND role::text = ANY (_roles)
  );
$$;

CREATE OR REPLACE FUNCTION current_company_id()
RETURNS uuid LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT company_id FROM public.company_user
  WHERE user_id = auth.uid() AND ativo = true
  ORDER BY created_at ASC LIMIT 1;
$$;

-- =============================================================================
-- PARTE 7: TRIGGER HANDLE_NEW_USER
-- =============================================================================
-- [ETAPA 7/10] Criando trigger de novo usuario...

CREATE OR REPLACE FUNCTION handle_new_user()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
  _is_first_super_admin boolean;
BEGIN
  INSERT INTO public.profiles (user_id, email, nome)
  VALUES (NEW.id, NEW.email, COALESCE(NEW.raw_user_meta_data->>'full_name', ''))
  ON CONFLICT (user_id) DO NOTHING;

  SELECT COUNT(*) = 0 INTO _is_first_super_admin
  FROM public.user_roles
  WHERE role = 'super_admin'::public.app_role;

  IF _is_first_super_admin AND NEW.email IS NOT NULL THEN
    INSERT INTO public.user_roles (user_id, role)
    VALUES (NEW.id, 'super_admin'::public.app_role)
    ON CONFLICT (user_id, role) DO NOTHING;

    UPDATE public.app_config
    SET super_admin_emails = array_append(super_admin_emails, NEW.email),
        updated_at = now()
    WHERE id = true;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- =============================================================================
-- PARTE 8: HABILITAR RLS (Row Level Security)
-- =============================================================================
-- [ETAPA 8/10] Habilitando RLS nas tabelas...

ALTER TABLE app_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE company ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_user ENABLE ROW LEVEL SECURITY;
ALTER TABLE agent_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE whatsapp_instances ENABLE ROW LEVEL SECURITY;
ALTER TABLE mensagens ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE contact_pause ENABLE ROW LEVEL SECURITY;
ALTER TABLE crm_stage ENABLE ROW LEVEL SECURITY;
ALTER TABLE produto ENABLE ROW LEVEL SECURITY;
ALTER TABLE plan ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscription ENABLE ROW LEVEL SECURITY;

-- =============================================================================
-- PARTE 9: POLICIES RLS
-- =============================================================================
-- [ETAPA 9/10] Criando policies RLS...

-- app_config: apenas super_admin
DROP POLICY IF EXISTS app_config_all ON app_config;
CREATE POLICY app_config_all ON app_config
  FOR ALL TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

-- user_roles: leitura para todos, escrita apenas super_admin
DROP POLICY IF EXISTS user_roles_select ON user_roles;
CREATE POLICY user_roles_select ON user_roles
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_super_admin());

DROP POLICY IF EXISTS user_roles_modify ON user_roles;
CREATE POLICY user_roles_modify ON user_roles
  FOR ALL TO authenticated
  WITH CHECK (public.is_super_admin());

-- profiles: cada usuario ve e edita apenas o proprio
DROP POLICY IF EXISTS profiles_select ON profiles;
CREATE POLICY profiles_select ON profiles
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_super_admin());

DROP POLICY IF EXISTS profiles_update ON profiles;
CREATE POLICY profiles_update ON profiles
  FOR UPDATE TO authenticated
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS profiles_insert ON profiles;
CREATE POLICY profiles_insert ON profiles
  FOR INSERT TO authenticated
  WITH CHECK (user_id = auth.uid());

-- company: acesso via has_company_access
DROP POLICY IF EXISTS company_select ON company;
CREATE POLICY company_select ON company
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(id));

DROP POLICY IF EXISTS company_insert ON company;
CREATE POLICY company_insert ON company
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin());

DROP POLICY IF EXISTS company_update ON company;
CREATE POLICY company_update ON company
  FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(id))
  WITH CHECK (public.is_super_admin() OR public.has_company_access(id));

DROP POLICY IF EXISTS company_delete ON company;
CREATE POLICY company_delete ON company
  FOR DELETE TO authenticated
  USING (public.is_super_admin());

-- company_user: membros da empresa ou super_admin
DROP POLICY IF EXISTS company_user_select ON company_user;
CREATE POLICY company_user_select ON company_user
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR user_id = auth.uid() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS company_user_insert ON company_user;
CREATE POLICY company_user_insert ON company_user
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS company_user_update ON company_user;
CREATE POLICY company_user_update ON company_user
  FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id))
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

-- agent_config: owner e admin da empresa
DROP POLICY IF EXISTS agent_config_select ON agent_config;
CREATE POLICY agent_config_select ON agent_config
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS agent_config_insert ON agent_config;
CREATE POLICY agent_config_insert ON agent_config
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR public.has_company_role(company_id, ARRAY['owner','admin']));

DROP POLICY IF EXISTS agent_config_update ON agent_config;
CREATE POLICY agent_config_update ON agent_config
  FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR public.has_company_role(company_id, ARRAY['owner','admin']))
  WITH CHECK (public.is_super_admin() OR public.has_company_role(company_id, ARRAY['owner','admin']));

DROP POLICY IF EXISTS agent_config_delete ON agent_config;
CREATE POLICY agent_config_delete ON agent_config
  FOR DELETE TO authenticated
  USING (public.is_super_admin() OR public.has_company_role(company_id, ARRAY['owner','admin']));

-- whatsapp_instances: membros da empresa
DROP POLICY IF EXISTS whatsapp_select ON whatsapp_instances;
CREATE POLICY whatsapp_select ON whatsapp_instances
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS whatsapp_insert ON whatsapp_instances;
CREATE POLICY whatsapp_insert ON whatsapp_instances
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS whatsapp_update ON whatsapp_instances;
CREATE POLICY whatsapp_update ON whatsapp_instances
  FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id))
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS whatsapp_delete ON whatsapp_instances;
CREATE POLICY whatsapp_delete ON whatsapp_instances
  FOR DELETE TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id));

-- mensagens: membros da empresa
DROP POLICY IF EXISTS mensagens_select ON mensagens;
CREATE POLICY mensagens_select ON mensagens
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS mensagens_insert ON mensagens;
CREATE POLICY mensagens_insert ON mensagens
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS mensagens_delete ON mensagens;
CREATE POLICY mensagens_delete ON mensagens
  FOR DELETE TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id));

-- crm_cards: membros da empresa
DROP POLICY IF EXISTS crm_cards_select ON crm_cards;
CREATE POLICY crm_cards_select ON crm_cards
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS crm_cards_insert ON crm_cards;
CREATE POLICY crm_cards_insert ON crm_cards
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS crm_cards_update ON crm_cards;
CREATE POLICY crm_cards_update ON crm_cards
  FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id))
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS crm_cards_delete ON crm_cards;
CREATE POLICY crm_cards_delete ON crm_cards
  FOR DELETE TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id));

-- contact_pause: membros da empresa
DROP POLICY IF EXISTS contact_pause_select ON contact_pause;
CREATE POLICY contact_pause_select ON contact_pause
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS contact_pause_insert ON contact_pause;
CREATE POLICY contact_pause_insert ON contact_pause
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS contact_pause_update ON contact_pause;
CREATE POLICY contact_pause_update ON contact_pause
  FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id))
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS contact_pause_delete ON contact_pause;
CREATE POLICY contact_pause_delete ON contact_pause
  FOR DELETE TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id));

-- crm_stage: membros da empresa
DROP POLICY IF EXISTS crm_stage_select ON crm_stage;
CREATE POLICY crm_stage_select ON crm_stage
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS crm_stage_insert ON crm_stage;
CREATE POLICY crm_stage_insert ON crm_stage
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS crm_stage_update ON crm_stage;
CREATE POLICY crm_stage_update ON crm_stage
  FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id))
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS crm_stage_delete ON crm_stage;
CREATE POLICY crm_stage_delete ON crm_stage
  FOR DELETE TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id));

-- produto: membros da empresa
DROP POLICY IF EXISTS produto_select ON produto;
CREATE POLICY produto_select ON produto
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS produto_insert ON produto;
CREATE POLICY produto_insert ON produto
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS produto_update ON produto;
CREATE POLICY produto_update ON produto
  FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id))
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS produto_delete ON produto;
CREATE POLICY produto_delete ON produto
  FOR DELETE TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id));

-- plan: todos podem ver, apenas super_admin pode modificar
DROP POLICY IF EXISTS plan_select ON plan;
CREATE POLICY plan_select ON plan
  FOR SELECT TO authenticated
  USING (true);

DROP POLICY IF EXISTS plan_admin ON plan;
CREATE POLICY plan_admin ON plan
  FOR ALL TO authenticated
  USING (public.is_super_admin())
  WITH CHECK (public.is_super_admin());

-- subscription: membros da empresa
DROP POLICY IF EXISTS subscription_select ON subscription;
CREATE POLICY subscription_select ON subscription
  FOR SELECT TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS subscription_insert ON subscription;
CREATE POLICY subscription_insert ON subscription
  FOR INSERT TO authenticated
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS subscription_update ON subscription;
CREATE POLICY subscription_update ON subscription
  FOR UPDATE TO authenticated
  USING (public.is_super_admin() OR public.has_company_access(company_id))
  WITH CHECK (public.is_super_admin() OR public.has_company_access(company_id));

DROP POLICY IF EXISTS subscription_delete ON subscription;
CREATE POLICY subscription_delete ON subscription
  FOR DELETE TO authenticated
  USING (public.is_super_admin());

-- =============================================================================
-- PARTE 10: SEED DATA - PLANOS + INDICES
-- =============================================================================
-- [ETAPA 10/10] Inserindo planos default e criando indices...

INSERT INTO plan (slug, nome, descricao, preco_cents, intervalo, trial_days, limite_mensagens, limite_instancias, limite_usuarios, limite_contatos, features, destaque, ordem) VALUES
  ('starter', 'Starter', 'Ideal para começar com WhatsApp e IA.', 9700, 'month', 3, 2000, 1, 2, 1000,
   '["1 WhatsApp","2 usuarios","CRM Kanban","IA Gemini"]'::jsonb, false, 1),
  ('pro', 'Pro', 'Para times de vendas que precisam de mais.', 19700, 'month', 3, 10000, 3, 8, 5000,
   '["3 WhatsApp","8 usuarios","CRM + Automacoes","IA Gemini, GPT, Claude"]'::jsonb, true, 2),
  ('business', 'Business', 'Alto volume com suporte prioritario.', 49700, 'month', 3, 50000, 10, 30, 25000,
   '["10 WhatsApp","30 usuarios","API + Webhooks","Suporte 24/7"]'::jsonb, false, 3)
ON CONFLICT (slug) DO NOTHING;

-- Indices
CREATE INDEX IF NOT EXISTS idx_mensagens_company_id ON mensagens(company_id);
CREATE INDEX IF NOT EXISTS idx_mensagens_user_id ON mensagens(user_id);
CREATE INDEX IF NOT EXISTS idx_mensagens_created_at ON mensagens(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_mensagens_numero ON mensagens(numero);

CREATE INDEX IF NOT EXISTS idx_crm_cards_company_id ON crm_cards(company_id);
CREATE INDEX IF NOT EXISTS idx_crm_cards_status ON crm_cards(status);
CREATE INDEX IF NOT EXISTS idx_crm_cards_stage_id ON crm_cards(stage_id);

CREATE INDEX IF NOT EXISTS idx_company_user_user_id ON company_user(user_id);
CREATE INDEX IF NOT EXISTS idx_company_user_company_id ON company_user(company_id);

CREATE INDEX IF NOT EXISTS idx_subscription_company_id ON subscription(company_id);
CREATE INDEX IF NOT EXISTS idx_subscription_status ON subscription(status);

SELECT 'Setup completo! Banco de dados ZAPIACRM criado com sucesso.' AS status;
