---
name: Local Development Setup
description: How to start the full local development environment with hot reload for testing on mobile.
---

# Panta Local Development Setup

When the user asks to "run locally", "start the dev server", or "test on phone", use this setup to provide an instant hot-reload environment.

## The Ideal Setup
Instead of waiting for AWS deployments, we run the Go backend and Flutter frontend locally. We expose them on `0.0.0.0` so the user can test the app on their physical phone by navigating to their computer's local IP address.

## How to start it
We have created a dedicated script that automatically:
1. Detects the machine's local IP on the Wi-Fi network.
2. Starts the Go backend with the necessary AWS environment variables.
3. Starts the Flutter web server with `--dart-define=API_BASE_URL` pointing dynamically to the detected IP.

**To run it on behalf of the user:**
1. Execute the script in the background:
   `./scripts/run_dev.sh`
2. Once the script starts, tell the user their local IP and tell them to open `http://<LOCAL_IP>:3000` on their phone.

## Important Configurations Already Handled
- **CORS:** The Go backend (`backend/cmd/api/http_helpers.go`) has been updated to explicitly allow CORS requests from `192.168.x.x` IPs.
- **HTTPS Bypass:** The Flutter app (`mobile/lib/services/api_config.dart`) has been updated to bypass the strict HTTPS requirement when connecting to `192.168.x.x` IPs.
