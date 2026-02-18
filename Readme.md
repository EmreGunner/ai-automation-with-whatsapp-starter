# 🤖 AI + WhatsApp Automation Starter Kit

**Deploy a complete AI workflow engine with professional WhatsApp automation in under 15 minutes.**

One-click setup on DigitalOcean. No coding required. Built on [n8n-io/self-hosted-ai-starter-kit](https://github.com/n8n-io/self-hosted-ai-starter-kit), extended with **Evolution API v2** for enterprise WhatsApp integration.

---

## 📦 What's Inside

| Service | Purpose | Port |
|---|---|---|
| **n8n** | Workflow automation with 400+ integrations | 5678 |
| **Evolution API** | WhatsApp bridge (send/receive messages, media, webhooks) | 8081 |
| **Evolution Manager** | Web UI for managing WhatsApp instances | 8081/manager OR 8082 |
| **Ollama** | Local LLM (Llama 3.2) — no API keys needed | 11434 |
| **Qdrant** | Vector database for AI memory | 6333 |
| **PostgreSQL ×2** | Isolated databases (n8n + Evolution) | internal |
| **Redis** | Session cache for Evolution API | internal |

---

## 🎯 What You Can Build

- **AI Customer Support Bot** — Answer questions 24/7 via WhatsApp using your local LLM
- **Document Summarizer** — Send PDF links, receive summaries on WhatsApp
- **Appointment Booking** — Let customers book through WhatsApp, auto-sync to calendar
- **Lead Qualifier** — Screen inbound leads and push hot ones to CRM
- **IT Helpdesk** — Internal employee support through company WhatsApp
- **Broadcast Campaigns** — Schedule messages to segmented contact lists

---

## 🚀 One-Click Setup on DigitalOcean

### Step 1: Create Your Droplet

1. Go to [DigitalOcean](https://cloud.digitalocean.com) → **Create → Droplets**
2. **Choose an OS:** Select `Ubuntu 24.04 (LTS) x64`
3. **Choose a Plan:** 
   - Select **Shared CPU** → **Basic**
   - Choose **4 GB RAM / 2 vCPUs** (~$24/month)
   
   > ⚠️ **Don't go smaller!** Llama 3.2 needs ~3.5 GB RAM. Droplets with 2 GB will crash.

4. **Choose Region:** Pick the datacenter closest to you
5. **Authentication:** Add your SSH key or set a root password

### Step 2: Add the Setup Script

1. Scroll down to **Advanced Options**
2. Check: ✅ **Add Initialization Scripts (User Data)**
3. Paste this in the text box:

```bash
#!/bin/bash
curl -fsSL https://raw.githubusercontent.com/EmreGunner/ai-automation-with-whatsapp-starter/main/setup.sh | bash
```

4. Click **Create Droplet**

### Step 3: Wait for Setup

The setup takes **15-20 minutes**. The script automatically:
- Opens firewall ports
- Installs Docker
- Pulls all images (~5 GB)
- Starts all 8 services
- Downloads Llama 3.2 model (~2 GB, in background)
- Validates everything works

When the droplet shows **Active**, copy your **Droplet IP** — you'll need it for every URL below.

---

## ✅ Step-by-Step Setup & Testing

### Quick Health Check

Before going through individual tests, run this one-liner to check if everything is working:

```bash
curl -fsSL https://raw.githubusercontent.com/EmreGunner/ai-automation-with-whatsapp-starter/main/health-check.sh | bash
```

You should see all green checkmarks ✓. If anything shows red ✗, see the [Troubleshooting](#️-troubleshooting) section.

---

### 1. Verify Services Are Running

**Option A: Via Health Check Script**

Run the health check above for a comprehensive report.

**Option B: Via SSH**

```bash
ssh root@YOUR_DROPLET_IP

# You'll see the status dashboard automatically on login:
#   ● n8n (http://64.23.165.226:5678)
#   ● evolution_manager (http://64.23.165.226:8082)
#   ● ollama (http://64.23.165.226:11434)
#   ...all green
```

If services aren't running:

```bash
cd /opt/workshop
docker compose ps        # Check status
docker compose up -d     # Start if needed
```

---

### 2. Test Ollama (AI Engine)

Open in your browser:
```
http://YOUR_DROPLET_IP:11434
```

You should see: `Ollama is running`

**Test the AI with a question:**

```bash
ssh root@YOUR_DROPLET_IP

# Ask Llama 3.2 a question
curl -X POST http://localhost:11434/api/generate -d '{
  "model": "llama3.2",
  "prompt": "Explain quantum computing in one sentence",
  "stream": false
}'
```

Response example:
```json
{
  "model": "llama3.2",
  "response": "Quantum computing harnesses quantum mechanics to process information..."
}
```

> **Note:** Llama 3.2 (~2GB) downloads automatically during setup. If you created your droplet less than 20 minutes ago and get `model not found`, wait 5 more minutes for the download to complete.

**Test Ollama from your browser (without SSH):**

You can also call Ollama directly from your local machine or browser console:

```bash
# From your local terminal (not SSH)
curl -X POST http://YOUR_DROPLET_IP:11434/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.2",
    "prompt": "What is artificial intelligence?",
    "stream": false
  }'
```

Or use a tool like Postman:
- **Method:** POST
- **URL:** `http://YOUR_DROPLET_IP:11434/api/generate`
- **Body (JSON):**
  ```json
  {
    "model": "llama3.2",
    "prompt": "Explain AI in simple terms",
    "stream": false
  }
  ```

---

### 3. Set Up Evolution Manager (WhatsApp)

#### 3.1 Log In to Evolution Manager

Evolution Manager can be accessed at **two URLs** (both work):

**Option A (Recommended):**
```
http://YOUR_DROPLET_IP:8082
```

**Option B (Alternative):**
```
http://YOUR_DROPLET_IP:8081/manager
```

You'll see a login screen. Enter:

| Field | Value |
|---|---|
| **Server URL** | `http://YOUR_DROPLET_IP:8081` |
| **API Key Global** | `workshop-key-xyz` |

Click **Connect**.

> **Why these values?**
> - Server URL points to Evolution API (the backend that connects to WhatsApp)
> - `workshop-key-xyz` is the default API key set in docker-compose.yml

#### 3.2 Create a WhatsApp Instance

1. Click **Instances** (left sidebar)
2. Click **+ Create Instance**
3. Enter:
   - **Instance Name:** `workshop` (or any name you like)
   - Leave other settings as default
4. Click **Create**

#### 3.3 Connect Your WhatsApp Number

1. Find your new instance in the list
2. Click **Connect**
3. A QR code appears
4. On your phone:
   - Open WhatsApp
   - Tap **Settings → Linked Devices**
   - Tap **Link a Device**
   - Scan the QR code on your screen

Within 5 seconds, the status changes to **Connected** ✅ (green circle).

> **Important:** This links WhatsApp to Evolution API, NOT WhatsApp Business API. You're using your personal/business WhatsApp number. Messages will appear in both the phone app and Evolution API.

#### 3.4 Test Sending a Message

1. Still in Evolution Manager, click your instance name
2. Click **Send Message** tab
3. Enter:
   - **Number:** Your own phone number in international format (e.g., `+14155551234`)
   - **Message:** `Test from Evolution API`
4. Click **Send**

Check your phone — you should receive the message instantly.

---

### 4. Test Evolution API Directly (Optional)

If you want to send messages programmatically (useful for n8n workflows later):

```bash
# Send a message via curl
curl -X POST http://YOUR_DROPLET_IP:8081/message/sendText/workshop \
  -H "apikey: workshop-key-xyz" \
  -H "Content-Type: application/json" \
  -d '{
    "number": "+14155551234",
    "text": "Hello from Evolution API via curl!"
  }'
```

Replace:
- `workshop` with your instance name
- `+14155551234` with your phone number

You should receive the message on WhatsApp.

---

### 5. Set Up n8n (Automation Builder)

#### 5.1 Create Your Owner Account

Open in your browser:
```
http://YOUR_DROPLET_IP:5678
```

First visit shows the **owner registration** screen. This is normal. Fill in:
- **Email:** Any email (no verification needed)
- **Password:** Create a strong password

Click **Continue** — you land on the workflow canvas.

#### 5.2 Test n8n with a Simple Workflow

Let's build a "Hello World" workflow to test everything works:

1. Click **+ Add first step**
2. Search for **Manual Trigger** → Select it
3. Click **+** button to add another node
4. Search for **HTTP Request** → Select it
5. Configure the HTTP Request node:
   - **Method:** POST
   - **URL:** `http://evolution_api:8080/message/sendText/workshop`
   - Click **Add Header**:
     - Name: `apikey`
     - Value: `workshop-key-xyz`
   - Click **Add Header** again:
     - Name: `Content-Type`
     - Value: `application/json`
   - **Body Content Type:** JSON
   - **JSON:**
     ```json
     {
       "number": "+14155551234",
       "text": "Hello from n8n!"
     }
     ```

6. Click **Test workflow** (top right)
7. Click **Execute workflow**

Check your phone — you should receive "Hello from n8n!"

> **🔥 Important:** Notice we used `http://evolution_api:8080` (internal Docker address), NOT `http://YOUR_DROPLET_IP:8081` (public address). Always use internal service names inside n8n workflows.

#### 5.3 Add Ollama AI to n8n Workflow

Let's test the AI engine by adding Ollama to a workflow:

1. Create a new workflow in n8n
2. Add **Manual Trigger** node
3. Add **HTTP Request** node
4. Configure:
   - **Method:** POST
   - **URL:** `http://ollama:11434/api/generate`
   - **Body Content Type:** JSON
   - **JSON:**
     ```json
     {
       "model": "llama3.2",
       "prompt": "Explain AI in one sentence",
       "stream": false
     }
     ```
5. Click **Test workflow** → **Execute workflow**

You'll see a response in the output panel with `"response": "..."` containing the AI's answer.

**Extract just the AI response:**

Add a **Code** node after the HTTP Request:
```javascript
return {
  json: {
    aiAnswer: $input.item.json.response
  }
};
```

Now you can use `{{ $json.aiAnswer }}` in any downstream node (like sending it to WhatsApp, email, Slack, etc.).

---

### 6. Test Qdrant (Vector Database)

Open in your browser:
```
http://YOUR_DROPLET_IP:6333
```

You should see JSON like:
```json
{
  "title": "qdrant - vector search engine",
  "version": "1.16.3"
}
```

Qdrant is used for AI memory (storing conversation history as vectors). You'll use it in advanced workflows.

---

## 🔗 Internal vs External Addresses — Critical!

When building workflows **inside n8n**, always use internal Docker service names:

| Service | ❌ Don't Use (Public) | ✅ Use This (Internal) |
|---|---|---|
| Evolution API | `http://YOUR_IP:8081` | `http://evolution_api:8080` |
| Ollama | `http://YOUR_IP:11434` | `http://ollama:11434` |
| Qdrant | `http://YOUR_IP:6333` | `http://qdrant:6333` |

**Why?**
- Docker has internal DNS — services find each other by name
- Internal traffic never leaves the server (faster, more secure)
- External IPs add latency and unnecessary firewall rules

**When to use public IPs?**
- ✅ Accessing web UIs from your browser (Evolution Manager, n8n UI)
- ✅ Testing Ollama from your local machine (outside the server)
- ✅ Webhooks from external services calling into your server (e.g., Stripe → n8n)
- ✅ Sending WhatsApp messages from external apps to Evolution API

**When to use internal service names?**
- ✅ **Inside n8n workflows** connecting to Evolution API, Ollama, or Qdrant
- ✅ Any service-to-service communication on the same Docker network

---

## 🧪 Example: Simple AI WhatsApp Bot

Now that everything is tested, let's build a real AI chatbot that responds to WhatsApp messages.

### Step 1: Create a Webhook in n8n

1. In n8n, create a new workflow
2. Add a **Webhook** node
3. Set **HTTP Method:** POST
4. Set **Path:** `whatsapp-webhook`
5. Copy the **Production URL** (looks like `http://YOUR_IP:5678/webhook/whatsapp-webhook`)

### Step 2: Connect Evolution API to n8n

1. Go to Evolution Manager → Your instance → **Webhook** tab
2. Click **Add Webhook**
3. Enter:
   - **URL:** Your n8n webhook URL from Step 1
   - **Events:** Check `messages.upsert` (received messages)
   - **Webhook By Events:** Enable
4. Click **Save**

### Step 3: Build the AI Response Logic

In your n8n workflow (after the Webhook node):

1. Add **Code** node:
   ```javascript
   // Extract the incoming message
   const message = $input.item.json.data.message.conversation;
   const from = $input.item.json.data.key.remoteJid;
   
   return {
     json: {
       userMessage: message,
       phoneNumber: from
     }
   };
   ```

2. Add **HTTP Request** node:
   - **Method:** POST
   - **URL:** `http://ollama:11434/api/generate`
   - **JSON:**
     ```json
     {
       "model": "llama3.2",
       "prompt": "{{$json.userMessage}}",
       "stream": false
     }
     ```

3. Add another **Code** node:
   ```javascript
   // Extract AI response
   return {
     json: {
       aiResponse: $input.item.json.response,
       phoneNumber: $('Code').item.json.phoneNumber
     }
   };
   ```

4. Add **HTTP Request** node (to send reply):
   - **Method:** POST
   - **URL:** `http://evolution_api:8080/message/sendText/workshop`
   - **Headers:** Same as before (`apikey`, `Content-Type`)
   - **JSON:**
     ```json
     {
       "number": "{{$json.phoneNumber}}",
       "text": "{{$json.aiResponse}}"
     }
     ```

5. Click **Save** → **Activate** (toggle in top right)

**Test:** Send any message to your WhatsApp number. The bot should respond with an AI-generated answer in 3-5 seconds.

---

## 🛠️ Troubleshooting

### Services Not Accessible (ERR_CONNECTION_REFUSED)

**Check containers:**
```bash
ssh root@YOUR_DROPLET_IP
cd /opt/workshop
docker compose ps
```

All should show `Up`. If not:
```bash
docker compose up -d
docker compose logs --tail=50
```

**Check firewall:**
```bash
ufw status
```

Required ports: `22, 5678, 8081, 8082, 11434`. If missing:
```bash
ufw allow 22/tcp
ufw allow 5678/tcp
ufw allow 8081/tcp
ufw allow 8082/tcp
ufw allow 11434/tcp
ufw reload
```

**Check DigitalOcean Cloud Firewall:**
- Go to **Networking → Firewalls** in DO dashboard
- If a firewall is attached to your droplet, ensure it allows the same ports

---

### Ollama Returns "model not found"

Llama 3.2 is still downloading (~2 GB, takes 5-10 minutes during initial setup).

**Check if download is complete:**

```bash
cd /opt/workshop
docker compose logs ollama --tail=30 | grep -i "success\|error"
```

If you see "success", the model is ready. If you see errors or nothing, the download may have failed. Restart it:

```bash
docker compose exec ollama ollama pull llama3.2
```

Wait for "success", then test again.

---

### Evolution API Crash-Looping

**Check logs:**
```bash
docker compose logs evolution_api --tail=30
```

Common issues:
- **Redis connection failed:** Restart evolution_api after 10 seconds:
  ```bash
  docker compose restart evolution_api
  ```

- **Database auth failed:** The postgres credentials don't match. Check docker-compose.yml:
  ```bash
  grep -A 5 "evolution_postgres:" docker-compose.yml
  # Should show: POSTGRES_USER=evolution_user
  ```

---

### Can't SSH to Server

Use the **DigitalOcean browser console**:
1. Click your droplet → **Console** (top right)
2. If it says "Connection lost", click **Reset**
3. Login as `root`
4. Run diagnostic commands from there

---

## 📊 Useful Commands

```bash
# Quick health check (run from anywhere)
curl -fsSL https://raw.githubusercontent.com/EmreGunner/ai-automation-with-whatsapp-starter/main/health-check.sh | bash

# View service status (auto-updates every 5 sec)
workshop-status

# View all logs in real-time
workshop-logs

# View logs for one service
docker compose logs -f evolution_api

# Restart all services
workshop-restart

# Run full health check (if workshop-health command exists)
workshop-health

# Check disk space
df -h

# Check memory usage
free -h

# Test Ollama from anywhere
curl -X POST http://YOUR_DROPLET_IP:11434/api/generate -d '{"model":"llama3.2","prompt":"Hello","stream":false}'
```

---

## 🔄 Updating

```bash
cd /opt/workshop
docker compose pull
docker compose up -d --remove-orphans
```

---

## 💾 Backup & Restore

**Backup (creates backup.tar.gz):**
```bash
cd /opt/workshop
docker compose down
tar -czf ~/backup-$(date +%Y%m%d).tar.gz \
  docker-compose.yml \
  $(docker volume inspect -f '{{ .Mountpoint }}' workshop_n8n_storage) \
  $(docker volume inspect -f '{{ .Mountpoint }}' workshop_n8n_postgres_data) \
  $(docker volume inspect -f '{{ .Mountpoint }}' workshop_evolution_postgres_data)
docker compose up -d
```

**Restore:**
```bash
cd /opt/workshop
docker compose down
tar -xzf ~/backup-20260218.tar.gz -C /
docker compose up -d
```

---

## 📜 License

Apache License 2.0 — based on [n8n-io/self-hosted-ai-starter-kit](https://github.com/n8n-io/self-hosted-ai-starter-kit).

---

## 💬 Support

- **GitHub Issues:** [Report bugs here](https://github.com/EmreGunner/ai-automation-with-whatsapp-starter/issues)
- **n8n Community:** [community.n8n.io](https://community.n8n.io/)
- **Evolution API Docs:** [doc.evolution-api.com](https://doc.evolution-api.com/v2/en)

---

## 🎓 Next Steps

**Ready to build real workflows?** Check out these examples:

- **[PDF Summarizer Bot](examples/pdf-summarizer.md)** — Send a PDF URL, get summary on WhatsApp
- **[Appointment Booking](examples/appointment-booking.md)** — Customers book slots via WhatsApp
- **[Lead Qualifier](examples/lead-qualifier.md)** — Screen leads and push to CRM
- **[Customer Support Bot](examples/support-bot.md)** — 24/7 AI helpdesk

> Note: Example workflows coming soon. Star the repo to get notified!
