# 🚀 ZAPIACRM - CRM + WhatsApp + IA

**Instale em 2 minutos com 1 comando!**

Sistema CRM completo com WhatsApp integrado e inteligência artificial para automação de vendas. Ideal para agências que revendem para clientes finais.

---

## ⚡ Instalação Rápida (2 minutos)

### 1️⃣ SSH na VPS

```bash
ssh root@IP-DA-SUA-VPS
```

### 2️⃣ Cole este comando:

```bash
curl -fsSL https://raw.githubusercontent.com/jeffersoncharles1007-lang/zapiacrm-easypanel-template/main/install-minimal.sh | bash
```

### 3️⃣ Aguarde ~2 minutos

O sistema vai:
- Instalar Docker (se necessário)
- Baixar imagem do Docker Hub
- Subir todos os serviços
- Configurar banco de dados

### 4️⃣ Acesse!

```
http://localhost:4000
```

---

## 🎯 O que está Included

| Componente | Descrição |
|------------|-----------|
| **CRM Kanban** | Cards, estágios, automações |
| **WhatsApp** | Conexão via Evolution API |
| **IA** | Gemini, GPT-4, Claude |
| **Multi-tenant** | Várias empresas por instalação |
| **Pagamentos** | Stripe integrado |

---

## 📋 Comandos Úteis

```bash
# Ver logs em tempo real
cd /opt/zapiacrm && docker compose logs -f

# Reiniciar
cd /opt/zapiacrm && docker compose restart

# Parar
cd /opt/zapiacrm && docker compose down

# Ver status
cd /opt/zapiacrm && docker compose ps

# Atualizar (recomendado)
cd /opt/zapiacrm && docker compose pull && docker compose up -d
```

---

## 🔧 Solução de Problemas

### "Port 4000 already in use"
```bash
docker ps  # veja qual container usa a porta
docker stop NOME-DO-CONTAINER
cd /opt/zapiacrm && docker compose up -d
```

### "Não consigo acessar"
```bash
# Libere a porta no firewall
ufw allow 4000/tcp
# ou
iptables -I INPUT -p tcp --dport 4000 -j ACCEPT
```

### Ver logs de erro
```bash
cd /opt/zapiacrm && docker compose logs --tail=100
```

### Reiniciar do zero
```bash
cd /opt/zapiacrm
docker compose down -v    # ⚠️ apaga dados
docker compose up -d      # reinstala
```

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────┐
│           VPS do Cliente            │
│                                     │
│  ┌─────────────────────────────┐   │
│  │     postgres:15-alpine     │   │
│  │     (banco de dados)       │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │     zapiacrm-app           │   │
│  │     (app TanStack)         │   │
│  │     porta: 4000            │   │
│  └─────────────────────────────┘   │
│                                     │
│  ◄── Evolution API centralizada    │
│      (WhatsApp)                     │
└─────────────────────────────────────┘
```

---

## 📊 Requisitos

| Recurso | Mínimo | Recomendado |
|---------|--------|-------------|
| RAM | 1 GB | 2 GB |
| CPU | 1 core | 2 cores |
| Disco | 10 GB | 20 GB |
| Ubuntu | 22.04+ | 22.04 LTS |

---

## 🔒 Segurança

- Banco de dados com senha única por instalação
- Variables de ambiente, sem secrets no código
- RLS (Row Level Security) habilitado
- HTTPS recomendado (configure no reverse proxy)

---

## 📞 Suporte

- **GitHub Issues:** https://github.com/jeffersoncharles1007-lang/zapiacrm-easypanel-template/issues
- **Email:** suporte@zapiacrm.com.br

---

## 📄 Licença

Copyright © 2024 ZAPIACRM. Todos os direitos reservados.

---

**Tempo de instalação: ~2 minutos** 🎉
