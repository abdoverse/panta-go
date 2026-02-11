import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Import messaging
import 'package:intl/date_symbol_data_local.dart'; // Add this import
import 'app.dart';
import 'providers/panta_provider.dart';
import 'services/api_config.dart';
import 'firebase_options.dart'; // Import the new options file
import 'core/constants/app_constants.dart'; // Import AppConstants

// Background handler (must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Use the options from our new file
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting(AppConstants.defaultLocaleId, null); // Initialize default locale

  try {
    // Pass the options here as well
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Set foreground presentation options (iOS mainly)
    await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  } catch (e) {
    debugPrint("Firebase init failed (missing config?): $e");
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PantaProvider()),
      ],
      child: const PantaApp(),
    ),
  );
}
