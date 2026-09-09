// ZAPIACRM — public signup endpoint
//
// Cria uma nova conta COM trial gratuito de 3 dias em uma única chamada:
//   1. Cria auth user via service_role (bypass rate limit do Free tier)
//   2. Cria profile com nome + whatsapp do cliente
//   3. Cria company com status_cobranca='trial' e trial_ate = NOW + 3 dias
//   4. Cria company_user com role='owner'
//
// Request:  POST { email, password, nome?, whatsapp? }
// Response: 200 { user_id, email, company_id, trial_ate }
//           400 { error } — invalid input
//           409 { error } — user already exists
//           500 { error } — server error
//
// Security:
//   - Valida email + password + (nome se enviado)
//   - Retorna dados mínimos (nunca senha)
//   - CORS locked to APP_ORIGIN

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

// "Minha Empresa" / "Empresa do Joao" → slug unico
function slugify(s: string): string {
  return (
    s
      .toLowerCase()
      .normalize("NFD")
      .replace(/[̀-ͯ]/g, "")
      .replace(/[^a-z0-9]+/g, "-")
      .replace(/(^-|-$)/g, "")
      .slice(0, 48) || "empresa"
  );
}

export const Route = createFileRoute("/api/public/signup")({
  server: {
    handlers: {
      OPTIONS: async () => new Response(null, { status: 204, headers: cors }),
      POST: async ({ request }) => {
        if (!supabaseAdmin) {
          return json({ error: "admin_unavailable" }, 500);
        }

        let payload: {
          email?: unknown;
          password?: unknown;
          nome?: unknown;
          whatsapp?: unknown;
        };
        try {
          payload = await request.json();
        } catch {
          return json({ error: "invalid_json" }, 400);
        }

        const email = String(payload.email ?? "").trim().toLowerCase();
        const password = String(payload.password ?? "");
        const nomeRaw = payload.nome != null ? String(payload.nome).trim() : "";
        const whatsappRaw =
          payload.whatsapp != null ? String(payload.whatsapp).trim() : "";

        if (!email || !email.includes("@") || email.length > 254) {
          return json({ error: "invalid_email" }, 400);
        }
        if (password.length < 8 || password.length > 128) {
          return json({ error: "invalid_password" }, 400);
        }
        if (nomeRaw.length > 120) {
          return json({ error: "invalid_nome" }, 400);
        }
        // whatsapp é opcional, mas se enviado, validamos formato básico (10-15 dígitos)
        if (whatsappRaw && !/^[0-9+\-\s()]{10,20}$/.test(whatsappRaw)) {
          return json({ error: "invalid_whatsapp" }, 400);
        }

        // 1. Verifica se user já existe
        const { data: existing } = await supabaseAdmin.auth.admin.listUsers();
        const found = existing?.users?.find(
          (u) => u.email?.toLowerCase() === email,
        );
        if (found) {
          return json({ error: "user_already_exists" }, 409);
        }

        // 2. Cria auth user com email confirmado (sem precisar verificação)
        const { data, error } = await supabaseAdmin.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
          user_metadata: {
            source: "zapiacrm-signup-api",
            nome: nomeRaw || undefined,
            whatsapp: whatsappRaw || undefined,
          },
        });

        if (error || !data?.user) {
          return json({ error: error?.message ?? "create_failed" }, 500);
        }

        const userId = data.user.id;

        // 3. Cria profile com nome + whatsapp (opcional)
        //    O trigger handle_new_user() no banco pode já ter criado profile.
        //    Usamos upsert para garantir.
        const profileData: Record<string, unknown> = {
          user_id: userId,
          email,
          full_name: nomeRaw || null,
          whatsapp: whatsappRaw || null,
        };
        const { error: profileErr } = await supabaseAdmin
          .from("profiles")
          .upsert(profileData, { onConflict: "user_id" });
        if (profileErr) {
          console.error("[signup] profile upsert failed:", profileErr);
          // Não falha o signup — profile pode ser criado depois.
        }

        // 4. Cria company com trial de 3 dias (do plano starter como default)
        //    Pega trial_days do plano starter.
        const { data: starter } = await supabaseAdmin
          .from("plan")
          .select("trial_days, slug")
          .eq("slug", "starter")
          .maybeSingle();
        const trialDays = Number(starter?.trial_days) || 3;
        const planSlug = starter?.slug ?? "starter";

        // Nome default da company = nome do user, ou "Minha Empresa"
        const companyName = nomeRaw || "Minha Empresa";
        const companySlug = `${slugify(companyName)}-${Math.random()
          .toString(36)
          .slice(2, 6)}`;
        const trialAte = new Date(
          Date.now() + trialDays * 86400000,
        ).toISOString();

        const { data: company, error: companyErr } = await supabaseAdmin
          .from("company")
          .insert({
            nome: companyName,
            slug: companySlug,
            primary_color: "#22C55E",
            created_by: userId,
            status_cobranca: "trial",
            onboarding_completed: false,
            onboarding_step: 0,
            trial_ate: trialAte,
            selected_plan_slug: planSlug,
          } as any)
          .select("id")
          .single();
        if (companyErr || !company) {
          console.error("[signup] company insert failed:", companyErr);
          return json(
            { error: companyErr?.message ?? "company_create_failed", user_id: userId },
            500,
          );
        }

        const companyId = company.id as string;

        // 5. Cria company_user como owner
        const { error: memberErr } = await supabaseAdmin
          .from("company_user")
          .insert({
            user_id: userId,
            company_id: companyId,
            role: "owner",
            ativo: true,
          });
        if (memberErr) {
          console.error("[signup] company_user insert failed:", memberErr);
          return json(
            { error: memberErr.message, user_id: userId, company_id: companyId },
            500,
          );
        }

        return json(
          {
            user_id: userId,
            email: data.user.email,
            company_id: companyId,
            trial_ate: trialAte,
          },
          200,
        );
      },
    },
  },
});