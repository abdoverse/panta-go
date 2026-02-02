import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:8080';
    }
    // Android emulator localhost
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080';
    }
    // iOS simulator localhost
    return 'http://localhost:8080';
  }

  // TODO: Replace with real IDs from AWS Deployment
  static const String userPoolId = 'eu-north-1_CUudlgIZ5';
  static const String clientId = '260bj0q7933g1p5glq4c1gv25s';
  static const String region = 'eu-north-1';
}
