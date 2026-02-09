# panta

A high-grade recycling application with Flutter and Go.

## 💰 Payment Integration (TODO)

### 🚧 Swish Integration
Real Swish integration requires strict security measures including mutual TLS (mTLS) certificates.
- [ ] Obtain Merchant Test Certificates from Swish.
- [ ] Configure Backend to use mTLS with Swish API (`mss.cpc.getswish.net`).
- [ ] Implement Deep Linking in Flutter (`panta://`) to handle callbacks from the Swish app.

### 🚧 Card Payment
- [ ] Research Stripe or Adyen integration for direct card payments.
- [ ] Implement PCI-compliant card input form.

### 🚧 BankID Integration
Secure user identification and signing.
- [ ] Obtain BankID Test Certificates.
- [ ] Implement Backend support for Swish BankID RP API (Auth/Sign).
- [ ] Handle animated QR codes or deep linking for mobile auto-start.

## 📱 Notifications Support

### ✅ Supported Platforms
*   **Android:** Fully configured and working.
*   **Web:** Fully configured and working (requires VAPID key setup).

### 🚧 iOS Support (TODO)
Push notifications for iOS are currently a work in progress. To enable them, the following steps are required:

1.  **Apple Developer Program:** Enrollment is required ($99/year) to obtain Push Notification certificates.
2.  **Firebase Setup:**
    *   Create an iOS App in the Firebase Console.
    *   Download `GoogleService-Info.plist` and place it in `ios/Runner/`.
    *   Upload the APNs Authentication Key (.p8) to Firebase Console > Project Settings > Cloud Messaging.
3.  **Xcode Configuration:**
    *   Open `ios/Runner.xcworkspace` in Xcode.
    *   Add the **Push Notifications** capability.
    *   Enable **Background Modes** -> **Remote notifications**.

## 📱 Notifications Setup Guide

### 1. Android Setup (Free)
1.  **Firebase Console**:
    *   Go to [console.firebase.google.com](https://console.firebase.google.com/).
    *   Create a new project (e.g., "panta-go").
    *   Click "Add app" -> Select **Android** icon.
    *   **Package name**: Enter `com.abdoverse.panta` (matches `android/app/build.gradle.kts`).
    *   Click "Register app".
2.  **Configuration File**:
    *   Download `google-services.json`.
    *   Place it in: `mobile/android/app/google-services.json`.
3.  **Run**: No other code changes needed. Just run the app!

### 2. Web Setup (Free)
1.  **Firebase Console**:
    *   In Project Overview, click "Add app" -> Select **Web** (</>).
    *   Register app (e.g., "panta-web").
    *   Go to **Project Settings** -> **General** -> "Your apps" -> **SDK Setup and Configuration**.
    *   Copy the `firebaseConfig` object (keys, IDs, etc.).
2.  **Update Code**:
    *   Open `mobile/web/index.html`.
    *   Replace `YOUR_API_KEY`, `YOUR_PROJECT_ID` etc., with your copied values.
    *   Open `mobile/web/firebase-messaging-sw.js`.
    *   Replace the config object there too with the same values.
3.  **VAPID Key**:
    *   In Firebase Console -> **Project Settings** -> **Cloud Messaging** tab.
    *   Scroll to **Web configuration** -> Generate/Copy key pair.
    *   Open `mobile/lib/providers/panta_provider.dart`.
    *   Find the string `"YOUR_VAPID_KEY_HERE"` and paste your key.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
