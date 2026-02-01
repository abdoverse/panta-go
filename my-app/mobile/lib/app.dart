import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/login_page.dart';

class PantaApp extends StatefulWidget {
  const PantaApp({super.key});

  @override
  State<PantaApp> createState() => _PantaAppState();
}

class _PantaAppState extends State<PantaApp> {
  final GlobalKey<ScaffoldMessengerState> snackbarKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _setupForegroundMessaging();
  }

  void _setupForegroundMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      RemoteNotification? notification = message.notification;

      if (notification != null) {
        // Show SnackBar for any notification payload in foreground
        snackbarKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('${notification.title ?? "Notification"}: ${notification.body ?? ""}'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'VIEW',
              textColor: Colors.white,
              onPressed: () {
                // Handle tap logic if needed
              },
            ),
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: snackbarKey,
      title: 'Panta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginPage(),
    );
  }
}
