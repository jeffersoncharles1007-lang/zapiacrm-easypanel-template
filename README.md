# 🚀 ZAPIACRM - Como Instalar em 5 Minutos

Guia **ultra simplificado**. O cliente só precisa de **1 comando + 1 informação**.

---

## 📋 Passo a Passo (5 minutos no total)

### 1️⃣ Contrate uma VPS Ubuntu (se ainda não tem)

**Opções recomendadas:**

| Provedor | Plano | Preço |
|----------|-------|-------|
| Hostinger | VPS KVM 1 | R$30/mês |
| DigitalOcean | Basic Droplet | $6/mês (~R$30) |
| Hetzner | CX22 | €4/mês (~R$22) |

**Requisitos mínimos:** Ubuntu 22.04+, 2GB RAM

---

### 2️⃣ Conecte na VPS via SSH

**Windows:** Abra PowerShell e rode:
```bash
ssh root@IP-DA-VPS
```

**Mac/Linux:** Abra o Terminal e rode:
```bash
ssh root@IP-DA-VPS
```

Digite a senha quando pedir.

---

### 3️⃣ Cole o comando único e responda 1 pergunta

```bash
curl -fsSL https://raw.githubusercontent.com/jeffersoncharles1007-lang/zapiacrm-easypanel-template/main/install-1click.sh | bash
```

**Quando pedir**, digite o IP da VPS (ou domínio):
```
Qual o IP da sua VPS ou dominio?
→ 123.456.78.90
```

**Aguarde 3-5 minutos** enquanto:
- Instala Docker (se necessário)
- Baixa as imagens (Postgres + ZAPIACRM + Evolution)
- Cria o banco de dados automaticamente
- Configura tudo

---

### 4️⃣ Acesse no navegador

Quando aparecer `SISTEMA PRONTO!`, abra:

```
http://123.456.78.90:4000
```

---

### 5️⃣ Crie sua conta

1. Clique em **"Criar conta"**
2. Digite email e senha
3. Você automaticamente vira **administrador**
4. Pronto, pode usar!

---

### 6️⃣ (Opcional) Conecte seu WhatsApp

1. Vá em **/whatsapp** no menu
2. Escaneie o QR Code com seu celular
3. Pronto! Mensagens começam a ser processadas pela IA

---

## 🎯 Resumo: O que o cliente faz vs. o que o Docker faz

### 👤 O cliente só faz:
1. Contrata VPS
2. Conecta SSH
3. Cola 1 comando
4. Digita 1 coisa (IP)
5. Espera 5 minutos
6. Cria conta no navegador

### 🤖 O Docker faz sozinho (cliente nem vê):
- ✅ Instala Docker se faltar
- ✅ Cria banco Postgres
- ✅ Cria 17 tabelas automaticamente
- ✅ Configura 5 funções SQL
- ✅ Configura policies de segurança
- ✅ Sobe servidor Node.js
- ✅ Conecta Evolution API (WhatsApp central)
- ✅ Mantém tudo rodando 24/7

---

## 🆘 Problemas Comuns

### "Docker not found"
O instalador instala automaticamente. Se der erro:
```bash
curl -fsSL https://get.docker.com | sh
```

### "Port 4000 already in use"
Outro app está usando a porta. Mate-o:
```bash
docker ps
docker stop [nome-do-container]
```

### "Não consigo acessar http://IP:4000"
Verifique o firewall da VPS:
```bash
ufw allow 4000/tcp
```

### Reiniciar tudo do zero
```bash
cd /opt/zapiacrm
docker compose down
docker compose up -d
```

### Ver logs (se algo der errado)
```bash
cd /opt/zapiacrm
docker compose logs -f
```

---

## 📞 Suporte

- Email: suporte@zapiacrm.com.br
- Documentação: https://github.com/jeffersoncharles1007-lang/zapiacrm-easypanel-template

---

**Tempo total: 5 minutos. Clientes não precisam entender Docker, banco de dados, ou SSH avançado.** 🎉