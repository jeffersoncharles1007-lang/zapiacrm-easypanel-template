import { createFileRoute, redirect } from "@tanstack/react-router";
import { useState } from "react";
import { useRouter } from "@tanstack/react-router";
import { Building2, Users, Package, CreditCard, Zap, ArrowRight, Check } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { supabase } from "@/integrations/supabase/client";
import { brand } from "@/config/brand";

export const Route = createFileRoute("/master/welcome")({
  ssr: false,
  beforeLoad: async () => {
    const { data: u } = await supabase.auth.getUser();
    if (!u.user) throw redirect({ to: "/entrar" });

    const { data: roles } = await supabase.from("user_roles").select("role").eq("user_id", u.user.id);
    const isSuper = (roles ?? []).some((r: any) => r.role === "super_admin");
    if (!isSuper) {
      throw redirect({ to: "/master/painel" });
    }

    // Verifica se já tem empresa criada
    const { data: cu } = await supabase
      .from("company_user")
      .select("company_id")
      .eq("user_id", u.user.id)
      .maybeSingle();

    // Se já tem empresa, redireciona para o painel
    if (cu) {
      throw redirect({ to: "/master/painel" });
    }

    return { user: u.user };
  },
  component: MasterWelcome,
});

const features = [
  {
    icon: Building2,
    title: "Gerenciar Empresas",
    description: "Visualize e gerencie todas as empresas clientes da sua plataforma.",
    href: "/master/empresas",
    color: "#22C55E",
  },
  {
    icon: Package,
    title: "Criar Planos",
    description: "Configure planos de assinatura para vender aos seus clientes.",
    href: "/master/planos",
    color: "#3B82F6",
  },
  {
    icon: CreditCard,
    title: "Visualizar Assinaturas",
    description: "Acompanhe todas as assinaturas ativas do sistema.",
    href: "/master/assinaturas",
    color: "#8B5CF6",
  },
  {
    icon: Users,
    title: "Estatísticas",
    description: "Veja métricas e indicadores da sua plataforma.",
    href: "/master/painel",
    color: "#F59E0B",
  },
];

function MasterWelcome() {
  const ctx = Route.useRouteContext() as any;
  const router = useRouter();
  const [loading, setLoading] = useState(false);
  const [showCompanyForm, setShowCompanyForm] = useState(false);
  const [companyName, setCompanyName] = useState("");

  const userEmail = ctx?.user?.email || "";
  const userName = userEmail.split("@")[0];

  const handleCreateCompany = async () => {
    if (!companyName.trim()) return;
    setLoading(true);

    try {
      const { data: { user } } = await supabase.auth.getUser();
      if (!user) throw new Error("Não autenticado");

      // Cria empresa
      const { data: company, error: companyError } = await supabase
        .from("company")
        .insert({
          nome: companyName.trim(),
          slug: companyName.trim().toLowerCase().replace(/\s+/g, "-").replace(/[^a-z0-9-]/g, ""),
          status_cobranca: "ativo",
          created_by: user.id,
        })
        .select()
        .single();

      if (companyError) throw companyError;

      // Cria membership como owner
      const { error: memberError } = await supabase
        .from("company_user")
        .insert({
          user_id: user.id,
          company_id: company.id,
          role: "owner",
        });

      if (memberError) throw memberError;

      // Redireciona para o app
      router.navigate({ to: "/app/onboarding", replace: true });
    } catch (error) {
      console.error("Erro ao criar empresa:", error);
      alert("Erro ao criar empresa. Tente novamente.");
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="space-y-8">
      {/* Header */}
      <div className="text-center max-w-2xl mx-auto pt-8">
        <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-green-100 text-green-700 text-sm font-medium mb-6">
          <Zap className="size-4" />
          Primeiro acesso
        </div>

        <h1 className="text-4xl font-bold tracking-tight mb-4">
          Bem-vindo, {userName}! 👋
        </h1>

        <p className="text-lg text-muted-foreground mb-2">
          Você é o <strong className="text-green-600">administrador master</strong> desta plataforma.
        </p>

        <p className="text-muted-foreground">
          Use o painel master para gerenciar empresas clientes, criar planos de assinatura e acompanhar métricas do sistema.
        </p>
      </div>

      {/* Features Grid */}
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4 max-w-5xl mx-auto">
        {features.map((feature) => {
          const Icon = feature.icon;
          return (
            <Card
              key={feature.title}
              className="group cursor-pointer transition-all duration-200 hover:shadow-lg hover:border-primary/50"
              onClick={() => router.navigate({ to: feature.href })}
            >
              <CardHeader className="pb-3">
                <div
                  className="size-10 rounded-lg grid place-items-center mb-3"
                  style={{ backgroundColor: `${feature.color}15`, color: feature.color }}
                >
                  <Icon className="size-5" />
                </div>
                <CardTitle className="text-base">{feature.title}</CardTitle>
              </CardHeader>
              <CardContent>
                <CardDescription>{feature.description}</CardDescription>
              </CardContent>
            </Card>
          );
        })}
      </div>

      {/* Divider */}
      <div className="flex items-center gap-4 max-w-2xl mx-auto">
        <div className="flex-1 h-px bg-border" />
        <span className="text-sm text-muted-foreground">ou</span>
        <div className="flex-1 h-px bg-border" />
      </div>

      {/* Create Company Section */}
      <div className="max-w-xl mx-auto text-center">
        <h2 className="text-xl font-semibold mb-2">
          Quer usar o sistema como cliente também?
        </h2>
        <p className="text-muted-foreground mb-6">
          Você pode criar sua própria empresa para testar o sistema como um cliente normal.
        </p>

        {!showCompanyForm ? (
          <Button
            onClick={() => setShowCompanyForm(true)}
            variant="outline"
            className="gap-2"
          >
            <Building2 className="size-4" />
            Criar minha empresa
            <ArrowRight className="size-4" />
          </Button>
        ) : (
          <Card className="border-dashed">
            <CardContent className="pt-6">
              <div className="space-y-4">
                <div>
                  <label className="text-sm font-medium mb-2 block text-left">
                    Nome da empresa
                  </label>
                  <input
                    type="text"
                    value={companyName}
                    onChange={(e) => setCompanyName(e.target.value)}
                    placeholder="Ex: Minha Empresa Ltda"
                    className="w-full px-3 py-2 rounded-lg border border-input bg-background text-sm"
                    autoFocus
                  />
                </div>
                <div className="flex gap-2">
                  <Button
                    onClick={handleCreateCompany}
                    disabled={!companyName.trim() || loading}
                    className="flex-1"
                  >
                    {loading ? "Criando..." : "Criar empresa"}
                  </Button>
                  <Button
                    onClick={() => {
                      setShowCompanyForm(false);
                      setCompanyName("");
                    }}
                    variant="ghost"
                  >
                    Cancelar
                  </Button>
                </div>
              </div>
            </CardContent>
          </Card>
        )}
      </div>

      {/* Quick Links */}
      <div className="max-w-2xl mx-auto pt-8">
        <div className="bg-muted/50 rounded-xl p-6">
          <h3 className="font-semibold mb-4 flex items-center gap-2">
            <Check className="size-4 text-green-500" />
            Próximos passos recomendados
          </h3>
          <ul className="space-y-2 text-sm text-muted-foreground">
            <li className="flex items-center gap-2">
              <span className="size-1.5 rounded-full bg-green-500" />
              1. Configure seus planos de assinatura em Planos
            </li>
            <li className="flex items-center gap-2">
              <span className="size-1.5 rounded-full bg-green-500" />
              2. Visualize o dashboard para entender as métricas
            </li>
            <li className="flex items-center gap-2">
              <span className="size-1.5 rounded-full bg-green-500" />
              3. Crie sua primeira empresa de teste
            </li>
          </ul>
        </div>
      </div>
    </div>
  );
}
