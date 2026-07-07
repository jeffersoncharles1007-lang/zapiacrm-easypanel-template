import { createFileRoute, redirect, useNavigate, Link, useSearch } from "@tanstack/react-router";
import { useState } from "react";
import { z } from "zod";
import { supabase } from "@/integrations/supabase/client";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Card } from "@/components/ui/card";
import { toast } from "sonner";
import {
  MessageCircle, Sparkles, Loader2, Bot, KanbanSquare, ShieldCheck,
  ArrowLeft, Mail,
} from "lucide-react";
import { brand } from "@/config/brand";

type Search = { modo?: "login" | "criar"; plano?: string };

export const Route = createFileRoute("/entrar")({
  ssr: false,
  head: () => ({ meta: [{ title: `${brand.name} — Começar` }] }),
  validateSearch: (s: Record<string, unknown>): Search => ({
    modo: s.modo === "criar" ? "criar" : "login",
    plano: typeof s.plano === "string" ? s.plano : undefined,
  }),
  beforeLoad: async ({ search }) => {
    const { data } = await supabase.auth.getUser();
    if (data.user) {
      const dest = search.plano
        ? `/app/checkout?plano=${encodeURIComponent(search.plano)}`
        : "/app/dashboard";
      throw redirect({ href: dest });
    }
  },
  component: EntrarPage,
});

const PLAN_LABEL: Record<string, { nome: string; preco: string }> = {
  starter: { nome: "Starter", preco: "R$ 97/mês" },
  pro: { nome: "Pro", preco: "R$ 197/mês" },
  business: { nome: "Business", preco: "R$ 497/mês" },
};

const emailSchema = z.string().email("E-mail inválido").trim().toLowerCase();

/**
 * Fluxo simplificado: SEM senha, SEM código de 6 dígitos.
 * Cada login = um magiclink enviado por email (template do Supabase).
 *
 * - Clicar "Criar": envia magiclink; se user já existe, supabase retorna OK
 *   silenciosamente (não revela se email tá cadastrado — segurança)
 * - Clicar "Entrar": mesma chamada signInWithOtp, garante que user existe
 * - Clicar "Criar": envia magiclink; se user já existe, supabase retorna OK
 *
 * Quando o user clica no link do email → sessão criada → vai pra /callback
 * → callback redireciona pra /master/welcome (se super_admin) ou /app/dashboard
 */
function EntrarPage() {
  const navigate = useNavigate();
  const search = useSearch({ from: "/entrar" }) as Search;
  const [tab, setTab] = useState<"entrar" | "criar">(search.modo === "criar" ? "criar" : "entrar");
  const [email, setEmail] = useState("");
  const [loading, setLoading] = useState(false);
  const [sentAt, setSentAt] = useState<number | null>(null);

  const planInfo = search.plano ? PLAN_LABEL[search.plano] : null;
  const cooldownMs = 60_000; // anti-spam: 1 link/min
  const cooldownLeft = sentAt ? Math.max(0, cooldownMs - (Date.now() - sentAt)) : 0;

  function switchTab(newTab: "entrar" | "criar") {
    setTab(newTab);
    setSentAt(null);
  }

  async function sendMagicLink() {
    const parsed = emailSchema.safeParse(email);
    if (!parsed.success) {
      toast.error("Email inválido");
      return;
    }

    if (cooldownLeft > 0) {
      toast.message(`Aguarde ${Math.ceil(cooldownLeft / 1000)}s antes de pedir novo link.`);
      return;
    }

    setLoading(true);
    try {
      const redirectTo = `${window.location.origin}/callback`;
      const { error } = await supabase.auth.signInWithOtp({
        email: parsed.data,
        options: {
          emailRedirectTo: redirectTo,
          shouldCreateUser: tab === "entrar" ? false : true,
        },
      });

      // Supabase retorna OK silencioso se o email NÃO existe (privacidade).
      // Mas aqui no client tratamos erros reais de transporte.
      if (error) {
        // rate-limit excedido, email inválido, etc.
        const msg = error.message.toLowerCase();
        if (msg.includes("rate") || msg.includes("limit")) {
          toast.error("Muitas tentativas. Aguarde alguns minutos.");
        } else if (msg.includes("signups not allowed") || msg.includes("signups_disabled")) {
          toast.error("Cadastros novos desativados. Use 'Entrar' se já tem conta.");
        } else {
          toast.error(error.message);
        }
        return;
      }

      setSentAt(Date.now());
      // Mensagem neutra (não revela se email tá cadastrado)
      toast.success("Se o email estiver cadastrado, você receberá um link em instantes.");
    } catch (e: unknown) {
      const msg = e instanceof Error ? e.message : String(e);
      toast.error(msg);
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="min-h-screen w-full relative overflow-hidden bg-background text-foreground">
      <div className="relative z-10 min-h-screen grid lg:grid-cols-[1.05fr_1fr]">
        {/* LEFT — brand pane */}
        <aside className="hidden lg:flex flex-col justify-between p-10 xl:p-14 border-r border-[color:var(--hairline)] bg-[linear-gradient(160deg,rgba(22,163,74,.10),rgba(34,211,238,.04)_55%,transparent)]">
          <div className="flex items-center gap-3">
            <Link to="/" className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground transition-colors">
              <ArrowLeft className="size-4" />
              voltar ao site
            </Link>
          </div>

          <div className="space-y-8 max-w-lg">
            <div className="flex items-center gap-3">
              <div className="size-12 rounded-2xl grid place-items-center bg-gradient-brand text-primary-foreground shadow-[0_10px_30px_-10px_rgba(22,163,74,.6)] ring-1 ring-white/20">
                <MessageCircle className="size-6" strokeWidth={2.4} />
              </div>
              <div>
                <div className="font-display font-extrabold text-2xl text-gradient-brand leading-none">{brand.name}</div>
                <div className="text-[12px] text-muted-foreground mt-1">{brand.tagline}</div>
              </div>
            </div>

            <h1 className="font-display text-4xl xl:text-5xl font-extrabold leading-[1.05] tracking-tight">
              Sua IA atende o<br />
              <span className="text-gradient-brand">WhatsApp 24h</span> e<br />
              organiza o CRM sozinha.
            </h1>

            <p className="text-[15px] text-muted-foreground leading-relaxed">
              Conecte seu número em 2 minutos. A gente cuida do resto — respostas, qualificação e movimentação dos leads no funil, no automático.
            </p>

            <div className="grid gap-3">
              <Feature icon={<Bot className="size-4" />} title="IA treinada no seu negócio" desc="Responde no seu tom, sem parecer robô." />
              <Feature icon={<KanbanSquare className="size-4" />} title="CRM Kanban inteligente" desc="Cada lead se move sozinho pelo funil." />
              <Feature icon={<Mail className="size-4" />} title="Acesso por email" desc="Sem senha — cada login = novo link no seu email." />
            </div>

            <div className="flex items-center gap-4 pt-2 text-xs text-muted-foreground">
              <span className="inline-flex items-center gap-1.5"><ShieldCheck className="size-3.5 text-[color:var(--brand)]" /> LGPD-friendly</span>
              <span className="inline-flex items-center gap-1.5"><ShieldCheck className="size-3.5 text-[color:var(--brand)]" /> Sem cartão p/ testar</span>
              <span className="inline-flex items-center gap-1.5"><ShieldCheck className="size-3.5 text-[color:var(--brand)]" /> Cancele quando quiser</span>
            </div>
          </div>

          <div className="text-[12px] text-muted-foreground">
            © {new Date().getFullYear()} {brand.name}. Todos os direitos reservados.
          </div>
        </aside>

        {/* RIGHT — form */}
        <main className="flex flex-col items-center justify-center px-5 py-10 sm:px-10">
          <div className="lg:hidden w-full max-w-md mb-6 flex items-center justify-between">
            <Link to="/" className="inline-flex items-center gap-2 text-sm text-muted-foreground hover:text-foreground">
              <ArrowLeft className="size-4" /> voltar
            </Link>
            <div className="flex items-center gap-2">
              <div className="size-9 rounded-xl grid place-items-center bg-gradient-brand text-primary-foreground shadow-md">
                <MessageCircle className="size-4" />
              </div>
              <div className="font-display font-bold text-[15px] text-gradient-brand">{brand.name}</div>
            </div>
          </div>

          <div className="w-full max-w-md">
            <div className="relative panel p-7 sm:p-8 glow-brand overflow-hidden">
              <div aria-hidden className="absolute -top-24 -right-24 size-56 rounded-full blur-3xl opacity-50"
                   style={{ background: "radial-gradient(circle, rgba(22,163,74,.35) 0%, transparent 70%)" }} />

              <div className="relative">
                {planInfo && tab !== "entrar" && (
                  <div className="mb-5 rounded-xl border border-[color:var(--brand)]/30 bg-[color:var(--brand-soft)] p-4">
                    <div className="flex items-center gap-2 text-[11px] uppercase font-bold tracking-[0.14em] text-[color:var(--brand-text)]">
                      <Sparkles className="size-3.5" /> Plano escolhido
                    </div>
                    <div className="mt-1 flex items-baseline justify-between">
                      <div className="font-display text-lg font-bold">{planInfo.nome}</div>
                      <div className="text-sm font-semibold">{planInfo.preco}</div>
                    </div>
                  </div>
                )}

                <div className="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full bg-[color:var(--brand-soft)] border border-[color:var(--brand)]/20 text-[11px] font-semibold text-[color:var(--brand-text)] mb-3">
                  <span className="size-1.5 rounded-full bg-[color:var(--brand)] dot-pulse" />
                  Acesso por email
                </div>

                <h1 className="font-display text-[26px] sm:text-[28px] font-extrabold leading-tight tracking-tight">
                  {tab === "entrar" ? "Bem-vindo de volta" : tab === "criar" ? "Comece agora" : "Recupere o acesso"}
                </h1>
                <p className="text-sm text-muted-foreground mt-1.5 mb-5">
                  {tab === "entrar" && "Vamos enviar um link de acesso pro seu email."}
                  {tab === "criar" && "Vamos criar sua conta via link no email."}
                </p>

                {/* Tabs */}
                <div className="flex gap-1 p-1 rounded-lg bg-muted/50 mb-5">
                  <button type="button" onClick={() => switchTab("entrar")}
                    className={`flex-1 py-2 px-3 rounded-md text-sm font-medium transition-colors flex items-center justify-center gap-2 ${tab === "entrar" ? "bg-background shadow-sm" : "text-muted-foreground hover:text-foreground"}`}>
                    <Mail className="size-4" /> Entrar
                  </button>
                  <button type="button" onClick={() => switchTab("criar")}
                    className={`flex-1 py-2 px-3 rounded-md text-sm font-medium transition-colors flex items-center justify-center gap-2 ${tab === "criar" ? "bg-background shadow-sm" : "text-muted-foreground hover:text-foreground"}`}>
                    <Sparkles className="size-4" /> Criar
                  </button>
                </div>

                {sentAt ? (
                  <Card className="p-5 text-center space-y-4 border-primary/30 bg-primary/5">
                    <div className="size-14 mx-auto rounded-full bg-primary/10 grid place-items-center">
                      <Mail className="size-7 text-primary" />
                    </div>
                    <div className="space-y-2">
                      <h2 className="font-semibold text-lg">Link enviado!</h2>
                      <p className="text-sm text-muted-foreground">
                        Verifique sua caixa de entrada (e o spam) em <strong>{email}</strong>.
                        Clique no link pra entrar.
                      </p>
                      <p className="text-xs text-muted-foreground">
                        O link expira em 1 hora.
                      </p>
                    </div>
                    <div className="flex flex-col gap-2 pt-2">
                      <Button variant="outline" size="sm" onClick={() => setSentAt(null)}>
                        Usar outro email
                      </Button>
                    </div>
                  </Card>
                ) : (
                  <form onSubmit={(e) => { e.preventDefault(); void sendMagicLink(); }} className="space-y-4">
                    <div className="space-y-1.5">
                      <Label htmlFor="email">E-mail</Label>
                      <Input
                        id="email"
                        type="email"
                        value={email}
                        onChange={(e) => setEmail(e.target.value)}
                        required
                        autoFocus
                        placeholder="voce@empresa.com"
                        className="h-11"
                      />
                    </div>

                    <Button
                      type="submit"
                      disabled={loading}
                      size="lg"
                      className="w-full h-12 bg-gradient-brand text-primary-foreground hover:opacity-95 font-semibold text-[14.5px] shadow-[0_8px_24px_-10px_rgba(22,163,74,.6)]"
                    >
                      {loading && <Loader2 className="size-4 mr-2 animate-spin" />}
                      {tab === "entrar" && "Enviar link de acesso"}
                      {tab === "criar" && "Enviar link pra criar conta"}
                    </Button>
                  </form>
                )}

                <p className="text-[11px] text-muted-foreground text-center mt-4">
                  🔒 Privacidade: o sistema não revela se o email está cadastrado —
                  a mesma mensagem aparece em ambos os casos.
                </p>
              </div>
            </div>

            <p className="text-[11.5px] text-muted-foreground text-center mt-5">
              Ao continuar, você concorda com nossos{" "}
              <Link to="/termos" className="underline underline-offset-2 hover:text-foreground">Termos</Link>{" "}
              e{" "}
              <Link to="/privacidade" className="underline underline-offset-2 hover:text-foreground">Política de privacidade</Link>.
            </p>
          </div>
        </main>
      </div>
    </div>
  );
}

function Feature({ icon, title, desc }: { icon: React.ReactNode; title: string; desc: string }) {
  return (
    <div className="flex items-start gap-3 rounded-xl border border-[color:var(--hairline)] bg-[color:var(--panel)]/60 backdrop-blur-sm p-3.5">
      <div className="size-9 rounded-lg grid place-items-center bg-[color:var(--brand-soft)] text-[color:var(--brand-text)] shrink-0 ring-1 ring-[color:var(--brand)]/15">
        {icon}
      </div>
      <div className="min-w-0">
        <div className="font-semibold text-[13.5px] leading-tight">{title}</div>
        <div className="text-[12px] text-muted-foreground mt-0.5">{desc}</div>
      </div>
    </div>
  );
}
