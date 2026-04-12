# Copilot instructions for Panta

## Local app runs

- When asked to run the app locally, prefer the Flutter app in `my-app/mobile`.
- Default to the web workflow instead of Android emulators or Linux desktop unless the user explicitly asks for a different target.
- Start the app with:

  ```bash
  cd /home/abdo/Desktop/abdoverse/panta-go/my-app/mobile
  flutter run -d web-server --web-hostname 127.0.0.1 --web-port 3000
  ```

- If the client supports a built-in or embedded browser, open `http://127.0.0.1:3000` there after the server starts.
- If a built-in browser is not available, give the user the local URL directly.

## Target selection notes

- Avoid Android emulators by default on this project because they are heavy on this machine.
- Avoid the Linux desktop target unless the local linker/toolchain issue has been resolved.
