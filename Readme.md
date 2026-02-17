# 🤖 AI & WhatsApp Automation Starter Kit

Welcome! This is a simple, ready-to-use setup that lets you create fun and useful AI-powered tools connected to WhatsApp. Imagine building a chatbot that answers questions 24/7 or a helper that summarizes PDFs right in your chats.

You can set it up on a cloud server (like DigitalOcean) in under 10 minutes with just a few clicks. No fancy coding skills needed!

---

## ✅ What's Inside the Kit

- **n8n** — automation builder with AI support  
- **Evolution API v2** — WhatsApp bridge  
- **Evolution Manager** — dashboard for managing WhatsApp  
- **Ollama** — local AI model runner  
- **Qdrant** — AI memory storage  
- **PostgreSQL** — databases  
- **Redis** — session cache  

All components run inside Docker containers.

---

## ⭐ Fun Things You Can Build

- Friendly WhatsApp chatbot  
- PDF summarizer bot  
- Appointment booking assistant  
- Lead qualification bot  
- Office helpdesk assistant  
- Message scheduler  

---

## 🗺️ Architecture Overview

```
┌─────────────────────── Private Network ──────────────────────────┐
│                                                                    │
│  n8n ───▶ Evolution API ───▶ WhatsApp                              │
│   │            │                                                   │
│   ▼            ▼                                                   │
│ Ollama       Redis        Postgres                                 │
│                                                                    │
│ Qdrant      Postgres (n8n)                                         │
└────────────────────────────────────────────────────────────────────┘
```

### Public Access Ports

- `5678` — n8n  
- `8081` — Evolution API  
- `8082` — Evolution Manager  
- `11434` — Ollama  

---

## 🚀 DigitalOcean Setup (Fastest Method)

### Step 1 — Create Droplet

- Ubuntu 24.04 LTS  
- Minimum **4 GB RAM / 2 vCPU**

### Step 2 — Setup Script

Paste into **User Data**:

```bash
#!/bin/bash
curl -fsSL https://raw.githubusercontent.com/EmreGunner/ai-automation-with-whatsapp-starter/main/setup.sh | bash
```

Create the droplet and wait ~10 minutes.

Optional log monitoring:

```bash
tail -f /var/log/workshop-setup.log
```

---

## 🔗 Access Your Tools

Replace `[YOUR_IP]`.

### n8n

```
http://[YOUR_IP]:5678
```

### Evolution Manager

```
http://[YOUR_IP]:8082
```

Login:

```
Server URL: http://[YOUR_IP]:8081
API Key: workshop-key-xyz
```

Connect WhatsApp → scan QR code.

### Ollama

```
http://[YOUR_IP]:11434
```

---

## 🔧 Internal Service URLs (for n8n)

Use internal Docker addresses:

```
Evolution API → http://evolution_api:8080
Ollama → http://ollama:11434
Qdrant → http://qdrant:6333
Postgres → postgres:5432
```

---

## 💻 Local Setup

Prerequisite: Docker Desktop installed.

```bash
git clone https://github.com/EmreGunner/ai-automation-with-whatsapp-starter.git
cd ai-automation-with-whatsapp-starter
cp env.example .env
docker compose up -d
docker compose ps
```

Access locally:

```
http://localhost:5678
http://localhost:8082
http://localhost:8081
http://localhost:11434
```

---

## ⬆️ Updating

```bash
docker compose pull
docker compose up -d --remove-orphans
```

---

## 🔍 Troubleshooting

### Firewall

```bash
ufw allow 5678/tcp
ufw allow 8081/tcp
ufw allow 8082/tcp
ufw allow 11434/tcp
ufw reload
```

### Memory Check

```bash
free -h
```

### Logs

```bash
docker compose logs ollama --tail=50
```

### Restart Services

```bash
docker compose restart evolution_api
docker compose down
docker compose up -d
```

---

## 📜 License

Apache License 2.0.

---

## 💬 Help

- n8n forum  
- Evolution API docs  
- GitHub issues  

---
