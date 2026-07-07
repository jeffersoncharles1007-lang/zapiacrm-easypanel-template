import { createFileRoute } from "@tanstack/react-router";

export const Route = createFileRoute("/app/trigoplast")({
  head: () => ({ meta: [{ title: "Trigoplast — CRM" }] }),
  component: TrigoplastIndex,
});

function TrigoplastIndex() {
  return (
    <div className="p-6">
      <h1 className="text-2xl font-bold mb-4">Trigoplast CRM</h1>
      <p className="text-muted-foreground">
        Carregando...
      </p>
    </div>
  );
}
