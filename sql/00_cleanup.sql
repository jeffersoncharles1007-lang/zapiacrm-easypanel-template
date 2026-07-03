-- =============================================================================
-- SCRIPT DE LIMPEZA - Execute ANTES do 00_setup_database.sql
-- =============================================================================
-- Versao 2.0 - Com tratamento de erros robusto
-- Cada DROP e protegido com EXCEPTION para nao abortar o script
-- =============================================================================

DO $$
DECLARE
  _msg text;
BEGIN
  RAISE NOTICE 'Iniciando cleanup do banco ZAPIACRM...';

  -- ============================================================
  -- PASSO 1: Desabilitar RLS em todas as tabelas conhecidas
  -- ============================================================

  BEGIN
    ALTER TABLE IF EXISTS public.audit_log DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.webhook_delivery_log DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.api_token DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.webhook_endpoint DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.csat_response DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.campaign_target DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.campaign DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.credit_ledger DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.billing_event_log DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.company_billing DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.subscription DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.plan DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.fin_lancamento DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.fin_categoria DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.message_template DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.google_integration DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.agendamento DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.lead_evento DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.lead_nota DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.produto DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.crm_stage DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.contact_pause DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.crm_cards DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.mensagens DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.whatsapp_instances DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.agent_config DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.company_user DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.profiles DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.app_config DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.user_roles DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  BEGIN
    ALTER TABLE IF EXISTS public.company DISABLE ROW LEVEL SECURITY;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RAISE NOTICE 'RLS desabilitado.';

  -- ============================================================
  -- PASSO 2: Remover triggers (com IF EXISTS)
  -- ============================================================

  DECLARE _trigger_name text;
  BEGIN
    FOR _trigger_name IN
      SELECT DISTINCT trigger_name
      FROM information_schema.triggers
      WHERE event_object_schema = 'public'
    LOOP
      EXECUTE format('DROP TRIGGER IF EXISTS %I ON public.%I CASCADE',
        _trigger_name,
        (SELECT event_object_table FROM information_schema.triggers
         WHERE event_object_schema = 'public' AND trigger_name = _trigger_name
         LIMIT 1)
      );
    END LOOP;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  -- Trigger especifico da auth.users
  BEGIN
    DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users CASCADE;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RAISE NOTICE 'Triggers removidos.';

  -- ============================================================
  -- PASSO 3: Remover policies de TODAS as tabelas
  -- ============================================================

  DECLARE _policy_name text; _table_name text;
  BEGIN
    FOR _policy_name, _table_name IN
      SELECT policyname, tablename
      FROM pg_policies
      WHERE schemaname = 'public'
    LOOP
      EXECUTE format('DROP POLICY IF EXISTS %I ON public.%I CASCADE',
        _policy_name, _table_name);
    END LOOP;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  -- Policy do realtime.messages
  BEGIN
    DROP POLICY IF EXISTS "tenant_topic_subscription" ON realtime.messages CASCADE;
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  RAISE NOTICE 'Policies removidas.';

  -- ============================================================
  -- PASSO 4: Remover todas as tabelas via DROP CASCADE
  -- (CASCADE resolve automaticamente as dependencias de FK)
  -- ============================================================

  DECLARE _tbl text;
  BEGIN
    FOR _tbl IN
      SELECT tablename FROM pg_tables
      WHERE schemaname = 'public'
      ORDER BY tablename
    LOOP
      EXECUTE format('DROP TABLE IF EXISTS public.%I CASCADE', _tbl);
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Erro ao remover tabelas: %', SQLERRM;
  END;

  RAISE NOTICE 'Tabelas removidas.';

  -- ============================================================
  -- PASSO 5: Remover todas as funcoes customizadas do schema public
  -- ============================================================

  DECLARE _func_record RECORD;
  BEGIN
    FOR _func_record IN
      SELECT n.nspname AS schema, p.proname AS funcname,
             pg_get_function_identity_arguments(p.oid) AS args
      FROM pg_proc p
      JOIN pg_namespace n ON p.pronamespace = n.oid
      WHERE n.nspname = 'public'
        AND p.prokind = 'f'
    LOOP
      EXECUTE format('DROP FUNCTION IF EXISTS public.%I(%s) CASCADE',
        _func_record.funcname,
        _func_record.args);
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Erro ao remover funcoes: %', SQLERRM;
  END;

  RAISE NOTICE 'Funcoes removidas.';

  -- ============================================================
  -- PASSO 6: Remover todos os tipos customizados do schema public
  -- ============================================================

  DECLARE _type_record RECORD;
  BEGIN
    FOR _type_record IN
      SELECT t.typname AS typename
      FROM pg_type t
      JOIN pg_namespace n ON t.typnamespace = n.oid
      WHERE n.nspname = 'public'
        AND t.typtype = 'e'  -- enum types
    LOOP
      EXECUTE format('DROP TYPE IF EXISTS public.%I CASCADE', _type_record.typename);
    END LOOP;
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Erro ao remover tipos: %', SQLERRM;
  END;

  RAISE NOTICE 'Tipos removidos.';

  RAISE NOTICE 'Cleanup concluído com sucesso!';
END $$;

-- Verificacao final
SELECT 'Cleanup completo! Agora rode o 00_setup_database.sql' AS mensagem;
