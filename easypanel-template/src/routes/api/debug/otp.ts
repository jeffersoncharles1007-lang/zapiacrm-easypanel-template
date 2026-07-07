import { createFileRoute } from "@tanstack/react-router";
import { createClient } from "@supabase/supabase-js";
import { sendEmail } from "@/lib/smtp";

/**
 * Endpoint de DEBUG para inspecionar o sistema.
 *
 * Ações suportadas via ?action=...&...:
 * - (sem action)      : só mostra env vars (não faz nada destrutivo)
 * - action=users      : lista users + roles
 * - action=send-email : envia email de teste SMTP (params: to, subject opcional)
 *
 * NÃO usa mais auth-otp.ts (foi removido na refatoração pra Supabase nativo).
 */
export const Route = createFileRoute("/api/debug/otp")({
  server: {
    handlers: {
      GET: async ({ request }) => {
        const url = new URL(request.url);
        const to = (url.searchParams.get("to") || "").trim().toLowerCase();
        const action = (url.searchParams.get("action") || "").trim().toLowerCase();

        // 1) Verifica env vars (sempre)
        const env = {
          SMTP_HOST: process.env.SMTP_HOST ?? "❌ NÃO CONFIGURADO",
          SMTP_PORT: process.env.SMTP_PORT ?? "❌ NÃO CONFIGURADO",
          SMTP_USER: process.env.SMTP_USER ?? "❌ NÃO CONFIGURADO",
          SMTP_PASS: process.env.SMTP_PASS ? "✅ configurado" : "❌ NÃO CONFIGURADO",
          SMTP_SENDER_EMAIL: process.env.SMTP_SENDER_EMAIL ?? "❌ NÃO CONFIGURADO",
          SMTP_SENDER_NAME: process.env.SMTP_SENDER_NAME ?? "(vazio)",
          SUPABASE_URL: process.env.SUPABASE_URL ? "✅ configurado" : "❌ NÃO CONFIGURADO",
          SUPABASE_SERVICE_ROLE_KEY: process.env.SUPABASE_SERVICE_ROLE_KEY ? "✅ configurado" : "❌ NÃO CONFIGURADO",
          PUBLIC_APP_URL: process.env.PUBLIC_APP_URL ?? "❌ NÃO CONFIGURADO",
        };

        // users: listar users + roles
        if (action === "users") {
          const supabaseUrl = process.env.SUPABASE_URL;
          const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
          if (!supabaseUrl || !key) {
            return Response.json({ error: "Supabase envs faltando" }, { status: 500 });
          }
          const admin = createClient(supabaseUrl, key, {
            auth: { autoRefreshToken: false, persistSession: false },
          });
          const { data: list } = await admin.auth.admin.listUsers({ perPage: 10 });
          const { data: roles } = await admin.from("user_roles").select("*");
          return Response.json({
            users: list?.users?.map((u: { id: string; email?: string; email_confirmed_at?: string; created_at?: string; last_sign_in_at?: string; identities?: Array<{ provider: string }> }) => ({
              id: u.id,
              email: u.email,
              email_confirmed_at: u.email_confirmed_at,
              created_at: u.created_at,
              last_sign_in_at: u.last_sign_in_at,
              identities: u.identities?.map((i) => i.provider),
            })),
            roles: roles || [],
          });
        }

        // send-email: testa SMTP
        if (action === "send-email" && to && to.includes("@")) {
          try {
            const subject = url.searchParams.get("subject") || "[DEBUG] Teste SMTP";
            const result = await sendEmail({
              to,
              subject,
              html: `<h1>Teste SMTP</h1><p>Email enviado pra ${to}</p><p>Timestamp: ${new Date().toISOString()}</p>`,
            });
            return Response.json({
              env,
              emailTest: {
                ok: true,
                messageId: (result as { messageId?: string }).messageId,
                fullError: (result as { envelope?: unknown }).envelope,
              },
            });
          } catch (e: unknown) {
            const msg = e instanceof Error ? e.message : String(e);
            return Response.json({ env, emailTest: { ok: false, error: msg } }, { status: 500 });
          }
        }

        return Response.json({ env, hint: "Use ?action=users, ?action=send-email&to=email" });
      },
    },
  },
});
