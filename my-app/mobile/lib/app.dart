import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'features/auth/login_page.dart';
import 'providers/panta_provider.dart';

class PantaApp extends StatefulWidget {
  const PantaApp({super.key});

  @override
  State<PantaApp> createState() => _PantaAppState();
}

class _PantaAppState extends State<PantaApp> {
  final GlobalKey<ScaffoldMessengerState> snackbarKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _setupForegroundMessaging();
  }

  void _setupForegroundMessaging() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Got a message whilst in the foreground!');
      debugPrint('Message data: ${message.data}');

      RemoteNotification? notification = message.notification;

      if (notification != null) {
        final l10n = context.l10n;
        debugPrint(
            'Message also contained a notification: ${notification.title}');
        // Show SnackBar for any notification payload in foreground
        // Use a slight delay to ensure key is mounted if called extremely early (unlikely here but safe)
        if (snackbarKey.currentState != null) {
          snackbarKey.currentState!.showSnackBar(
            SnackBar(
              content: Text(
                  '${notification.title ?? l10n.notificationFallbackTitle}: ${notification.body ?? ""}'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: l10n.viewAction,
                textColor: Colors.white,
                onPressed: () {},
              ),
            ),
          );
        } else {
          debugPrint("Snackbar key current state is null!");
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider?>();

    return MaterialApp(
      scaffoldMessengerKey: snackbarKey,
      title: 'Panta',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const LoginPage(),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: provider?.locale ?? AppLocalizations.supportedLocales.first,
    );
  }
}
