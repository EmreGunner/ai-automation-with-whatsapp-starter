🤖 AI & WhatsApp Automation Starter Kit

A production-ready Docker Compose stack that deploys a complete AI workflow engine with professional WhatsApp integration in under 10 minutes.

This repository is a strategic evolution of the n8n-io/self-hosted-ai-starter-kit, supercharged with Evolution API v2 for enterprise-grade WhatsApp automation.

✅ What's Included
ServicePurposeVersion🔁 n8nLow-code automation engine with 400+ integrations and advanced AI nodesLatest📱 Evolution API v2Professional WhatsApp bridge (send/receive messages, media, webhooks)v2 Latest🖥️ Evolution ManagerWeb UI to manage WhatsApp instances and QR code scanningLatest🧠 OllamaLocal LLM runner — runs Llama 3.2 privately, no API key neededLatest📦 QdrantHigh-performance vector database for AI long-term memoryLatest🐘 PostgreSQL (×2)Separate isolated databases for n8n and Evolution API15⚡ RedisIsolated cache layer for Evolution API session managementLatest

⭐ What You Can Build

🤝 AI WhatsApp Chatbot — Answer customer questions 24/7 using your private LLM
📄 PDF → WhatsApp Summariser — Send a PDF link, get a summary back on WhatsApp
📅 Appointment Booking Bot — Customers book via WhatsApp, n8n writes to your calendar
🧑‍💼 Lead Qualification Agent — Qualify inbound WhatsApp leads and route to your CRM
📊 Internal IT Helpdesk Bot — Handle employee requests via a company WhatsApp number
🔔 Broadcast Automation — Schedule and send segmented messages to contact lists


🗺️ Architecture Overview
┌─────────────────────── Docker Network: workshop-net ──────────────────────────┐
│                                                                                  │
│   ┌──────────────┐      ┌─────────────────┐      ┌─────────────────────────┐  │
│   │   n8n :5678  │─────▶│ evolution_api   │─────▶│  WhatsApp (via Baileys)  │  │
│   │  (AI Engine) │      │ internal: :8080 │      └─────────────────────────┘  │
│   └──────┬───────┘      └────────┬────────┘                                    │
│          │                       │                                              │
│   ┌──────▼──────┐    ┌──────────▼────────┐    ┌────────────────────────────┐  │
│   │  Ollama     │    │  evolution_redis  │    │  evolution_postgres        │  │
│   │  :11434     │    │  (internal only)  │    │  (internal only, :5432)    │  │
│   └─────────────┘    └───────────────────┘    └────────────────────────────┘  │
│                                                                                  │
│   ┌─────────────┐    ┌───────────────────┐                                     │
│   │  Qdrant     │    │  n8n Postgres     │                                     │
│   │  :6333      │    │  (internal only)  │                                     │
│   └─────────────┘    └───────────────────┘                                     │
└──────────────────────────────────────────────────────────────────────────────────┘
Public Ports (Firewall must allow these):
PortServiceURL5678n8nhttp://[IP]:56788081Evolution APIhttp://[IP]:80818082Evolution Manager UIhttp://[IP]:808211434Ollamahttp://[IP]:11434

🚀 One-Click Setup on DigitalOcean
This is the recommended method for the workshop. Zero manual SSH required.
Step 1 — Create a Droplet

Log in to DigitalOcean → click Create Droplet
OS: Select Ubuntu 24.04 (LTS) x64
Plan: Shared CPU → Basic
CPU Option: Regular SSD or Premium Intel
Size: Select 4 GB RAM / 2 vCPUs ($24/mo)


⚠️ CRITICAL — RAM Warning: The Ollama LLM engine will crash and restart on any droplet with less than 4 GB RAM. Do not choose a smaller size. The 4 GB tier is the absolute minimum.


Datacenter Region: Choose the one closest to your physical location
Authentication: Add your SSH key or use a root password (password is fine for a workshop)

Step 2 — Paste the Setup Script (User Data)

Scroll down the Droplet creation page to Additional Options
Check the box: ✅ "Add Initialization scripts (User Data)"
Paste exactly the following into the text box:

bash#!/bin/bash
curl -fsSL https://raw.githubusercontent.com/EmreGunner/ai-automation-with-whatsapp-starter/main/setup.sh | bash
Step 3 — Launch & Wait

Click Create Droplet
⏳ Wait 7–10 minutes. The server must:

Install Docker & dependencies
Pull all Docker images (~1.5 GB total)
Start all 7 services
Download the Llama 3.2 model via Ollama (~2 GB) ← this is the slow part


Once the Droplet shows "Active" in DigitalOcean, copy your Droplet IP Address


💡 Tip: You can monitor progress by SSHing in and running: tail -f /var/log/workshop-setup.log


🔗 Accessing Your Tools (After Setup)
Replace [YOUR_IP] with your Droplet IP in every URL below.

1️⃣ n8n — The Automation Brain
URL: http://[YOUR_IP]:5678
On your first visit, you will see an owner registration screen. This is normal — you are creating the admin account for this instance. Fill in an email and password, then click "Next". You will not need to verify the email.

✅ Once registered, you land on the n8n canvas and you're ready to build workflows.


2️⃣ Evolution Manager — The WhatsApp Control Panel
URL: http://[YOUR_IP]:8082
On the login screen, enter:

Server URL: http://[YOUR_IP]:8081
Global API Key: workshop-key-xyz

To connect a WhatsApp number:

Click Instances → Create Instance
Give it a name (e.g., workshop)
Click Connect — a QR Code will appear
On your phone, open WhatsApp → Settings → Linked Devices → Link a Device
Scan the QR code. The instance status will turn green ✅


3️⃣ Ollama — The Local AI Engine
URL: http://[YOUR_IP]:11434
If you see "Ollama is running" in your browser, the AI engine is online. The Llama 3.2 model is pre-configured and will be downloaded automatically on first start.

🔧 Internal Docker Networking — IMPORTANT

This is the most common source of errors for workshop participants. Please read carefully.

When building n8n workflows, you must never use the public IP address to connect services together. Instead, use the internal Docker service names. This keeps all traffic inside the private network — faster, cheaper, and secure.
When connecting to...❌ Do NOT use✅ Use this insteadEvolution APIhttp://[YOUR_IP]:8081http://evolution_api:8080Ollamahttp://[YOUR_IP]:11434http://ollama:11434Qdranthttp://[YOUR_IP]:6333http://qdrant:6333n8n Postgres[YOUR_IP]:5432postgres:5432
Why? When n8n sends a request to http://evolution_api:8080, it resolves via Docker's internal DNS — no packet ever leaves the server. Using the public IP routes traffic through the network interface, adding latency and exposing service ports unnecessarily.

💻 Manual Local Installation
For running this stack on your own machine (requires Docker Desktop):
bash# 1. Clone the repository
git clone https://github.com/EmreGunner/ai-automation-with-whatsapp-starter.git
cd ai-automation-with-whatsapp-starter

# 2. Copy environment config
cp env.example .env

# 3. (Optional) Edit .env to change passwords
# nano .env

# 4. Start all services
docker compose up -d

# 5. Check status
docker compose ps
Access locally:

n8n: http://localhost:5678
Evolution Manager: http://localhost:8082
Evolution API: http://localhost:8081
Ollama: http://localhost:11434

Resource note for Mac (Apple Silicon / M-series):
Docker Desktop on Mac cannot share GPU resources with containers. Ollama will run on CPU only. Expect ~2–3× slower model inference. Everything still works — it's just slower.

⬆️ Upgrading
bashcd /opt/workshop
docker compose pull
docker compose up -d --remove-orphans

🔍 Troubleshooting
🔥 Firewall — Can't access n8n or Evolution Manager?
DigitalOcean Droplets use a cloud-level firewall (separate from UFW). If your ports aren't accessible, check both layers:
Option A — DigitalOcean Cloud Firewall (recommended):

In DigitalOcean, go to Networking → Firewalls
Create an inbound rule allowing TCP ports: 5678, 8081, 8082, 11434
Apply the firewall to your Droplet

Option B — UFW on the Droplet (if applicable):
bashufw allow 5678/tcp
ufw allow 8081/tcp
ufw allow 8082/tcp
ufw allow 11434/tcp
ufw reload

ℹ️ By default, Ubuntu 24.04 on DigitalOcean does not have UFW enabled. Your main concern is the cloud-level firewall.


💾 Ollama Crashing / n8n Returning 502?
Symptom: n8n shows "502 Bad Gateway" or Ollama requests time out.
Cause: Insufficient RAM. Llama 3.2 requires ~3.5 GB of RAM to run. On a 2 GB Droplet, the container will be OOM-killed by the kernel.
Fix: Resize your Droplet to 4 GB RAM minimum (can be done in DigitalOcean without data loss — power off → resize → power on).
bash# Check memory usage on the server
free -h

# Check which containers are running
docker compose ps

# Inspect Ollama logs for OOM messages
docker compose logs ollama --tail=50

📱 Evolution API Redis Disconnected Error?
Symptom: docker logs evolution_api shows [Redis] [string] redis disconnected repeatedly.
Cause: Evolution API container started before the Redis container was fully healthy.
Fix:
bashcd /opt/workshop
docker compose restart evolution_api
# Wait 10 seconds, then check
docker compose logs evolution_api --tail=30
If it persists, do a full restart with dependency ordering:
bashdocker compose down
docker compose up -d

🐘 Evolution API "Can't reach database" Error?
Symptom: Evolution API crashes with P1001: Can't reach database server.
Cause: Evolution API started before PostgreSQL was ready to accept connections.
Fix:
bashcd /opt/workshop
# Wait for postgres to be fully ready, then restart evolution_api
docker compose restart evolution_api

🔑 Forgot the API Key for Evolution?
The API Key is workshop-key-xyz (set in .env). You can change it by editing /opt/workshop/.env:
bashnano /opt/workshop/.env
# Edit AUTHENTICATION_API_KEY=your-new-key
docker compose up -d evolution_api  # apply change

📜 License
This project is based on the n8n-io/self-hosted-ai-starter-kit and is licensed under the Apache License 2.0.

💬 Support & Community

🧵 n8n Community Forum — for workflow and AI node questions
📚 Evolution API Documentation — for WhatsApp API configuration
🎓 Workshop issues? Raise a GitHub Issue on this repository
