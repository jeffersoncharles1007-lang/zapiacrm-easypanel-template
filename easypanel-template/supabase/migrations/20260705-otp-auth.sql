-- ============================================================================
-- ZAPIACRM: Auth via OTP (1ª parte - schema)
-- ============================================================================

-- 1) Campos em profiles
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS telefone_verificado boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS whatsapp_opt_in boolean NOT NULL DEFAULT true;

-- 2) Tabela otp_codes
CREATE TABLE IF NOT EXISTS public.otp_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  identifier text NOT NULL,
  purpose text NOT NULL CHECK (purpose IN ('signup', 'login', 'reset_password')),
  code text NOT NULL,
  attempts int NOT NULL DEFAULT 0,
  max_attempts int NOT NULL DEFAULT 3,
  expires_at timestamptz NOT NULL,
  consumed boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_otp_codes_lookup
  ON public.otp_codes(identifier, purpose, expires_at DESC)
  WHERE consumed = false;

-- 3) RLS
ALTER TABLE public.otp_codes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS otp_codes_service_role_all ON public.otp_codes;
CREATE POLICY otp_codes_service_role_all ON public.otp_codes
  FOR ALL TO service_role
  USING (true) WITH CHECK (true);
