import { createFileRoute, redirect, useRouter } from "@tanstack/react-router";
import { Building2, Users, Package, CreditCard, Zap, Check } from "lucide-react";
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

    return { user: u.user };
  },
  component: MasterWelcome,
});

const features = [
  { icon: Building2, title: "Gerenciar Empresas", description: "Visualize e gerencie todas as empresas clientes.", href: "/master/empresas", color: "#22C55E" },
  { icon: Package, title: "Criar Planos", description: "Configure planos de assinatura.", href: "/master/planos", color: "#3B82F6" },
  { icon: CreditCard, title: "Visualizar Assinaturas", description: "Acompanhe todas as assinaturas ativas.", href: "/master/assinaturas", color: "#8B5CF6" },
  { icon: Users, title: "Estatísticas", description: "Veja métricas da plataforma.", href: "/master/painel", color: "#F59E0B" },
];

function MasterWelcome() {
  const ctx = Route.useRouteContext() as any;
  const router = useRouter();

  const userEmail = ctx?.user?.email || "";
  const userName = userEmail.split("@")[0];

  return (
    <div className="space-y-8">
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

      <div>
        <h2 className="text-xl font-semibold text-center mb-6">Próximos passos</h2>
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
      </div>

      <div className="max-w-2xl mx-auto pt-8">
        <div className="bg-muted/50 rounded-xl p-6">
          <h3 className="font-semibold mb-4 flex items-center gap-2">
            <Check className="size-4 text-green-500" />
            Como usar o {brand.name} Master
          </h3>
          <ul className="space-y-2 text-sm text-muted-foreground">
            <li>1. Adicione planos em /master/planos</li>
            <li>2. Configure webhooks do Kiwify/Cakto/PerfectPay (URLs em /master/configuracoes)</li>
            <li>3. Quando cliente pagar, ele recebe acesso automaticamente</li>
          </ul>
        </div>
      </div>
    </div>
  );
}
