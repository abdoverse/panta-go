import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart'; // Import messaging
import 'package:intl/date_symbol_data_local.dart'; // Add this import
import 'dart:ui';
import 'app.dart';
import 'core/localization/app_localizations.dart';
import 'providers/panta_provider.dart';
import 'firebase_options.dart'; // Import the new options file
import 'services/remote_logger.dart';

// Background handler (must be top-level)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Use the options from our new file
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  for (final locale in AppLocalizations.supportedLocales) {
    final localeName = locale.languageCode == 'sv' ? 'sv_SE' : 'en_US';
    await initializeDateFormatting(localeName, null);
  }

  try {
    // Pass the options here as well
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Set foreground presentation options (iOS mainly)
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );
  } catch (e) {
    debugPrint("Firebase init failed (missing config?): $e");
  }

  RemoteLogger.runWithLogger(() {
    // Keep this inside the runner to test if logs are caught
    debugPrint("====== PANTA FLUTTER WEB STARTING UP (ZONED) ======");
    print("====== THIS IS A RAW PRINT STATEMENT ======");
    
    // We cannot easily await inside runWithLogger unless we change it to async,
    // but runZonedGuarded handles async microtasks perfectly fine.
    // However, runApp is synchronous.
    // The safest way is to do the async init *before* runWithLogger, 
    // and then call runWithLogger just for runApp.
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => PantaProvider()),
        ],
        child: const PantaApp(),
      ),
    );
  });
}
