# Persistent Local Stack

The local stack uses the real AWS DynamoDB and S3 data layer. It does not use local storage emulators or in-memory fallbacks.

## Prerequisites

Install AWS CLI, Flutter, and (on Linux) `systemd` user services. Configure a developer-owned AWS profile with access to the `panta-requests` table and `panta-request-images` bucket.

```bash
aws configure --profile panta-local-dev
aws sts get-caller-identity --profile panta-local-dev
```

Never commit `~/.aws/credentials`, access keys, or the Maps key. Restrict the Maps key by API, HTTP referrer, and development origins in Google Cloud Console.

## Install persistent service

From the repository root:

```bash
AWS_PROFILE_NAME=panta-local-dev \
GOOGLE_MAPS_API_KEY=your-key-here \
./panta-dev-loop/scripts/install_local_service.sh
```

The installer renders a user service for the current clone path, enables it, and starts the stack. It survives terminal closure, SSH disconnects, logout (when lingering is available), and Codex sessions.

```bash
systemctl --user status panta-local
systemctl --user restart panta-local
journalctl --user -u panta-local -f
```

The service automatically builds the web bundle with the detected LAN API address. Open the printed LAN URL from a phone on the same network.

To remove it:

```bash
./panta-dev-loop/scripts/uninstall_local_service.sh
```
