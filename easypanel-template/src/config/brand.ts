// Branding centralizado. Troque aqui pra renomear/recolorir o app inteiro.
export const brand = {
  name: "ZAPIACRM",                                // Nome da marca
  tagline: "Sua IA atende o WhatsApp 24h",            // Tagline principal
  headline: "ZAPIACRM — CRM + WhatsApp + IA",         // Headline do navegador
  description:
    "ZAPIACRM: CRM com WhatsApp integrado e IA para automação de vendas.",  // Meta description
  twitterHandle: "@zapiacrm",
  primary: "#22C55E",                                // Verde WhatsApp
  primaryOklch: "0.72 0.18 152",
  logoIcon: "MessageSquareText",                       // Ícone
};

// Exportações auxiliares esperadas por alguns componentes
export const brandTitle = brand.name;
export const brandHeadline = brand.headline;

// Helper: retorna um ícone padrão (usado em componentes que não tem getLogoUrl)
export function getLogoUrl(): string {
  return ""; // Sem logo por enquanto, retorna vazio (componentes fazem fallback pro ícone)
}

// WhatsApp de suporte - mude para o seu número
export const supportWhatsapp = "5562994101731";
export const supportWhatsappUrl = `https://wa.me/${supportWhatsapp}`;
export const supportWhatsappDisplay = "(62) 99410-1731";
