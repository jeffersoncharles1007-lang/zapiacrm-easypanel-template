"use client";

import { createFileRoute } from "@tanstack/react-router";
import { HelpTip } from "@/components/help-tip";
import { useQuery } from "@tanstack/react-query";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs";
import {
  TrendingUp, TrendingDown, Minus, DollarSign, Users, Calendar,
  Target, Trophy, RefreshCw, AlertCircle
} from "lucide-react";
import { TrigoplastDashboard } from "@/components/trigoplast/dashboard";

export const Route = createFileRoute("/app/trigoplast/vendas")({
  head: () => ({ meta: [{ title: "Trigoplast — Vendas" }] }),
  component: VendasPage,
});

function formatCurrency(centavos: number): string {
  return new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: "BRL",
  }).format(centavos / 100);
}

function formatPercent(valor: number): string {
  return `${Math.round(valor * 100) / 100}%`;
}

interface VendaDiaria {
  data: string;
  diaSemana: string;
  meta: number;
  marina: number;
  luciana: number;
  renata: number;
  rodrigues: number;
  representantes: number;
  real: number;
  semana: number;
}

interface ResumoVendedor {
  nome: string;
  totalVendido: number;
  metaMensal: number;
  percentualMeta: number;
}

interface DashboardData {
  vendasDiarias: VendaDiaria[];
  totalReal: number;
  totalMeta: number;
  realizadoMeta: number;
  rankingVendedores: ResumoVendedor[];
  melhorDia: { data: string; valor: number };
  tendencia: "subindo" | "estavel" | "descendo";
}

interface ApiResponse {
  data: DashboardData | VendaDiaria[] | ResumoVendedor[];
  success: boolean;
  error?: string;
}

// ─── API Functions ──────────────────────────────────────────────────────────

async function fetchDashboardData(): Promise<DashboardData> {
  const res = await fetch("/api/trigoplast/vendas?resource=dashboard");
  if (!res.ok) throw new Error("Falha ao carregar dados");
  const json: ApiResponse = await res.json();
  if (!json.success) throw new Error(json.error || "Erro desconhecido");
  return json.data as DashboardData;
}

async function fetchVendas(dias = 14): Promise<VendaDiaria[]> {
  const res = await fetch(`/api/trigoplast/vendas?resource=vendas&dias=${dias}`);
  if (!res.ok) throw new Error("Falha ao carregar vendas");
  const json: ApiResponse = await res.json();
  if (!json.success) throw new Error(json.error || "Erro desconhecido");
  return json.data as VendaDiaria[];
}

async function fetchRanking(): Promise<ResumoVendedor[]> {
  const res = await fetch("/api/trigoplast/vendas?resource=ranking");
  if (!res.ok) throw new Error("Falha ao carregar ranking");
  const json: ApiResponse = await res.json();
  if (!json.success) throw new Error(json.error || "Erro desconhecido");
  return json.data as ResumoVendedor[];
}

// ─── Sub-components ──────────────────────────────────────────────────────────

function Scorecard({ titulo, valor, subvalor, icon: Icon, cor }: {
  titulo: string;
  valor: string;
  subvalor?: string;
  icon: React.ElementType;
  cor?: string;
}) {
  return (
    <Card>
      <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
        <CardTitle className="text-sm font-medium">{titulo}</CardTitle>
        <Icon className={`h-4 w-4 ${cor || "text-muted-foreground"}`} />
      </CardHeader>
      <CardContent>
        <div className="text-2xl font-bold">{valor}</div>
        {subvalor && <p className="text-xs text-muted-foreground">{subvalor}</p>}
      </CardContent>
    </Card>
  );
}

function TendenciaBadge({ tendencia }: { tendencia: string }) {
  const configs = {
    subindo: { icon: TrendingUp, label: "Subindo", className: "bg-green-100 text-green-800" },
    descendo: { icon: TrendingDown, label: "Descendo", className: "bg-red-100 text-red-800" },
    estavel: { icon: Minus, label: "Estável", className: "bg-yellow-100 text-yellow-800" },
  };
  const config = configs[tendencia as keyof typeof configs] || configs.estavel;
  const Icon = config.icon;

  return (
    <Badge className={`gap-1 ${config.className}`}>
      <Icon className="h-3 w-3" />
      {config.label}
    </Badge>
  );
}

function RankingCard({ ranking }: { ranking: ResumoVendedor[] }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Users className="h-5 w-5" />
          Ranking de Vendedores
        </CardTitle>
        <CardDescription>Performance no período</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          {ranking.map((vendedor, index) => (
            <div key={vendedor.nome} className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className={`flex h-8 w-8 items-center justify-center rounded-full text-sm font-bold ${
                  index === 0 ? "bg-yellow-500 text-white" :
                  index === 1 ? "bg-gray-400 text-white" :
                  index === 2 ? "bg-amber-600 text-white" :
                  "bg-muted"
                }`}>
                  {index + 1}
                </div>
                <div>
                  <p className="font-medium">{vendedor.nome}</p>
                  <p className="text-xs text-muted-foreground">
                    {formatCurrency(vendedor.totalVendido)}
                  </p>
                </div>
              </div>
              <div className="text-right">
                <p className={`font-bold ${
                  vendedor.percentualMeta >= 100 ? "text-green-600" :
                  vendedor.percentualMeta >= 50 ? "text-yellow-600" :
                  "text-red-600"
                }`}>
                  {formatPercent(vendedor.percentualMeta)}
                </p>
                <p className="text-xs text-muted-foreground">da meta</p>
              </div>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}

function VendasChart({ vendas }: { vendas: VendaDiaria[] }) {
  const ultimasVendas = vendas.slice(-7);

  if (ultimasVendas.length === 0) {
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Calendar className="h-5 w-5" />
            Vendas Recentes
          </CardTitle>
        </CardHeader>
        <CardContent>
          <p className="text-muted-foreground">Nenhuma venda registrada.</p>
        </CardContent>
      </Card>
    );
  }

  const maxValor = Math.max(...ultimasVendas.map(v => v.real));

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Calendar className="h-5 w-5" />
          Vendas Recentes (7 dias)
        </CardTitle>
        <CardDescription>Barras mostram realizados vs meta</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="space-y-2">
          {ultimasVendas.map((venda, i) => {
            const percentualMeta = venda.meta > 0 ? (venda.real / venda.meta) * 100 : 0;
            const barraReal = venda.real > 0 ? Math.min((venda.real / maxValor) * 100, 100) : 0;
            const barraMeta = venda.meta > 0 ? Math.min((venda.meta / maxValor) * 100, 100) : 0;

            return (
              <div key={i} className="space-y-1">
                <div className="flex justify-between text-xs">
                  <span className="font-medium">{venda.data}</span>
                  <span className="text-muted-foreground">{venda.diaSemana}</span>
                </div>
                <div className="relative h-6 w-full overflow-hidden rounded bg-muted">
                  <div
                    className="absolute h-full bg-gray-300 opacity-50"
                    style={{ width: `${barraMeta}%` }}
                  />
                  <div
                    className={`absolute h-full ${percentualMeta >= 100 ? "bg-green-500" : "bg-blue-500"}`}
                    style={{ width: `${barraReal}%` }}
                  />
                </div>
                <div className="flex justify-between text-xs">
                  <span className={percentualMeta >= 100 ? "text-green-600" : "text-blue-600"}>
                    Real: {formatCurrency(venda.real)}
                  </span>
                  <span className="text-muted-foreground">
                    Meta: {formatCurrency(venda.meta)}
                  </span>
                </div>
              </div>
            );
          })}
        </div>
      </CardContent>
    </Card>
  );
}

function TabelaVendas({ vendas }: { vendas: VendaDiaria[] }) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>Detalhamento de Vendas</CardTitle>
        <CardDescription>Vendas por vendedor nos últimos 14 dias</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b">
                <th className="pb-2 text-left font-medium">Data</th>
                <th className="pb-2 text-right font-medium">MARINA</th>
                <th className="pb-2 text-right font-medium">LUCIANA</th>
                <th className="pb-2 text-right font-medium">RENATA/TF</th>
                <th className="pb-2 text-right font-medium">RODRIGUES</th>
                <th className="pb-2 text-right font-medium">Representantes</th>
                <th className="pb-2 text-right font-medium">Total Real</th>
              </tr>
            </thead>
            <tbody>
              {vendas.slice(-14).reverse().map((venda, i) => (
                <tr key={i} className="border-b">
                  <td className="py-2">
                    <span className="font-medium">{venda.data}</span>
                    <span className="ml-2 text-xs text-muted-foreground">{venda.diaSemana}</span>
                  </td>
                  <td className="py-2 text-right">{formatCurrency(venda.marina)}</td>
                  <td className="py-2 text-right">{formatCurrency(venda.luciana)}</td>
                  <td className="py-2 text-right">{formatCurrency(venda.renata)}</td>
                  <td className="py-2 text-right">{formatCurrency(venda.rodrigues)}</td>
                  <td className="py-2 text-right">{formatCurrency(venda.representantes)}</td>
                  <td className="py-2 text-right font-medium">{formatCurrency(venda.real)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </CardContent>
    </Card>
  );
}

function LoadingSkeleton() {
  return (
    <div className="space-y-4">
      <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
        {[...Array(4)].map((_, i) => (
          <Card key={i}>
            <CardHeader className="pb-2">
              <Skeleton className="h-4 w-24" />
            </CardHeader>
            <CardContent>
              <Skeleton className="h-8 w-32" />
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}

function ErrorState({ error, onRetry }: { error: string; onRetry: () => void }) {
  return (
    <Card className="border-red-200 bg-red-50 dark:bg-red-950/20">
      <CardContent className="flex flex-col items-center justify-center py-12">
        <AlertCircle className="h-12 w-12 text-red-500 mb-4" />
        <h3 className="font-semibold text-lg mb-2">Erro ao carregar dados</h3>
        <p className="text-sm text-muted-foreground mb-4 text-center max-w-md">{error}</p>
        <Button variant="outline" onClick={onRetry} className="gap-2">
          <RefreshCw className="h-4 w-4" />
          Tentar novamente
        </Button>
      </CardContent>
    </Card>
  );
}

// ─── Main Page ───────────────────────────────────────────────────────────────

function VendasPage() {
  const { data: dashboard, isLoading: loadingDash, error: errorDash, refetch: refetchDash } = useQuery({
    queryKey: ["trigoplast-dashboard"],
    queryFn: fetchDashboardData,
    refetchInterval: 5 * 60 * 1000,
    retry: 2,
  });

  const { data: ranking, isLoading: loadingRank } = useQuery({
    queryKey: ["trigoplast-ranking"],
    queryFn: fetchRanking,
    refetchInterval: 5 * 60 * 1000,
    retry: 2,
  });

  const { data: vendas, isLoading: loadingVendas } = useQuery({
    queryKey: ["trigoplast-vendas"],
    queryFn: () => fetchVendas(14),
    refetchInterval: 5 * 60 * 1000,
    retry: 2,
  });

  const isLoading = loadingDash || loadingRank || loadingVendas;
  const hasError = errorDash;

  return (
    <div className="space-y-6">
      <header className="flex flex-wrap items-end justify-between gap-3">
        <div className="min-w-0">
          <h1 className="font-display text-[26px] font-extrabold tracking-tight flex items-center gap-2">
            Vendas Trigoplast
            <HelpTip text="Dashboard de vendas extraído da planilha de controle. Atualização automática a cada 5 minutos." />
          </h1>
          <p className="text-sm text-muted-foreground">
            {hasError
              ? "Erro ao carregar dados"
              : isLoading
              ? "Carregando..."
              : `Última atualização: ${new Date().toLocaleTimeString("pt-BR")}`
            }
          </p>
        </div>
        <Button
          variant="outline"
          size="sm"
          onClick={() => { refetchDash(); }}
          className="gap-2"
        >
          <RefreshCw className={`h-4 w-4 ${loadingDash ? "animate-spin" : ""}`} />
          Atualizar
        </Button>
      </header>

      {hasError ? (
        <ErrorState error={errorDash.message} onRetry={() => refetchDash()} />
      ) : isLoading ? (
        <LoadingSkeleton />
      ) : (
        <>
          {/* Scorecards */}
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-4">
            <Scorecard
              titulo="Total Realizado"
              valor={formatCurrency(dashboard?.totalReal || 0)}
              subvalor={`${formatPercent(dashboard?.realizadoMeta || 0)} da meta`}
              icon={DollarSign}
              cor="text-green-600"
            />
            <Scorecard
              titulo="Meta do Período"
              valor={formatCurrency(dashboard?.totalMeta || 0)}
              subvalor="Total planejado"
              icon={Target}
              cor="text-blue-600"
            />
            <Scorecard
              titulo="Melhor Dia"
              valor={formatCurrency(dashboard?.melhorDia?.valor || 0)}
              subvalor={dashboard?.melhorDia?.data || "-"}
              icon={Trophy}
              cor="text-yellow-600"
            />
            <Card>
              <CardHeader className="flex flex-row items-center justify-between space-y-0 pb-2">
                <CardTitle className="text-sm font-medium">Tendência</CardTitle>
                {dashboard?.tendencia && <TendenciaBadge tendencia={dashboard.tendencia} />}
              </CardHeader>
              <CardContent>
                <div className="text-2xl font-bold">
                  {dashboard?.tendencia
                    ? dashboard.tendencia.charAt(0).toUpperCase() + dashboard.tendencia.slice(1)
                    : "Estável"}
                </div>
                <p className="text-xs text-muted-foreground">Últimos 7 dias vs anteriores</p>
              </CardContent>
            </Card>
          </div>

          {/* Gráficos e Ranking */}
          <div className="grid gap-4 md:grid-cols-2">
            <VendasChart vendas={vendas || []} />
            <RankingCard ranking={ranking || []} />
          </div>

          {/* Tabela Detalhada */}
          <Tabs defaultValue="tabela" className="w-full">
            <TabsList>
              <TabsTrigger value="tabela">Tabela Detalhada</TabsTrigger>
              <TabsTrigger value="dashboard">Dashboard Completo</TabsTrigger>
            </TabsList>
            <TabsContent value="tabela" className="mt-4">
              <TabelaVendas vendas={vendas || []} />
            </TabsContent>
            <TabsContent value="dashboard" className="mt-4">
              <TrigoplastDashboard />
            </TabsContent>
          </Tabs>
        </>
      )}
    </div>
  );
}
