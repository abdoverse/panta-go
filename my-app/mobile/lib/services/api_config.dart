import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    if (kReleaseMode) {
      return 'https://YOUR_NEW_SERVICE_URL_HERE';
    }
    // Android Emulator uses 10.0.2.2 for localhost
    if (Platform.isAndroid) return 'http://10.0.2.2:8080';
    // iOS Simulator uses localhost
    if (Platform.isIOS) return 'http://127.0.0.1:8080';
    
    return 'http://localhost:8080';
  }
}
