# 🤖 AI + WhatsApp Automation Starter Kit

A one-click Docker stack that deploys a complete AI workflow engine with professional WhatsApp automation — ready in under 10 minutes.

Built on the [n8n-io/self-hosted-ai-starter-kit](https://github.com/n8n-io/self-hosted-ai-starter-kit), extended with **Evolution API v2** for WhatsApp integration.

---

## ✅ What's Included

| Service | Purpose | Port |
|---|---|---|
| **n8n** | Workflow automation with 400+ integrations and AI nodes | 5678 |
| **Evolution API v2** | WhatsApp bridge (send/receive messages, webhooks, media) | 8081 |
| **Evolution Manager** | Web UI for managing WhatsApp instances and QR scanning | 8082 |
| **Ollama** | Local LLM runner — Llama 3.2 runs privately, no API key | 11434 |
| **Qdrant** | Vector database for AI long-term memory | 6333 (internal) |
| **PostgreSQL ×2** | Separate isolated databases for n8n and Evolution API | internal only |
| **Redis** | Cache layer for Evolution API session management | internal only |

---

## ⭐ What You Can Build

- **AI WhatsApp Chatbot** — Answer customer questions 24/7 using your local LLM
- **PDF Summariser via WhatsApp** — Send a document link, receive a summary on WhatsApp
- **Appointment Booking Bot** — Customers book via WhatsApp, n8n writes to your calendar
- **Lead Qualification Agent** — Qualify inbound leads and push them to your CRM
- **Internal IT Helpdesk Bot** — Handle employee requests through a company WhatsApp number
- **Broadcast Automation** — Schedule and send messages to segmented contact lists

---

## 🚀 One-Click Setup on DigitalOcean

### Step 1 — Create a Droplet

1. Log in to [DigitalOcean](https://cloud.digitalocean.com) and click **Create → Droplets**
2. **OS:** Choose `Ubuntu 24.04 (LTS) x64`
3. **Plan:** Shared CPU → **Basic**
4. **Size:** `4 GB RAM / 2 vCPUs` (~$24/month)

> ⚠️ **RAM Warning:** Ollama (the AI engine) requires at least 3.5 GB of RAM to run the Llama 3.2 model. A droplet with less than 4 GB RAM will crash. Do not go smaller.

5. **Region:** Choose the city closest to you
6. **Authentication:** Add an SSH key, or use a root password (password is fine for a workshop)

### Step 2 — Paste the Setup Script

1. Still on the Droplet creation page, scroll down to **Advanced Options**
2. Check the box: ✅ `Add Initialization Scripts (User Data)`
3. A text box appears. Paste **exactly** this — nothing more, nothing less:

```bash
#!/bin/bash
curl -fsSL https://raw.githubusercontent.com/EmreGunner/ai-automation-with-whatsapp-starter/main/setup.sh | bash
```

### Step 3 — Launch and Wait

1. Click **Create Droplet**
2. Wait **7–10 minutes**. The script automatically:
   - Opens firewall ports
   - Installs Docker
   - Clones this repository
   - Pulls all Docker images (~1.5 GB)
   - Starts all 7 services
3. Once the Droplet shows **Active**, copy your **Droplet IP address**

---

## 🔗 Accessing Your Tools

Replace `YOUR_IP` with your actual Droplet IP in every URL below.

---

### 1. n8n — Automation Builder

**URL:** `http://YOUR_IP:5678`

On your first visit, n8n shows an **owner registration screen**. This is normal — fill in any email and password to create your admin account. No email verification required. You land directly on the workflow canvas.

---

### 2. Evolution Manager — WhatsApp Control Panel

**URL:** `http://YOUR_IP:8082`

On the login screen enter:
- **Server URL:** `http://YOUR_IP:8081`
- **Global API Key:** `workshop-key-xyz`

To connect a WhatsApp number:
1. Click **Instances** → **Create Instance** → give it a name (e.g. `workshop`)
2. Click **Connect** — a QR code appears
3. On your phone: **WhatsApp → Settings → Linked Devices → Link a Device**
4. Scan the QR code. The instance status turns green ✅

---

### 3. Ollama — Local AI Engine

**URL:** `http://YOUR_IP:11434`

If you see `"Ollama is running"` in the browser, the AI engine is online. Llama 3.2 downloads automatically in the background on first start (~2 GB, takes about 5 minutes).

---

## 🔧 Internal Docker Networking — Important

> This is the most common source of errors. Please read carefully.

When building workflows inside n8n, **never use the public IP** to connect services together. Use the internal Docker service names instead. All traffic stays inside the private network — faster, more secure, no extra cost.

| Connecting to | ❌ Don't use | ✅ Use this in n8n |
|---|---|---|
| Evolution API | `http://YOUR_IP:8081` | `http://evolution_api:8080` |
| Ollama | `http://YOUR_IP:11434` | `http://ollama:11434` |
| Qdrant | `http://YOUR_IP:6333` | `http://qdrant:6333` |

**Why?** Docker has its own internal DNS. Using the service name `evolution_api` resolves directly inside the container network. Using the public IP sends traffic out through the network card and back in, adding latency and unnecessarily exposing ports.

---

## 💻 Manual Local Installation

For running on your own machine ([Docker Desktop](https://www.docker.com/products/docker-desktop/) required):

```bash
git clone https://github.com/EmreGunner/ai-automation-with-whatsapp-starter.git
cd ai-automation-with-whatsapp-starter
cp env.example .env
docker compose up -d
```

Access locally at `http://localhost:5678` (n8n) and `http://localhost:8082` (Evolution Manager).

---

## ⬆️ Updating

```bash
cd /opt/workshop
docker compose pull
docker compose up -d --remove-orphans
```

---

## 🛠 Troubleshooting

### "This site can't be reached" / ERR_CONNECTION_REFUSED

If you can't reach any port in the browser, work through this checklist in order:

**1. Check if containers are actually running**

SSH in (or use the DigitalOcean browser Console), then run:

```bash
cd /opt/workshop
docker compose ps
```

All services should show `Up`. If not:

```bash
docker compose up -d
docker compose logs --tail=50
```

**2. Check the setup log to see where the script stopped**

```bash
cat /var/log/workshop-setup.log
```

Also check the cloud-init official log (the DO standard location):

```bash
cat /var/log/cloud-init-output.log
```

Look for any line with `ERROR` or `failed`.

**3. Check the UFW firewall on the server**

```bash
ufw status
```

Required ports must show `ALLOW`. If they don't:

```bash
ufw allow 22/tcp
ufw allow 5678/tcp
ufw allow 8081/tcp
ufw allow 8082/tcp
ufw allow 11434/tcp
ufw reload
```

**4. Check the DigitalOcean Cloud Firewall (separate from UFW)**

In the DigitalOcean dashboard:
1. Go to **Networking → Firewalls**
2. If a firewall is assigned to your Droplet, make sure it has inbound rules allowing TCP ports `5678`, `8081`, `8082`, and `11434`
3. If there is no cloud firewall, skip this step — UFW on the server is sufficient

> DigitalOcean has two separate firewall layers: UFW runs **on the server**, the Cloud Firewall runs **at the network level** before traffic even reaches the server. Both must allow a port for it to be accessible.

---

### Ollama Crashing / n8n Returns 502 Bad Gateway

**Cause:** Not enough RAM. Llama 3.2 needs ~3.5 GB of RAM to load. On a 2 GB droplet the kernel will OOM-kill the container.

**Fix:** Resize your Droplet to 4 GB RAM in DigitalOcean (can be done without data loss: power off → Resize → power on).

To confirm the cause:

```bash
# Check available memory
free -h

# Check if Ollama was killed
docker compose logs ollama --tail=50
# Look for "Killed" or "OOM" messages
```

---

### Evolution API Keeps Restarting — Redis Error

**Symptom:** `docker compose logs evolution_api` shows `[Redis] redis disconnected` in a loop.

**Cause:** Evolution API started before Redis was fully ready.

**Fix:**

```bash
cd /opt/workshop
docker compose restart evolution_api
# Wait 15 seconds, then check
docker compose ps
```

---

### Can't SSH Into the Server

If you can't SSH, use the **DigitalOcean browser console** instead:

1. In the DigitalOcean dashboard, click your Droplet
2. Click **Console** in the top right
3. If the console shows `SSH Connection Lost`, click **Reset**
4. Log in with `root` and your password
5. From here you can run all the diagnostic commands above

---

## 📜 License

Apache License 2.0 — based on [n8n-io/self-hosted-ai-starter-kit](https://github.com/n8n-io/self-hosted-ai-starter-kit).

---

## 💬 Support

- [n8n Community Forum](https://community.n8n.io/)
- [Evolution API Docs](https://doc.evolution-api.com/v2/en)
- [GitHub Issues](https://github.com/EmreGunner/ai-automation-with-whatsapp-starter/issues)
