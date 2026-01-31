import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    // Using the remote backend for real integration test
    return 'http://InfraS-Panta-ANti8qT1Cybj-1735811194.eu-north-1.elb.amazonaws.com';
  }
}
