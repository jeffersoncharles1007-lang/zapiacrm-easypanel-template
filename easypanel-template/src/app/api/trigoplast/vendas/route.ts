import { NextResponse } from "next/server";
import { google } from "googleapis";

const SPREADSHEET_ID = process.env.TRIGOPLAST_SPREADSHEET_ID;
const SHEET_NAME = process.env.TRIGOPLAST_SHEET_NAME || "VENDAS";

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

async function getAuthClient() {
  const credentials = {
    type: "service_account",
    project_id: process.env.GOOGLE_PROJECT_ID,
    private_key: process.env.GOOGLE_PRIVATE_KEY?.replace(/\\n/g, "\n"),
    client_email: process.env.GOOGLE_CLIENT_EMAIL,
  };

  const auth = new google.auth.GoogleAuth({
    credentials,
    scopes: ["https://www.googleapis.com/auth/spreadsheets.readonly"],
  });

  return auth;
}

async function getSpreadsheetValues(): Promise<{ values: string[][] }> {
  if (!SPREADSHEET_ID) {
    throw new Error("TRIGOPLAST_SPREADSHEET_ID não configurado");
  }

  const auth = await getAuthClient();
  const sheets = google.sheets({ version: "v4", auth });

  const response = await sheets.spreadsheets.values.get({
    spreadsheetId: SPREADSHEET_ID,
    range: SHEET_NAME,
    valueRenderOption: "UNFORMATTED_VALUE",
  });

  return { values: response.data.values || [] };
}

function parseVendasData(values: string[][]): VendaDiaria[] {
  const vendas: VendaDiaria[] = [];
  const diasSemana = ["", "Dom", "Seg", "Ter", "Qua", "Qui", "Sex", "Sáb"];

  for (let i = 1; i < values.length; i++) {
    const row = values[i];
    if (row.length < 9) continue;

    const dataRaw = row[0];
    let data = String(dataRaw);
    let diaSemana = "";

    if (typeof dataRaw === "number") {
      const date = new Date((dataRaw - 25569) * 86400 * 1000);
      data = date.toLocaleDateString("pt-BR");
      diaSemana = diasSemana[date.getDay()];
    } else if (typeof dataRaw === "string") {
      const parsed = new Date(dataRaw);
      if (!isNaN(parsed.getTime())) {
        data = parsed.toLocaleDateString("pt-BR");
        diaSemana = diasSemana[parsed.getDay()];
      }
    }

    vendas.push({
      data,
      diaSemana,
      meta: Math.round(Number(row[1]) * 100),
      marina: Math.round(Number(row[2]) * 100),
      luciana: Math.round(Number(row[3]) * 100),
      renata: Math.round(Number(row[4]) * 100),
      rodrigues: Math.round(Number(row[5]) * 100),
      representantes: Math.round(Number(row[6]) * 100),
      real: Math.round(Number(row[7]) * 100),
      semana: Math.round(Number(row[8])),
    });
  }

  return vendas;
}

function calcularRanking(vendas: VendaDiaria[]): ResumoVendedor[] {
  const totais: Record<string, number> = {
    "Marina": 0,
    "Luciana": 0,
    "Renata/TF": 0,
    "Rodriguez": 0,
    "Representantes": 0,
  };

  vendas.forEach((v) => {
    totais["Marina"] += v.marina;
    totais["Luciana"] += v.luciana;
    totais["Renata/TF"] += v.renata;
    totais["Rodriguez"] += v.rodrigues;
    totais["Representantes"] += v.representantes;
  });

  const metas: Record<string, number> = {
    "Marina": 2000000,
    "Luciana": 1500000,
    "Renata/TF": 1500000,
    "Rodriguez": 2000000,
    "Representantes": 1000000,
  };

  const ranking: ResumoVendedor[] = Object.entries(totais).map(([nome, totalVendido]) => ({
    nome,
    totalVendido,
    metaMensal: metas[nome] || 1000000,
    percentualMeta: ((totalVendido / (metas[nome] || 1000000)) * 100),
  }));

  return ranking.sort((a, b) => b.totalVendido - a.totalVendido);
}

function calcularDashboard(vendas: VendaDiaria[]): DashboardData {
  const ultimos14 = vendas.slice(-14);
  const totalReal = ultimos14.reduce((acc, v) => acc + v.real, 0);
  const totalMeta = ultimos14.reduce((acc, v) => acc + v.meta, 0);
  const realizadoMeta = totalMeta > 0 ? (totalReal / totalMeta) * 100 : 0;

  const melhorDia = ultimos14.reduce(
    (best, v) => (v.real > (best?.valor || 0) ? { data: v.data, valor: v.real } : best),
    { data: "-", valor: 0 }
  );

  const ultimos7 = ultimos14.slice(-7);
  const anteriores7 = ultimos14.slice(-14, -7);
  const somaUltimos7 = ultimos7.reduce((acc, v) => acc + v.real, 0);
  const somaAnteriores7 = anteriores7.reduce((acc, v) => acc + v.real, 0);

  let tendencia: "subindo" | "estavel" | "descendo" = "estavel";
  if (somaUltimos7 > somaAnteriores7 * 1.05) {
    tendencia = "subindo";
  } else if (somaUltimos7 < somaAnteriores7 * 0.95) {
    tendencia = "descendo";
  }

  return {
    vendasDiarias: ultimos14,
    totalReal,
    totalMeta,
    realizadoMeta,
    rankingVendedores: calcularRanking(vendas),
    melhorDia,
    tendencia,
  };
}

export async function GET(request: Request) {
  try {
    const { searchParams } = new URL(request.url);
    const resource = searchParams.get("resource");

    const values = await getSpreadsheetValues();
    const vendas = parseVendasData(values.values);

    switch (resource) {
      case "vendas":
        return NextResponse.json({ success: true, data: vendas });

      case "ranking":
        return NextResponse.json({ success: true, data: calcularRanking(vendas) });

      case "dashboard":
      default:
        return NextResponse.json({ success: true, data: calcularDashboard(vendas) });
    }
  } catch (error) {
    console.error("[Trigoplast API Error]", error);
    return NextResponse.json(
      { success: false, error: error instanceof Error ? error.message : "Erro interno" },
      { status: 500 }
    );
  }
}
