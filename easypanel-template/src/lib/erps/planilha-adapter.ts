/**
 * Adapter de Planilha — Trigoplast
 *
 * Lê dados da planilha Google Sheets "vendas diaria" e expõe como API interna.
 *
 * Planilha: https://docs.google.com/spreadsheets/d/1kuJF1Fd2eAgL6vkKVMEIDjAv71tQOzudPE1mw1nvxz0
 *
 * Estrutura real (verificado):
 *   Col A = data        | Data (1-jan., 2-jan., ...)
 *   Col B = dia_semana  | Dia da semana (quinta, sexta, sabado...)
 *   Col C = meta        | Meta diária (R$ 30.000)
 *   Col D = MARINA      | Vendas MARINA
 *   Col E = LUCIANA     | Vendas LUCIANA
 *   Col F = RENATA/TF   | Vendas RENATA (Televendas)
 *   Col G = RODRIGUES   | Vendas RODRIGUES
 *   Col H = REPRESENTANTES | Total representantes
 *   Col I = REAL        | Total real do dia
 *   Col J = SEMANA      | Acumulado semanal
 */

import Papa from "papaparse";

// ─── Configuração ────────────────────────────────────────────────────────────

export const TRIGOPLAST_SPREADSHEET_ID = "1kuJF1Fd2eAgL6vkKVMEIDjAv71tQOzudPE1mw1nvxz0";
export const TRIGOPLAST_SHEET_NAME = "vendas diaria";
export const TRIGOPLAST_CSV_URL = `https://docs.google.com/spreadsheets/d/${TRIGOPLAST_SPREADSHEET_ID}/export?format=csv&gid=0`;

// Colunas (índice 0-based no array de campos)
export const COLUNAS = {
  DATA:          0,  // Coluna A - Data (1-jan., 2-jan.)
  DIA_SEMANA:    1,  // Coluna B - Dia da semana
  META:          2,  // Coluna C - Meta
  MARINA:        3,  // Coluna D - MARINA
  LUCIANA:       4,  // Coluna E - LUCIANA
  RENATA:        5,  // Coluna F - RENATA/TF
  RODRIGUES:     6,  // Coluna G - RODRIGUES
  REPRESENTANTES: 7,  // Coluna H - Total representantes
  REAL:          8,  // Coluna I - Total real do dia
  SEMANA:        9,  // Coluna J - Acumulado semanal
} as const;

// Vendedores mapeados (índice da coluna no CSV)
export const VENDEDORES = [
  { key: "MARINA",   nome: "MARINA",   coluna: COLUNAS.MARINA,   ghlUserId: "" },
  { key: "LUCIANA",  nome: "LUCIANA",  coluna: COLUNAS.LUCIANA,  ghlUserId: "" },
  { key: "RENATA",   nome: "RENATA/TF", coluna: COLUNAS.RENATA,  ghlUserId: "" },
  { key: "RODRIGUES", nome: "RODRIGUES", coluna: COLUNAS.RODRIGUES, ghlUserId: "" },
] as const;

// Linha onde começam os dados (1-based, após headers)
const DATA_START_ROW = 4;

// ─── Tipos ──────────────────────────────────────────────────────────────────

export interface VendaDiaria {
  data: string;           // "1-jan.", "2-jan."
  diaSemana: string;      // "quinta", "sexta", etc.
  dataISO?: string;      // "2025-01-01" (parseado)
  meta: number;          // Meta do dia em centavos (R$ 3000000 = R$ 30.000,00)
  marina: number;        // Vendas Marina em centavos
  luciana: number;       // Vendas Luciana em centavos
  renata: number;        // Vendas Renata em centavos
  rodrigues: number;     // Vendas Rodrigues em centavos
  representantes: number;  // Total representantes
  real: number;          // Total real do dia em centavos
  semana: number;        // Acumulado semanal em centavos
}

export interface ResumoVendedor {
  nome: string;
  totalVendido: number;     // Em centavos
  metaMensal: number;       // Em centavos
  percentualMeta: number;   // 0-100
}

export interface DashboardData {
  vendasDiarias: VendaDiaria[];
  totalReal: number;        // Total do período em centavos
  totalMeta: number;        // Meta total do período em centavos
  realizadoMeta: number;     // Percentual realizado (0-100)
  rankingVendedores: ResumoVendedor[];
  melhorDia: { data: string; valor: number };
  tendencia: "subindo" | "estavel" | "descendo";
}

// ─── Utilitários ────────────────────────────────────────────────────────────

/**
 * Converte string de valor brasileiro (R$ 30.000,00) para centavos (number)
 * Entrada: "R$ 30.000,00" ou "9.339,20" ou "30.000" ou "−" (travessão = zero)
 * Saída: 3000000 (centavos)
 */
export function parseCurrency(valor: string): number {
  if (!valor || valor === "−" || valor === "-" || valor.trim() === "") {
    return 0;
  }

  // Remove R$, espaços e separadores de milhar (ponto), troca decimal (vírgula) para ponto
  const limpo = valor
    .replace(/R\$\s*/g, "")
    .replace(/\./g, "")
    .replace(",", ".")
    .trim();

  const num = parseFloat(limpo);
  if (isNaN(num)) return 0;

  // Converte para centavos (multiplica por 100)
  return Math.round(num * 100);
}

/**
 * Converte "5-jan", "9-jan", "12-fev" para data ISO (YYYY-MM-DD)
 * Assume ano de 2025 para este caso
 */
export function parseDataBr(dataBr: string, ano = 2025): string {
  if (!dataBr) return "";

  const meses: Record<string, string> = {
    "jan": "01", "fev": "02", "mar": "03", "abr": "04",
    "mai": "05", "jun": "06", "jul": "07", "ago": "08",
    "set": "09", "out": "10", "nov": "11", "dez": "12"
  };

  // "5-jan" -> ["5", "jan"]
  const match = dataBr.match(/^(\d+)-(\w+)$/);
  if (!match) return "";

  const [, dia, mes] = match;
  const mesNum = meses[mes.toLowerCase()] || "01";
  const diaFormatado = dia.padStart(2, "0");

  return `${ano}-${mesNum}-${diaFormatado}`;
}

/**
 * Formata centavos para exibição em reais
 */
export function formatCurrency(centavos: number): string {
  return new Intl.NumberFormat("pt-BR", {
    style: "currency",
    currency: "BRL",
  }).format(centavos / 100);
}

// ─── Fetch da planilha ──────────────────────────────────────────────────────

/**
 * Busca dados da planilha via CSV export do Google Sheets
 */
export async function fetchPlanilhaData(): Promise<VendaDiaria[]> {
  const response = await fetch(TRIGOPLAST_CSV_URL);

  if (!response.ok) {
    throw new Error(`Falha ao buscar planilha: ${response.status} ${response.statusText}`);
  }

  const csvText = await response.text();

  return new Promise((resolve, reject) => {
    Papa.parse(csvText, {
      skipEmptyLines: true,
      complete: (results) => {
        const linhas = results.data as string[][];
        const vendas: VendaDiaria[] = [];

        // Começa a partir da linha DATA_START_ROW (índice = DATA_START_ROW - 1)
        for (let i = DATA_START_ROW - 1; i < linhas.length; i++) {
          const row = linhas[i];

          // Verifica se a linha tem dados suficientes
          if (!row || row.length < 8) continue;

          // Pula linhas de totais/resumo (não têm data válida)
          const dataCelula = row[0] || "";
          if (!dataCelula.match(/^\d+-\w+$/)) continue;

          const venda: VendaDiaria = {
            data: dataCelula,
            diaSemana: row[COLUNAS.DIA_SEMANA] || "",
            dataISO: parseDataBr(dataCelula),
            meta: parseCurrency(row[COLUNAS.META] || "0"),
            marina: parseCurrency(row[COLUNAS.MARINA] || "0"),
            luciana: parseCurrency(row[COLUNAS.LUCIANA] || "0"),
            renata: parseCurrency(row[COLUNAS.RENATA] || "0"),
            rodrigues: parseCurrency(row[COLUNAS.RODRIGUES] || "0"),
            representantes: parseCurrency(row[COLUNAS.REPRESENTANTES] || "0"),
            real: parseCurrency(row[COLUNAS.REAL] || "0"),
            semana: parseCurrency(row[COLUNAS.SEMANA] || "0"),
          };

          vendas.push(venda);
        }

        resolve(vendas);
      },
      error: (error: Error) => {
        reject(new Error(`Erro ao parsear CSV: ${error.message}`));
      },
    });
  });
}

// ─── Cálculos de Dashboard ──────────────────────────────────────────────────

/**
 * Calcula métricas de resumo para um vendedor específico
 */
export function calcularResumoVendedor(
  vendas: VendaDiaria[],
  nome: string,
  key: "MARINA" | "LUCIANA" | "RENATA" | "RODRIGUES",
  metaMensal: number
): ResumoVendedor {
  const totalVendido = vendas.reduce((acc, v) => {
    const valores: Record<string, number> = {
      MARINA: v.marina,
      LUCIANA: v.luciana,
      RENATA: v.renata,
      RODRIGUES: v.rodrigues,
    };
    return acc + (valores[key] || 0);
  }, 0);

  return {
    nome,
    totalVendido,
    metaMensal,
    percentualMeta: metaMensal > 0 ? Math.round((totalVendido / metaMensal) * 100 * 100) / 100 : 0,
  };
}

/**
 * Obtém dados agregados para o dashboard
 */
export async function getDashboardData(): Promise<DashboardData> {
  const vendas = await fetchPlanilhaData();

  if (vendas.length === 0) {
    return {
      vendasDiarias: [],
      totalReal: 0,
      totalMeta: 0,
      realizadoMeta: 0,
      rankingVendedores: [],
      melhorDia: { data: "", valor: 0 },
      tendencia: "estavel",
    };
  }

  // Totais gerais
  const totalReal = vendas.reduce((acc, v) => acc + v.real, 0);
  const totalMeta = vendas.reduce((acc, v) => acc + v.meta, 0);
  const realizadoMeta = totalMeta > 0 ? (totalReal / totalMeta) * 100 : 0;

  // Ranking de vendedores (metas aproximadas)
  const rankingVendedores: ResumoVendedor[] = [
    calcularResumoVendedor(vendas, "MARINA", "MARINA", 42500000),      // R$ 425.000,00
    calcularResumoVendedor(vendas, "LUCIANA", "LUCIANA", 5000000),    // R$ 50.000,00
    calcularResumoVendedor(vendas, "RENATA/TF", "RENATA", 0),         // A definir
    calcularResumoVendedor(vendas, "RODRIGUES", "RODRIGUES", 0),    // A definir
  ].sort((a, b) => b.totalVendido - a.totalVendido);

  // Melhor dia
  const melhorDiaVenda = vendas.reduce(
    (acc, v) => (v.real > acc.valor ? { data: v.data, valor: v.real } : acc),
    { data: "", valor: 0 }
  );

  // Tendência (últimos 7 dias vs 7 dias anteriores)
  const ultimos7 = vendas.slice(-7);
  const anteriores7 = vendas.slice(-14, -7);
  const sum7 = ultimos7.reduce((acc, v) => acc + v.real, 0);
  const sumAnt = anteriores7.reduce((acc, v) => acc + v.real, 0);

  let tendencia: "subindo" | "estavel" | "descendo" = "estavel";
  if (sum7 > sumAnt * 1.1) tendencia = "subindo";
  else if (sum7 < sumAnt * 0.9) tendencia = "descendo";

  return {
    vendasDiarias: vendas,
    totalReal,
    totalMeta,
    realizadoMeta: Math.round(realizadoMeta * 100) / 100,
    rankingVendedores,
    melhorDia: melhorDiaVenda,
    tendencia,
  };
}

/**
 * Obtém vendas do dia atual ou mais recente
 */
export async function getVendasRecentes(dias = 7): Promise<VendaDiaria[]> {
  const vendas = await fetchPlanilhaData();
  return vendas.slice(-dias);
}

/**
 * Obtém ranking de vendedores ordenado por performance
 */
export async function getRankingVendedores(): Promise<ResumoVendedor[]> {
  const data = await getDashboardData();
  return data.rankingVendedores;
}

// ─── Exportação default ─────────────────────────────────────────────────────

export default {
  fetchPlanilhaData,
  getDashboardData,
  getVendasRecentes,
  getRankingVendedores,
  TRIGOPLAST_SPREADSHEET_ID,
  TRIGOPLAST_SHEET_NAME,
  VENDEDORES,
  parseCurrency,
  formatCurrency,
};
