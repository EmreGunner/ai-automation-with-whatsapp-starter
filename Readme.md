I have thoroughly reviewed the n8n AI Starter Kit and the Evolution API repositories to ensure the installation steps and environment variables are 100% accurate.

Here is your professional, step-by-step README.md in Markdown format.

🤖 AI & WhatsApp Automation Starter Kit
This repository is a curated Docker Compose template designed to deploy a complete AI and WhatsApp automation environment in minutes. It combines the low-code power of n8n with the professional WhatsApp integration of Evolution API.

✅ What’s Included?
n8n (AI Edition): The workflow engine with advanced AI nodes.

Evolution API v2: The most robust open-source WhatsApp bridge.

Ollama: Local LLM runner (Llama 3.2 pre-configured).

Qdrant: Vector database for "Long-term AI Memory."

PostgreSQL & Redis: High-performance database and caching.

🚀 One-Click Setup (DigitalOcean)
Use this for the workshop to avoid manual terminal commands.

Step 1: Create Your Droplet
Log in to DigitalOcean and click Create Droplet.

OS: Choose Ubuntu 24.04 (LTS).

Plan: Choose Shared CPU -> Basic.

CPU Options: Select Regular SSD or Premium Intel.

Size: Select 4GB RAM / 2 CPUs ($24/mo).

⚠️ IMPORTANT: AI models (Ollama) will CRASH on droplets with less than 4GB of RAM.

Region: Select the city closest to you.

Step 2: Add the Setup Script
Scroll down to Recommended and Advanced Options.

Check the box "Add Initialization scripts" (User Data).

Paste the following code exactly:

Bash
#!/bin/bash
curl -s https://raw.githubusercontent.com/EmreGunner/ai-automation-with-whatsapp-starter/main/setup.sh | bash
Step 3: Launch
Click Create Droplet.

Wait 5 to 8 minutes. The server needs time to install Docker, pull the images, and download the Llama 3.2 model (~2GB).

🔗 Accessing Your Tools
Once the Droplet is "Running," copy your Droplet IP Address from DigitalOcean.

1. n8n (Automation Brain)
URL: http://YOUR_DROPLET_IP:5678

Setup: On your first visit, you will see a Registration Screen. Create your owner account to start building.

2. Evolution API Manager (WhatsApp Connection)
URL: http://YOUR_DROPLET_IP:8081/manager

Authentication:

Global ApiKey: workshop-key-xyz

Next Steps:

Click on "Instances".

Create a new instance.

Scan the QR Code with your WhatsApp (Linked Devices).

3. Ollama (AI Brain)
URL: http://YOUR_DROPLET_IP:11434

Status: If you see "Ollama is running," your AI is ready.

🛠️ How to Connect Tools (Internal Networking)
When building workflows in n8n, use these internal addresses for faster performance (avoiding the public internet):

Evolution API URL for n8n: http://evolution_api:8080

Ollama URL for n8n: http://ollama:11434

Qdrant URL for n8n: http://qdrant:6333

💻 Manual Installation (Local Desktop)
If you want to run this kit on your own computer (Docker Desktop required):

Clone the Repo:

Bash
git clone https://github.com/EmreGunner/ai-automation-with-whatsapp-starter.git
cd ai-automation-with-whatsapp-starter
Prepare Environment:

Bash
cp env.example .env
Start Services:

Bash
docker compose up -d
Access: Open http://localhost:5678 (n8n) and http://localhost:8081/manager (Evolution API).

📜 License
This starter kit is open-source and based on the Apache License 2.0.
