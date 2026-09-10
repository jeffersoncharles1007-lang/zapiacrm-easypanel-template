// ZAPIACRM — Email sender (SMTP Titan)
//
// Wrapper simples sobre nodemailer para envio de emails transacionais.
// Usa as env vars SMTP_HOST / SMTP_PORT / SMTP_USER / SMTP_PASS / SMTP_SENDER_EMAIL / SMTP_SENDER_NAME.
//
// Por que .server.ts? Para garantir que NAO vai pro bundle do client.

import nodemailer from "nodemailer";

let cachedTransporter: ReturnType<typeof nodemailer.createTransport> | null = null;

function getTransporter() {
  if (cachedTransporter) return cachedTransporter;

  const host = process.env.SMTP_HOST;
  const port = Number(process.env.SMTP_PORT ?? 465);
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;

  if (!host || !user || !pass) {
    return null;
  }

  cachedTransporter = nodemailer.createTransport({
    host,
    port,
    secure: port === 465, // SSL direto para 465, STARTTLS para 587
    auth: { user, pass },
  });

  return cachedTransporter;
}

export type SendEmailInput = {
  to: string;
  subject: string;
  html: string;
  text?: string;
};

export async function sendEmail({
  to,
  subject,
  html,
  text,
}: SendEmailInput): Promise<{ ok: true } | { ok: false; error: string }> {
  const transporter = getTransporter();
  if (!transporter) {
    return { ok: false, error: "smtp_not_configured" };
  }

  const from = `"${process.env.SMTP_SENDER_NAME ?? "ZAPIACRM"}" <${process.env.SMTP_SENDER_EMAIL ?? process.env.SMTP_USER}>`;

  try {
    await transporter.sendMail({
      from,
      to,
      subject,
      html,
      text: text ?? html.replace(/<[^>]+>/g, ""), // fallback texto = HTML sem tags
    });
    return { ok: true };
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    console.error("[email] send failed:", to, message);
    return { ok: false, error: message };
  }
}

// Template: Email de boas-vindas (trial gratuito)
export function welcomeTrialEmail(params: {
  nome: string;
  trialAte: string; // ISO date
  appUrl: string;
}): { subject: string; html: string; text: string } {
  const { nome, trialAte, appUrl } = params;
  const dataFmt = new Date(trialAte).toLocaleDateString("pt-BR", {
    day: "2-digit",
    month: "long",
    year: "numeric",
  });
  const primeiroNome = nome.split(" ")[0] || "Cliente";
  const subject = `Bem-vindo ao ZAPIACRM, ${primeiroNome}! Seus 3 dias grátis estão ativos`;

  const html = `
<!DOCTYPE html>
<html lang="pt-BR">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="margin:0;padding:0;background:#0a0a0a;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;color:#fff;">
  <div style="max-width:600px;margin:0 auto;padding:32px 24px;">
    <!-- Logo -->
    <div style="text-align:center;margin-bottom:32px;">
      <div style="display:inline-block;width:56px;height:56px;background:linear-gradient(135deg,#22C55E,#16A34A);border-radius:16px;text-align:center;line-height:56px;font-size:24px;font-weight:900;color:#fff;">Z</div>
      <h1 style="margin:16px 0 0;font-size:24px;font-weight:800;color:#fff;">ZAPIACRM</h1>
    </div>

    <!-- Saudacao -->
    <h2 style="font-size:28px;font-weight:800;margin:0 0 16px;line-height:1.2;">
      Oi, ${primeiroNome}! 👋
    </h2>
    <p style="font-size:16px;line-height:1.6;color:#d4d4d4;margin:0 0 24px;">
      Sua conta foi criada com sucesso. Você tem <strong style="color:#22C55E;">3 dias grátis</strong> para experimentar tudo.
    </p>

    <!-- Trial Banner -->
    <div style="background:linear-gradient(135deg,#dc2626,#ef4444);border-radius:12px;padding:20px;margin-bottom:24px;text-align:center;">
      <div style="font-size:13px;text-transform:uppercase;letter-spacing:0.14em;font-weight:700;opacity:0.9;margin-bottom:4px;">Período de teste</div>
      <div style="font-size:18px;font-weight:800;">Seus 3 dias grátis vão até <strong>${dataFmt}</strong></div>
    </div>

    <!-- Proximos passos -->
    <h3 style="font-size:18px;font-weight:700;margin:32px 0 16px;">Próximos passos:</h3>
    <ol style="margin:0;padding:0 0 0 20px;color:#d4d4d4;font-size:15px;line-height:1.8;">
      <li>Conecte seu WhatsApp (escaneie o QR code no app)</li>
      <li>Personalize a marca em <strong>Configurações → Marca</strong></li>
      <li>Configure o agente IA com o briefing do seu negócio</li>
      <li>Importe seus contatos ou cadastre leads manualmente</li>
    </ol>

    <!-- CTA -->
    <div style="text-align:center;margin:32px 0;">
      <a href="${appUrl}/app/dashboard" style="display:inline-block;background:#22C55E;color:#fff;text-decoration:none;padding:14px 32px;border-radius:10px;font-weight:700;font-size:16px;">
        Acessar meu painel
      </a>
    </div>

    <!-- Footer -->
    <div style="border-top:1px solid #333;padding-top:24px;margin-top:32px;text-align:center;font-size:12px;color:#888;">
      <p style="margin:0 0 8px;">Dúvidas? Responda este email ou fale com nosso suporte.</p>
      <p style="margin:0;color:#666;">© ${new Date().getFullYear()} ZAPIACRM. Todos os direitos reservados.</p>
    </div>
  </div>
</body>
</html>`.trim();

  const text = `
Oi, ${primeiroNome}!

Sua conta ZAPIACRM foi criada. Você tem 3 dias grátis para experimentar tudo.

Período de teste: até ${dataFmt}

Próximos passos:
1. Conecte seu WhatsApp (escaneie o QR code no app)
2. Personalize a marca em Configurações → Marca
3. Configure o agente IA com o briefing do seu negócio
4. Importe seus contatos ou cadastre leads manualmente

Acesse seu painel: ${appUrl}/app/dashboard

Dúvidas? Responda este email ou fale com nosso suporte.

© ${new Date().getFullYear()} ZAPIACRM.
`.trim();

  return { subject, html, text };
}
