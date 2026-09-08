-- =====================================================================
-- Enable Realtime (no-op if already enabled)
-- Migration 20260616131406 needs realtime.messages to exist. On new
-- Supabase projects the schema exists but the table may not.
-- We attempt creation; if permission denied, the project likely has
-- Realtime not enabled via Dashboard, which must be enabled manually
-- before re-running this migration.
-- =====================================================================

-- Ensure schema exists (no-op if already)
-- (Supabase creates realtime schema automatically)

-- Attempt to ensure the table exists; if permission denied, the operator
-- must enable Realtime in the Supabase Dashboard first.
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'realtime' AND table_name = 'messages'
  ) THEN
    BEGIN
      CREATE TABLE realtime.messages (
        id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        topic text NOT NULL,
        extension text NOT NULL,
        payload jsonb,
        event text,
        private boolean DEFAULT false,
        updated_at timestamp without time zone NOT NULL DEFAULT now(),
        created_at timestamp without time zone NOT NULL DEFAULT now()
      );
    EXCEPTION
      WHEN insufficient_privilege THEN
        RAISE NOTICE 'realtime.messages table does not exist and current role lacks privilege to create it. Enable Realtime in Supabase Dashboard (Database → Replication) and re-run this migration.';
      WHEN OTHERS THEN
        RAISE NOTICE 'Could not create realtime.messages: %', SQLERRM;
    END;
  END IF;
END
$$;

-- Add to publication so changes broadcast
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'realtime' AND table_name = 'messages') THEN
    IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime') THEN
      BEGIN
        EXECUTE 'ALTER PUBLICATION supabase_realtime ADD TABLE realtime.messages';
      EXCEPTION
        WHEN duplicate_object THEN NULL;
        WHEN OTHERS THEN RAISE NOTICE 'Could not add to publication: %', SQLERRM;
      END;
    END IF;
  END IF;
END
$$;