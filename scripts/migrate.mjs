// =============================================================================
// ZAPIACRM - Runner de migrations (Supabase / Postgres)
//
// Aplica todos os arquivos SQL de supabase/migrations/ em ordem, de forma
// IDEMPOTENTE: cada migration aplicada com sucesso fica registrada na tabela
// zapiacrm_migrations e nao roda de novo.
//
// Usado no build do Vercel (scripts/vercel-build.mjs) contra o banco do
// projeto Supabase do cliente. Tambem pode rodar sozinho:  node scripts/migrate.mjs
//
// Conexao: usa POSTGRES_URL_NON_POOLING (setada pela integracao Vercel<->Supabase)
// e cai para DATABASE_URL / POSTGRES_URL se preciso. Conexao direta (nao pooled)
// e obrigatoria para DDL.
// =============================================================================

import { readFileSync, readdirSync, existsSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join, resolve } from "node:path";
import pg from "pg";

const __dirname = dirname(fileURLToPath(import.meta.url));
const MIGRATIONS_DIR = resolve(__dirname, "..", "supabase", "migrations");

function getConnectionString() {
  const url =
    process.env.POSTGRES_URL_NON_POOLING ||
    process.env.DATABASE_URL ||
    process.env.POSTGRES_URL ||
    process.env.SUPABASE_DB_URL;
  return url;
}

async function main() {
  const connectionString = getConnectionString();

  if (!connectionString) {
    console.warn(
      "[migrate] Nenhuma connection string encontrada " +
        "(POSTGRES_URL_NON_POOLING / DATABASE_URL). Pulando migrations.",
    );
    // Em preview/CI sem banco, nao quebra o build.
    process.exit(0);
  }

  if (!existsSync(MIGRATIONS_DIR)) {
    console.warn(`[migrate] Pasta nao encontrada: ${MIGRATIONS_DIR}. Nada a fazer.`);
    process.exit(0);
  }

  const files = readdirSync(MIGRATIONS_DIR)
    .filter((f) => f.endsWith(".sql"))
    .sort(); // ordem lexicografica = ordem cronologica (prefixo timestamp)

  if (files.length === 0) {
    console.log("[migrate] Nenhuma migration para aplicar.");
    process.exit(0);
  }

  // O Postgres do Supabase apresenta um certificado self-signed no chain e a
  // connection string vem com sslmode=require (tratado como verify-full pelo pg),
  // o que sobrepoe o ssl object abaixo. Como este runner roda APENAS no build
  // (nunca em runtime de request), desabilitamos a verificacao de cert TLS para
  // conseguir aplicar as migrations. Nao afeta a seguranca do app em producao.
  process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

  const client = new pg.Client({
    connectionString,
    ssl: { rejectUnauthorized: false },
    // migrations grandes podem demorar
    statement_timeout: 120_000,
  });

  await client.connect();
  console.log(`[migrate] Conectado. ${files.length} migration(s) candidata(s).`);

  await client.query(`
    CREATE TABLE IF NOT EXISTS public.zapiacrm_migrations (
      name        text PRIMARY KEY,
      applied_at  timestamptz NOT NULL DEFAULT now()
    );
  `);

  const appliedRes = await client.query(
    "SELECT name FROM public.zapiacrm_migrations",
  );
  const applied = new Set(appliedRes.rows.map((r) => r.name));

  let count = 0;
  for (const file of files) {
    if (applied.has(file)) continue;

    const sql = readFileSync(join(MIGRATIONS_DIR, file), "utf8");
    console.log(`[migrate] Aplicando: ${file}`);

    try {
      await client.query("BEGIN");
      await client.query(sql);
      await client.query(
        "INSERT INTO public.zapiacrm_migrations (name) VALUES ($1)",
        [file],
      );
      await client.query("COMMIT");
      count++;
    } catch (err) {
      await client.query("ROLLBACK").catch(() => {});
      console.error(`[migrate] FALHOU em ${file}:`, err.message);
      await client.end().catch(() => {});
      process.exit(1);
    }
  }

  await client.end();
  console.log(
    count === 0
      ? "[migrate] Banco ja estava atualizado. Nada aplicado."
      : `[migrate] OK. ${count} migration(s) aplicada(s).`,
  );
}

main().catch((err) => {
  console.error("[migrate] Erro inesperado:", err);
  process.exit(1);
});
