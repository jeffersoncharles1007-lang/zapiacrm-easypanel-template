// =============================================================================
// ZAPIACRM - Build para Vercel
//
// 1) Mapeia as variaveis que a integracao Vercel<->Supabase cria
//    (SUPABASE_URL, SUPABASE_ANON_KEY, ...) para os nomes que o app espera,
//    incluindo os VITE_* que precisam existir em BUILD TIME (o Vite injeta
//    qualquer process.env.VITE_* no bundle do cliente).
// 2) Roda as migrations no banco do Supabase do cliente.
// 3) Executa o build do Nitro com o preset "vercel".
// =============================================================================

import { spawnSync } from "node:child_process";

const env = { ...process.env };

// --- 1. Mapeamento de variaveis -------------------------------------------
// A integracao Supabase pode expor a anon key com nomes diferentes.
const anonKey =
  env.SUPABASE_PUBLISHABLE_KEY ||
  env.SUPABASE_ANON_KEY ||
  env.NEXT_PUBLIC_SUPABASE_ANON_KEY ||
  "";

const supabaseUrl = env.SUPABASE_URL || env.NEXT_PUBLIC_SUPABASE_URL || "";

// Deriva o project ref do host (https://<ref>.supabase.co)
let projectId = env.SUPABASE_PROJECT_ID || "";
if (!projectId && supabaseUrl) {
  try {
    projectId = new URL(supabaseUrl).hostname.split(".")[0];
  } catch {
    /* ignora */
  }
}

function setIfEmpty(key, value) {
  if (value && !env[key]) env[key] = value;
}

// Nomes server-side esperados pelo app
setIfEmpty("SUPABASE_URL", supabaseUrl);
setIfEmpty("SUPABASE_PUBLISHABLE_KEY", anonKey);
setIfEmpty("SUPABASE_PROJECT_ID", projectId);

// Nomes VITE_* (build-time, vao para o bundle do cliente)
setIfEmpty("VITE_SUPABASE_URL", supabaseUrl);
setIfEmpty("VITE_SUPABASE_PUBLISHABLE_KEY", anonKey);
setIfEmpty("VITE_SUPABASE_PROJECT_ID", projectId);
setIfEmpty("VITE_GOOGLE_CLIENT_ID", env.GOOGLE_CLIENT_ID);
setIfEmpty("VITE_GOOGLE_API_KEY", env.GOOGLE_API_KEY);
setIfEmpty("VITE_EVOLUTION_API_URL", env.EVOLUTION_API_URL);

// Preset do Nitro para deploy no Vercel
env.NITRO_PRESET = env.NITRO_PRESET || "vercel";

function run(cmd, args) {
  const res = spawnSync(cmd, args, { stdio: "inherit", env, shell: true });
  if (res.status !== 0) process.exit(res.status ?? 1);
}

// --- 2. Migrations --------------------------------------------------------
console.log("[vercel-build] Rodando migrations...");
run("node", ["scripts/migrate.mjs"]);

// --- 3. Build -------------------------------------------------------------
console.log(`[vercel-build] Build (NITRO_PRESET=${env.NITRO_PRESET})...`);
run("npx", ["vite", "build"]);

console.log("[vercel-build] Concluido.");
