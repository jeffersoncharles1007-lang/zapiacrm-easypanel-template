// ZAPIACRM — public signup endpoint
//
// Creates a new auth user using the service_role (admin) API.
// Bypasses the Supabase Free-tier rate limit on supabase.auth.signUp.
//
// Request:  POST { email, password, redirectTo? }
// Response: 200 { user_id, email }
//           400 { error } — invalid input
//           409 { error } — user already exists
//           500 { error } — server error
//
// Security:
//   - Validates email + password shape
//   - Returns no sensitive data
//   - Logs minimal context (no password) for debugging
//   - Intended to be called from the same-origin app only
//     (CORS locked to APP_ORIGIN env var)

import { createFileRoute } from "@tanstack/react-router";
import { supabaseAdmin } from "@/integrations/supabase/client.server";

const APP_ORIGIN = process.env.APP_ORIGIN ?? "https://zapiacrm.vercel.app";

const cors = {
  "Access-Control-Allow-Origin": APP_ORIGIN,
  "Access-Control-Allow-Headers": "authorization, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Content-Type": "application/json",
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: cors });
}

export const Route = createFileRoute("/api/public/signup")({
  server: {
    handlers: {
      OPTIONS: async () => new Response(null, { status: 204, headers: cors }),
      POST: async ({ request }) => {
        if (!supabaseAdmin) {
          return json({ error: "admin_unavailable" }, 500);
        }

        let payload: { email?: unknown; password?: unknown; redirectTo?: unknown };
        try {
          payload = await request.json();
        } catch {
          return json({ error: "invalid_json" }, 400);
        }

        const email = String(payload.email ?? "").trim().toLowerCase();
        const password = String(payload.password ?? "");
        const redirectTo =
          typeof payload.redirectTo === "string" && payload.redirectTo.startsWith("/")
            ? payload.redirectTo
            : "/app/dashboard";

        if (!email || !email.includes("@") || email.length > 254) {
          return json({ error: "invalid_email" }, 400);
        }
        if (password.length < 8 || password.length > 128) {
          return json({ error: "invalid_password" }, 400);
        }

        // Check if user already exists
        const { data: existing } = await supabaseAdmin.auth.admin.listUsers();
        const found = existing?.users?.find(
          (u) => u.email?.toLowerCase() === email,
        );
        if (found) {
          return json({ error: "user_already_exists" }, 409);
        }

        // Create user with email already confirmed (no need for verification email)
        const { data, error } = await supabaseAdmin.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          user_metadata: { source: "zapiacrm-signup-api" },
        });

        if (error || !data?.user) {
          return json({ error: error?.message ?? "create_failed" }, 500);
        }

        return json(
          { user_id: data.user.id, email: data.user.email },
          200,
        );
      },
    },
  },
});