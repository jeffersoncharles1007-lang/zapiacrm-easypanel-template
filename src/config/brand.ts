// Branding centralizado. Troque aqui pra renomear/recolorir o app inteiro.
export const brand = {
  name: "ZAPIACRM",
  tagline: "IA que atende seu WhatsApp 24/7 + CRM Kanban",
  // Usados em <title>, meta tags e redes sociais (SEO/compartilhamento)
  headline: "Atendente de WhatsApp com IA + CRM Kanban",
  description:
    "Conecte o WhatsApp, deixe a IA atender e organize seus leads em um kanban arrastável.",
  twitterHandle: "@ZAPIACRM",
  // Cor primaria da marca (WhatsApp green). Fonte unica: injetada como
  // CSS var --brand na raiz (__root.tsx) e usada tambem nos graficos.
  // Troque AQUI para recolorir o app inteiro.
  primary: "#16A34A",
  primaryOklch: "0.72 0.18 152",
  // Logo: WhatsApp icon (via lucide-react "MessageCircle" com cor WhatsApp)
  logoIcon: "MessageCircle",
};

// Titulo completo reutilizavel (aba do navegador, og:title, twitter:title)
export const brandTitle = `${brand.name} — ${brand.headline}`;

// Suporte fixo — usado em rodapé, telas de erro e mensagens de falha.
// Editar aqui troca em todos os pontos.
export const supportWhatsapp = "5562994101731";
export const supportWhatsappUrl = `https://wa.me/${supportWhatsapp}`;
export const supportWhatsappDisplay = "(62) 99410-1731";
