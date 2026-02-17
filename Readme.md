# 🤖 AI + WhatsApp Bot Starter Kit  
## DigitalOcean Beginner Deployment Guide

This guide walks you step-by-step through deploying your AI + WhatsApp automation server on **DigitalOcean** using **User Data** and **cloud-init** — the safest and easiest way to automate setup.

No server experience required.

---

# 🎯 What You’re Building

After setup, your server will run:

- WhatsApp automation bridge
- AI model engine
- Visual workflow builder
- Databases + caching

All installed automatically during server creation.

---

# 🧠 What is User Data (Simple Explanation)

When you create a DigitalOcean server (called a **Droplet**), you can attach a startup script.

DigitalOcean uses **cloud-init** to:

✅ Run your script automatically  
✅ Install software  
✅ Configure services  
✅ Prepare your environment  

This script runs **once** during the first boot — hands-free setup.

Important:

> User data cannot be changed after the Droplet is created.

---

# 🚀 Step 1 — Create Your DigitalOcean Server

## 1️⃣ Log In

Go to:

👉 https://digitalocean.com

Sign in or create an account.

---

## 2️⃣ Create Droplet

Click:

```
Create → Droplets
```

Choose:

### Image

```
Ubuntu 24.04 LTS
```

### Size (IMPORTANT)

```
4 GB RAM / 2 CPU minimum
```

Anything smaller will crash under AI load.

### Region

Pick the closest region to you.

### Authentication

Use a password (beginner-friendly).

---

# ⚙ Step 2 — Add Initialization Script (User Data)

Scroll down to:

```
Advanced Options
```

Enable:

```
☑ Add Initialization Scripts (User Data)
```

Paste this EXACT script:

```bash
#!/bin/bash
curl -fsSL https://raw.githubusercontent.com/EmreGunner/ai-automation-with-whatsapp-starter/main/setup.sh | bash
```

What this script does:

- Installs Docker
- Downloads the automation stack
- Configures services
- Starts everything automatically

---

## 3️⃣ Launch Droplet

Click:

```
Create Droplet
```

Now wait:

⏳ **7–10 minutes**

The server installs everything automatically.

---

# 🔍 Step 3 — Verify Setup

Copy your Droplet IP from the dashboard.

Example:

```
123.45.67.89
```

Open your browser:

### Automation Builder

```
http://YOUR_IP:5678
```

### WhatsApp Dashboard

```
http://YOUR_IP:8082
```

### AI Service Check

```
http://YOUR_IP:11434
```

If pages load → setup succeeded.

---

# 🧪 Optional — Monitor Installation Progress

If you want to see setup logs:

SSH into your server:

```bash
ssh root@YOUR_IP
```

Then run:

```bash
tail -f /var/log/workshop-setup.log
```

---

# 🛠 Debug User Data (cloud-init)

If something didn’t install correctly:

SSH into the server:

```bash
ssh root@YOUR_IP
```

View cloud-init logs:

```bash
cat /var/log/cloud-init-output.log | grep userdata
```

This shows:

- Script execution logs
- Errors
- Warnings

---

# 🔥 Common Beginner Mistakes

## ❌ Wrong server size

Symptoms:

- Installation crashes
- AI fails to start

Fix:

Upgrade to **4 GB RAM minimum**.

---

## ❌ Firewall blocking ports

Allow access:

```bash
ufw allow 5678/tcp
ufw allow 8081/tcp
ufw allow 8082/tcp
ufw allow 11434/tcp
ufw reload
```

Or configure firewall rules in DigitalOcean dashboard.

---

## ❌ Script pasted incorrectly

Make sure:

✔ Starts with `#!/bin/bash`  
✔ No extra spaces  
✔ Entire script pasted  

---

# 🔄 Updating the System

SSH into server:

```bash
ssh root@YOUR_IP
```

Go to install folder:

```bash
cd /opt/workshop
```

Update:

```bash
docker compose pull
docker compose up -d --remove-orphans
```

---

# 📱 Next Step — Connect WhatsApp

Open:

```
http://YOUR_IP:8082
```

Login:

```
Server URL → http://YOUR_IP:8081
API Key → workshop-key-xyz
```

Create instance → scan QR → connected.

---

# ✅ Deployment Complete

You now have:

✔ AI engine running  
✔ WhatsApp automation bridge  
✔ Workflow builder  
✔ Persistent storage  

Everything installed automatically via cloud-init.

---

# 📦 License

Apache 2.0 — free to use.

---

# 🆘 Help Resources

- n8n community forum  
- Evolution API documentation  
- GitHub issues  

---

# 🎉 You’re Ready

Start building bots, workflows, and AI automations directly inside WhatsApp.

---

