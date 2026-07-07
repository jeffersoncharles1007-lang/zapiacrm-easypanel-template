// API pública /api/trigoplast/vendas — dados da planilha de vendas
import { createFileRoute } from "@tanstack/react-router";

// ─── Auth (simplificado — verificar Bearer token ou IP permitido) ───────────────

async function auth(request: Request): Promise<boolean> {
  // TODO: Implementar autenticação real com Supabase
  // Por enquanto, permite acesso (remover em produção!)
  return true;

  // Auth real:
  // const h = request.headers.get("authorization") || "";
  // const m = h.match(/^Bearer\s+(azp_[a-z0-9]+)$/i);
  // if (!m) return false;
  // ...verificar token no banco...
}

async function handle(request: Request) {
  // CORS headers
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, Authorization",
    "Content-Type": "application/json",
  };

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  if (!await auth(request)) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: corsHeaders,
    });
  }

  if (request.method !== "GET") {
    return new Response(JSON.stringify({ error: "Method Not Allowed" }), {
      status: 405,
      headers: corsHeaders,
    });
  }

  try {
    const { getDashboardData, getVendasRecentes, getRankingVendedores } = await import("@/lib/erps/planilha-adapter");
    const url = new URL(request.url);
    const resource = url.searchParams.get("resource") || "dashboard";
    const dias = parseInt(url.searchParams.get("dias") || "7", 10);

    if (resource === "dashboard") {
      const data = await getDashboardData();
      return Response.json({ data }, { headers: corsHeaders });
    }

    if (resource === "vendas") {
      const vendas = await getVendasRecentes(dias);
      return Response.json({ data: vendas }, { headers: corsHeaders });
    }

    if (resource === "ranking") {
      const ranking = await getRankingVendedores();
      return Response.json({ data: ranking }, { headers: corsHeaders });
    }

    return new Response(JSON.stringify({ error: "Unknown resource" }), {
      status: 400,
      headers: corsHeaders,
    });
  } catch (error) {
    console.error("[trigoplast/vendas]", error);
    return new Response(JSON.stringify({
      error: "Internal Server Error",
      message: error instanceof Error ? error.message : "Unknown error",
    }), {
      status: 500,
      headers: corsHeaders,
    });
  }
}

export const Route = createFileRoute("/api/trigoplast/vendas")({
  server: {
    handlers: {
      GET: ({ request }) => handle(request),
      OPTIONS: () => handle(new Request("http://localhost", { method: "OPTIONS" })),
    },
  },
});
