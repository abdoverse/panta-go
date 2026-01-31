import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/panta_provider.dart';
import 'services/api_config.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => PantaProvider()),
      ],
      child: const PantaApp(),
    ),
  );
}
