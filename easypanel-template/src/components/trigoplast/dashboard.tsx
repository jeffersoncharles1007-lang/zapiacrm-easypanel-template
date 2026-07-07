"use client";

import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { TrendingUp, TrendingDown, Minus } from "lucide-react";

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

function formatCurrency(centavos: number): string {
  return new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: "BRL",
  }).format(centavos / 100);
}

function formatPercent(valor: number): string {
  return `${Math.round(valor * 100) / 100}%`;
}

export function TrigoplastDashboard() {
  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle>Sobre o Dashboard Trigoplast</CardTitle>
          <CardDescription>
            Este dashboard exibe dados de vendas extraídos da planilha de controle.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="space-y-4">
            <div>
              <h4 className="font-semibold mb-2">Vendedores Monitorados</h4>
              <ul className="list-disc list-inside text-sm text-muted-foreground space-y-1">
                <li><strong>Marina</strong> — Gerente de vendas</li>
                <li><strong>Luciana</strong> — Vendas internas</li>
                <li><strong>Renata/TF</strong> — Força de vendas</li>
                <li><strong>Rodriguez</strong> — Vendas externas</li>
                <li><strong>Representantes</strong> — Canal indireto</li>
              </ul>
            </div>

            <div>
              <h4 className="font-semibold mb-2">Como Funciona</h4>
              <ol className="list-decimal list-inside text-sm text-muted-foreground space-y-1">
                <li>Dados são extraídos da planilha Google Sheets</li>
                <li>Atualização automática a cada 5 minutos</li>
                <li>Cálculos de ranking e tendências em tempo real</li>
                <li>Comparativo de desempenho vs meta</li>
              </ol>
            </div>

            <div className="bg-muted/50 rounded-lg p-4">
              <h4 className="font-semibold mb-2">Configuração Necessária</h4>
              <p className="text-sm text-muted-foreground">
                Para ativar o dashboard completo, configure as seguintes variáveis de ambiente:
              </p>
              <pre className="mt-2 text-xs bg-black/10 dark:bg-white/10 p-2 rounded overflow-x-auto">
{`TRIGOPLAST_SPREADSHEET_ID=<ID da planilha>
TRIGOPLAST_SHEET_NAME=VENDAS
GOOGLE_PROJECT_ID=<ID do projeto>
GOOGLE_PRIVATE_KEY=<chave privada>
GOOGLE_CLIENT_EMAIL=<email do serviço>`}
              </pre>
            </div>
          </div>
        </CardContent>
      </Card>

      <div className="grid gap-4 md:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="text-sm">Indicadores de Performance</CardTitle>
          </CardHeader>
          <CardContent>
            <div className="space-y-3">
              <div className="flex items-center justify-between">
                <span className="text-sm">Realizado vs Meta</span>
                <span className="text-sm font-medium text-yellow-600">Aguardando dados</span>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm">Tendencia</span>
                <div className="flex items-center gap-1">
                  <Minus className="h-4 w-4 text-yellow-500" />
                  <span className="text-sm font-medium text-yellow-600">Aguardando dados</span>
                </div>
              </div>
              <div className="flex items-center justify-between">
                <span className="text-sm">Melhor vendedor</span>
                <span className="text-sm font-medium text-yellow-600">Aguardando dados</span>
              </div>
            </div>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="text-sm">Próximos Passos</CardTitle>
          </CardHeader>
          <CardContent>
            <ol className="list-decimal list-inside text-sm text-muted-foreground space-y-2">
              <li>Obter o link de compartilhamento da planilha</li>
              <li>Configurar credenciais Google Cloud</li>
              <li>Preencher variáveis de ambiente</li>
              <li>Testar extração de dados</li>
            </ol>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
