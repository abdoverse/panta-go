import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConfig {
  static String get baseUrl {
    // Using the remote backend for real integration test
    return 'http://InfraS-Panta-ANti8qT1Cybj-1735811194.eu-north-1.elb.amazonaws.com';
  }

  // TODO: Replace with real IDs from AWS Deployment
  static const String userPoolId = 'eu-north-1_CUudlgIZ5';
  static const String clientId = '260bj0q7933g1p5glq4c1gv25s';
  static const String region = 'eu-north-1';
}
