import { createFileRoute, redirect, useNavigate, useSearch } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { supabase } from "@/integrations/supabase/client";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { brand } from "@/config/brand";
import { Loader2, CheckCircle2, AlertCircle, ArrowLeft } from "lucide-react";
import { Link } from "@tanstack/react-router";

type Search = { plano?: string };

export const Route = createFileRoute("/callback")({
  ssr: false,
  head: () => ({ meta: [{ title: `${brand.name} — Autenticando…` }] }),
  validateSearch: (s: Record<string, unknown>): Search => ({
    plano: typeof s.plano === "string" ? s.plano : undefined,
  }),
  component: CallbackPage,
});

type Status = "loading" | "ok" | "error";

function CallbackPage() {
  const navigate = useNavigate();
  const search = useSearch({ from: "/callback" }) as Search;
  const [status, setStatus] = useState<Status>("loading");
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    let timeoutId: ReturnType<typeof setTimeout> | null = null;

    async function redirectAfterLogin(userId: string) {
      // Aguarda o trigger do banco rodar (cria profile, define role)
      await new Promise((r) => setTimeout(r, 800));

      const { data: roles } = await supabase
        .from("user_roles")
        .select("role")
        .eq("user_id", userId);

      const isSuperAdmin = (roles ?? []).some((r: any) => r.role === "super_admin");

      // Master (1º usuário) → painel master
      if (isSuperAdmin) {
        navigate({ to: "/master/welcome", replace: true });
        return;
      }

      // Tem plano no URL → checkout
      if (search.plano) {
        navigate({
          to: "/app/checkout",
          search: { plano: search.plano } as any,
          replace: true,
        });
        return;
      }

      // Cliente normal → checa se tem empresa
      const { data: cu } = await supabase
        .from("company_user")
        .select("company_id")
        .eq("user_id", userId)
        .eq("ativo", true)
        .maybeSingle();

      if (cu) {
        navigate({ to: "/app/dashboard", replace: true });
      } else {
        navigate({ to: "/app/checkout", replace: true });
      }
    }

    async function handle() {
      // Caminho 1: tokens no hash (#access_token...) — Supabase client processa
      // automaticamente via detectSessionInUrl. Escutamos onAuthStateChange pra
      // capturar o evento SIGNED_IN.
      const { data: sub } = supabase.auth.onAuthStateChange(async (event, session) => {
        if (cancelled) return;
        if (event === "SIGNED_IN" && session?.user) {
          if (timeoutId) clearTimeout(timeoutId);
          setStatus("ok");
          await redirectAfterLogin(session.user.id);
        }
      });

      // Caminho 2: já existe sessão em cookie (caso o usuário já tivesse logado antes).
      const { data: sessData } = await supabase.auth.getSession();
      if (cancelled) return;

      if (sessData.session?.user) {
        if (timeoutId) clearTimeout(timeoutId);
        setStatus("ok");
        await redirectAfterLogin(sessData.session.user.id);
        sub.subscription.unsubscribe();
        return;
      }

      // Caminho 3: PKCE code na query (?code=...). Troca por sessão.
      const code = new URLSearchParams(window.location.search).get("code");
      if (code) {
        const { error } = await supabase.auth.exchangeCodeForSession(code);
        if (!cancelled && !error && sessData.session?.user) {
          setStatus("ok");
          await redirectAfterLogin(sessData.session.user.id);
          sub.subscription.unsubscribe();
          return;
        }
      }

      // Timeout de segurança: se nada acontecer em 10s, mostra erro.
      timeoutId = setTimeout(() => {
        if (cancelled) return;
        setErrorMsg(
          "Não conseguimos validar o link. Pode ter expirado. Tente entrar de novo.",
        );
        setStatus("error");
        sub.subscription.unsubscribe();
      }, 10_000);
    }

    void handle();
    return () => {
      cancelled = true;
    };
  }, [navigate, search.plano]);

  return (
    <div className="min-h-screen grid place-items-center p-6 bg-background">
      <Card className="w-full max-w-md p-8 text-center space-y-5">
        {status === "loading" && (
          <>
            <div className="size-16 mx-auto rounded-full bg-primary/10 grid place-items-center">
              <Loader2 className="size-8 text-primary animate-spin" />
            </div>
            <div className="space-y-2">
              <h1 className="text-2xl font-bold tracking-tight">Autenticando…</h1>
              <p className="text-sm text-muted-foreground">
                Estamos confirmando seu acesso. Isso leva menos de 2 segundos.
              </p>
            </div>
          </>
        )}

        {status === "ok" && (
          <>
            <div className="size-16 mx-auto rounded-full bg-green-500/10 grid place-items-center">
              <CheckCircle2 className="size-8 text-green-500" />
            </div>
            <div className="space-y-2">
              <h1 className="text-2xl font-bold tracking-tight">Tudo certo!</h1>
              <p className="text-sm text-muted-foreground">
                Redirecionando para o painel…
              </p>
            </div>
          </>
        )}

        {status === "error" && (
          <>
            <div className="size-16 mx-auto rounded-full bg-red-500/10 grid place-items-center">
              <AlertCircle className="size-8 text-red-500" />
            </div>
            <div className="space-y-2">
              <h1 className="text-2xl font-bold tracking-tight">Link inválido</h1>
              <p className="text-sm text-muted-foreground">
                {errorMsg ?? "O link expirou ou já foi usado."}
              </p>
            </div>
            <div className="flex flex-col gap-2 pt-2">
              <Button asChild className="w-full">
                <Link to="/entrar">Tentar de novo</Link>
              </Button>
              <Button asChild variant="ghost" className="w-full">
                <Link to="/"><ArrowLeft className="size-4 mr-2" /> Voltar ao site</Link>
              </Button>
            </div>
          </>
        )}
      </Card>
    </div>
  );
}
