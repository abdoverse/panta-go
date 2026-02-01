import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // Add this
import 'app.dart';
import 'providers/panta_provider.dart';
import 'services/api_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // User must add google-services.json (Android) and GoogleService-Info.plist (iOS)
    await Firebase.initializeApp();
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
