-- ============================================================
-- RESET COMPLETO - APAGA TUDO PRA TESTAR DO ZERO
-- Cole no SQL Editor do Supabase em ambiente de TESTE
-- ⚠️ NÃO RODE EM PRODUÇÃO - apaga TODOS os dados
-- ============================================================

-- 1) Apaga memberships (FK para company e profiles)
DELETE FROM public.company_user;

-- 2) Apaga empresas
DELETE FROM public.company;

-- 3) Apaga subscriptions (FK para company)
DELETE FROM public.subscription;

-- 4) Apaga leads, mensagens, configs (todas com FK para company)
DELETE FROM public.crm_cards;
DELETE FROM public.crm_stage;
DELETE FROM public.mensagens;
DELETE FROM public.contact_pause;
DELETE FROM public.whatsapp_instances;
DELETE FROM public.agent_config;
DELETE FROM public.produto;

-- 5) Apaga roles
DELETE FROM public.user_roles;

-- 6) Limpa lista de super admins (vai ficar vazia = primeiro user vira master)
UPDATE public.app_config SET super_admin_emails = '{}', updated_at = now() WHERE id = true;

-- 7) Apaga OTP codes (novo)
DELETE FROM public.otp_codes;

-- 8) Apaga profiles (depende de auth.users)
DELETE FROM public.profiles;

-- 9) Apaga users do auth (cascade apaga profiles e tudo que dependente)
DELETE FROM auth.users;

-- 10) Reset billing events + audit log
DELETE FROM public.billing_event_log;
DELETE FROM public.audit_log;
DELETE FROM public.credit_ledger;
DELETE FROM public.api_token;
DELETE FROM public.webhook_endpoint;
DELETE FROM public.webhook_delivery_log;
DELETE FROM public.campaign_target;
DELETE FROM public.campaign;
DELETE FROM public.message_template;
DELETE FROM public.lead_evento;
DELETE FROM public.lead_nota;
DELETE FROM public.google_integration;
DELETE FROM public.fin_categoria;
DELETE FROM public.fin_lancamento;
DELETE FROM public.csat_response;
DELETE FROM public.company_billing;

-- 11) Confirmação final
SELECT
  'RESET COMPLETO!' AS status,
  (SELECT COUNT(*) FROM auth.users) AS users_restantes,
  (SELECT COUNT(*) FROM public.user_roles) AS roles_restantes,
  (SELECT COUNT(*) FROM public.company) AS empresas_restantes,
  (SELECT COUNT(*) FROM public.otp_codes) AS otp_codes_restantes,
  (SELECT super_admin_emails FROM public.app_config LIMIT 1) AS super_admin_emails;
