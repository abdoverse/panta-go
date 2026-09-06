---
name: panta-local-run
description: Orchestrates running the full Panta application stack locally (Go backend, Flutter Web, demo data seeding) for browser testing, and manages the multi-agent development loop. Use when the user asks to run, test, start, or verify the app locally in the browser.
---

# Panta Local Stack & Development Skill

This skill brings up and manages the **complete Panta application stack locally in the browser**, enabling immediate end-to-end interactive testing of both Recycler and Helper workflows without needing AWS Cognito credentials or external services.

## Quick Start: Run the Whole App Locally

To start the full stack (Backend + Seed Data + Flutter Web):
```bash
scripts/run_local.sh start
# or via manage_loop.sh:
scripts/manage_loop.sh local start
```

### URLs & Ports
- **Flutter Web App**: [http://localhost:3000](http://localhost:3000)
- **Go Backend API**: [http://localhost:8080](http://localhost:8080)
- **WebSocket Gateway**: `ws://localhost:8080/api/v1/ws`

---

## 1-Click Browser Testing (No Credentials Required)

When opening `http://localhost:3000`, the login screen displays a prominent **"⚡ Local Testing / 1-Click Demo"** card:

1. **Anna (Recycler)**
   - Click **"Anna (Recycler)"** to instantly enter the Recycler experience:
     - **Ongoing Requests**: Active pickup request at *Götgatan 22, Stockholm* with live ETA countdown (12 mins) and proximity status.
     - **Live In-App Chat**: Open the chat window with Erik Helper pre-populated with realistic message history.
     - **BankID Verification Badge**: Profile displays verified Swedish BankID badge (`19920512-****`).
     - **Sustainability Impact**: Impact dashboard showing CO2 savings, recycling streak, and unlocked Eco Badges.
     - **Create Request**: Full flow to submit new requests with map location, Leave-at-Door contactless instructions, and Pant refund split slider (e.g. 70/30).

2. **Erik (Helper / Pantare)**
   - Click **"Erik (Helper)"** to enter the Helper experience:
     - **Available Jobs**: Live feed of nearby recycling jobs sorted by distance (e.g. *Sveavägen 44, Stockholm*).
     - **Job Actions**: One-tap **"Accept Pickup"** to claim jobs.
     - **Arrival Alert**: One-tap **"I am at the door"** button to alert the recycler with an arrival notification.
     - **Receipt OCR & Split**: Scan pant slip, auto-calculate 70/30 refund split, and confirm earnings.
     - **Contactless Dropoff**: Complete pickups with photo proof and door dropoff confirmation.

3. **In-App Demo Switcher & Re-Seeding**
   - Inside the app, navigate to **Profile**:
     - Tap **"Switch to Helper / Switch to Recycler"** to toggle perspectives immediately with 1 click.
     - Tap **"Re-seed Sample Requests"** anytime to reset and refresh pending, accepted, and completed requests.

---

## Service Management Commands

```bash
# Check running status of backend (8080) and web (3000)
scripts/run_local.sh status

# Re-seed realistic test requests into local DynamoDB
scripts/run_local.sh seed

# View live logs
scripts/run_local.sh logs

# Stop all local processes
scripts/run_local.sh stop

# Restart the full stack
scripts/run_local.sh restart
```

---

## Multi-Agent Development Loop (PantaSwarm)

To manage background autonomous agent development:
```bash
scripts/manage_loop.sh start     # Starts the background orchestrator
scripts/manage_loop.sh status    # Checks orchestrator process & heartbeat
scripts/manage_loop.sh recover   # Recovers stalled backlog tasks
scripts/manage_loop.sh logs      # Tails .copilot/orchestrator.log
```