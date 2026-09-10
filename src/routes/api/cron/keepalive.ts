// ZAPIACRM — Cron job de keepalive do Supabase
//
// Vercel dispara este endpoint 1x por dia (configurado em vercel.json).
// Ele faz um SELECT 1 no banco do Supabase via REST API publica.
// O Supabase conta essa requisicao como acesso, evitando que o projeto
// Free tier seja pausado por inatividade (7 dias sem acesso = pause).
//
// R$ 0/mes — substitui o upgrade para Pro ($25/mes) para esse proposito.
//
// Seguranca: aceita requests so do Vercel Cron (header authorization Bearer
// com CRON_SECRET), exceto em development.

import { createFileRoute } from "@tanstack/react-router";
import { createClient } from "@supabase/supabase-js";

const SUPABASE_URL = process.env.SUPABASE_URL ?? "";
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY ?? "";

export const Route = createFileRoute("/api/cron/keepalive")({
  server: {
    handlers: {
      GET: async ({ request }) => {
        // Em producao, Vercel Cron adiciona header authorization Bearer
        // contendo o CRON_SECRET. Em development, deixa passar.
        const auth = request.headers.get("authorization") ?? "";
        const expected = process.env.CRON_SECRET;
        if (expected && auth !== `Bearer ${expected}`) {
          return new Response("forbidden", { status: 403 });
        }

        if (!SUPABASE_URL || !SUPABASE_SERVICE_ROLE_KEY) {
          return Response.json(
            { ok: false, error: "supabase_env_missing" },
            { status: 500 },
          );
        }

        // Cliente normal (nao admin) basta para SELECT 1.
        // Usamos a publishable key se service_role nao estiver disponivel.
        const publishableKey =
          process.env.SUPABASE_PUBLISHABLE_KEY ?? "";
        const key = SUPABASE_SERVICE_ROLE_KEY || publishableKey;
        const supabase = createClient(SUPABASE_URL, key);

        const start = Date.now();
        const { data, error } = await supabase
          .from("company")
          .select("id")
          .limit(1);
        const ms = Date.now() - start;

        if (error) {
          console.error("[cron.keepalive] supabase error:", error);
          return Response.json(
            { ok: false, error: error.message, ms },
            { status: 500 },
          );
        }

        console.log(
          `[cron.keepalive] ok — pinged Supabase in ${ms}ms (rows: ${data?.length ?? 0})`,
        );
        return Response.json({
          ok: true,
          timestamp: new Date().toISOString(),
          ms,
          rows: data?.length ?? 0,
        });
      },
    },
  },
});
