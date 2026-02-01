// Give the service worker access to Firebase Messaging.
// Note: You must allow firebase to be loaded from external URL
importScripts("https://www.gstatic.com/firebasejs/9.0.0/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/9.0.0/firebase-messaging-compat.js");

// Initialize the Firebase app in the service worker by passing in
// your app's Firebase config object.
// https://firebase.google.com/docs/web/setup#config-object
firebase.initializeApp({
  apiKey: "AIzaSyAn1WrZmsT3uDV4N8zDQZ3DIFziCcBzRZg",
  authDomain: "panta-3dc75.firebaseapp.com",
  projectId: "panta-3dc75",
  storageBucket: "panta-3dc75.firebasestorage.app",
  messagingSenderId: "504471880267",
  appId: "1:504471880267:web:6a66aff5779318b60083ce",
});

// Retrieve an instance of Firebase Messaging so that it can handle background
// messages.
const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  console.log("[firebase-messaging-sw.js] Received background message ", payload);
  // Customize notification here
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: "/icons/Icon-192.png", // Use your app icon
  };

  self.registration.showNotification(notificationTitle, notificationOptions);
});
