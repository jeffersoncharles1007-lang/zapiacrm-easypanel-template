import { createFileRoute } from "@tanstack/react-router";
import { useEffect, useState } from "react";
import { useServerFn } from "@tanstack/react-start";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { toast } from "sonner";
import { Loader2, Plus, X, Save } from "lucide-react";
import { brand } from "@/config/brand";
import { getSuperAdminEmails, setSuperAdminEmails } from "@/lib/master.functions";

export const Route = createFileRoute("/master/configuracoes")({
  head: () => ({ meta: [{ title: `${brand.name} — Master Config` }] }),
  component: ConfigPage,
});

function ConfigPage() {
  const get = useServerFn(getSuperAdminEmails);
  const set = useServerFn(setSuperAdminEmails);

  const [emails, setEmails] = useState<string[]>([]);
  const [novo, setNovo] = useState("");
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    void (async () => {
      try {
        const res = await get();
        if (!cancelled) {
          setEmails(res.emails ?? []);
        }
      } catch (e: any) {
        console.error("Erro getSuperAdminEmails:", e);
        if (!cancelled) {
          setError(e?.message ?? "Falha ao carregar emails");
          toast.error(`Emails: ${e?.message ?? "erro desconhecido"}`);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  function add(e: React.FormEvent) {
    e.preventDefault();
    const v = novo.trim().toLowerCase();
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(v)) return toast.error("Email inválido");
    if (emails.includes(v)) return toast.message("Já está na lista");
    setEmails([...emails, v]);
    setNovo("");
  }

  async function save() {
    setSaving(true);
    try {
      await set({ data: { emails } });
      toast.success("Salvo");
    } catch (e: any) {
      toast.error(e?.message);
    } finally {
      setSaving(false);
    }
  }

  return (
    <div className="space-y-6 max-w-3xl">
      <div>
        <h1 className="text-2xl font-bold tracking-tight">Configurações</h1>
        <p className="text-sm text-muted-foreground">Emails de super admin e variáveis de ambiente.</p>
      </div>

      {error && (
        <Card className="p-4 border-destructive/50 bg-destructive/5">
          <div className="text-sm text-destructive">
            ⚠️ Erro ao carregar dados: <strong>{error}</strong>
          </div>
          <p className="text-xs text-muted-foreground mt-2">
            Se persistir, verifique se a política de RLS permite leitura em <code>app_config</code>.
          </p>
        </Card>
      )}

      <Card className="p-5 space-y-4">
        <div>
          <h2 className="font-semibold">Emails de super admin</h2>
          <p className="text-xs text-muted-foreground mt-1">
            Cada email cadastrado aqui vira super admin automaticamente no próximo signup.
          </p>
        </div>

        <form onSubmit={add} className="flex gap-2">
          <Input
            placeholder="email@exemplo.com"
            value={novo}
            onChange={(e) => setNovo(e.target.value)}
          />
          <Button type="submit" variant="outline">
            <Plus className="size-4 mr-1" /> Adicionar
          </Button>
        </form>

        {loading ? (
          <div className="grid place-items-center py-6">
            <Loader2 className="animate-spin text-muted-foreground" />
          </div>
        ) : (
          <ul className="space-y-2">
            {emails.length === 0 && (
              <li className="text-sm text-muted-foreground">Nenhum email cadastrado.</li>
            )}
            {emails.map((em) => (
              <li
                key={em}
                className="flex items-center justify-between border rounded-md px-3 py-2"
              >
                <span className="text-sm">{em}</span>
                <button
                  onClick={() => setEmails(emails.filter((x) => x !== em))}
                  className="text-muted-foreground hover:text-destructive"
                  title="Remover"
                >
                  <X className="size-4" />
                </button>
              </li>
            ))}
          </ul>
        )}

        <div className="flex justify-end">
          <Button onClick={save} disabled={saving}>
            {saving ? (
              <Loader2 className="size-4 mr-1.5 animate-spin" />
            ) : (
              <Save className="size-4 mr-1.5" />
            )}
            Salvar
          </Button>
        </div>
      </Card>

      <Card className="p-5 space-y-3">
        <div>
          <h2 className="font-semibold">Variáveis de ambiente (Vercel)</h2>
          <p className="text-xs text-muted-foreground mt-1">
            Configure em <strong>Vercel → Settings → Environment Variables</strong>:
          </p>
          <ul className="mt-2 space-y-1 text-xs font-mono">
            <li>
              • <code className="text-primary">KIWIFY_WEBHOOK_TOKEN</code>
            </li>
            <li>
              • <code className="text-primary">CAKTO_WEBHOOK_TOKEN</code>
            </li>
            <li>
              • <code className="text-primary">PERFECTPAY_WEBHOOK_TOKEN</code>
            </li>
          </ul>
          <p className="text-[11px] text-muted-foreground mt-3">
            Os webhooks chegarão em <code>/api/public/billing/webhook?provider=xxx</code> e ativarão as empresas automaticamente.
          </p>
        </div>
      </Card>
    </div>
  );
}
