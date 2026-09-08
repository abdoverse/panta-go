import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'api_config.dart';

class BankIdInitiateResponse {
  final String orderRef;
  final String autoStartToken;
  final String qrCode;
  final String status;

  BankIdInitiateResponse({
    required this.orderRef,
    required this.autoStartToken,
    required this.qrCode,
    required this.status,
  });

  factory BankIdInitiateResponse.fromJson(Map<String, dynamic> json) {
    return BankIdInitiateResponse(
      orderRef: json['orderRef']?.toString() ?? '',
      autoStartToken: json['autoStartToken']?.toString() ?? '',
      qrCode: json['qrCode']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
    );
  }
}

class BankIdCollectResponse {
  final String orderRef;
  final String status; // pending, complete, failed
  final String? hintCode; // outstandingTransaction, userSign, complete
  final String? token;
  final String? personalNumber;
  final String? name;
  final bool bankIdVerified;
  final String? bankIdVerifiedAt;

  BankIdCollectResponse({
    required this.orderRef,
    required this.status,
    this.hintCode,
    this.token,
    this.personalNumber,
    this.name,
    this.bankIdVerified = false,
    this.bankIdVerifiedAt,
  });

  bool get isComplete => status == 'complete';
  bool get isPending => status == 'pending';

  factory BankIdCollectResponse.fromJson(Map<String, dynamic> json) {
    return BankIdCollectResponse(
      orderRef: json['orderRef']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      hintCode: json['hintCode']?.toString(),
      token: json['token']?.toString(),
      personalNumber: json['personalNumber']?.toString(),
      name: json['name']?.toString(),
      bankIdVerified: json['bankIdVerified'] == true,
      bankIdVerifiedAt: json['bankIdVerifiedAt']?.toString(),
    );
  }
}

class BankIdVerificationStatus {
  final bool bankIdVerified;
  final String? personalNumber;
  final String? verifiedAt;
  final String? displayName;
  final String? role;

  BankIdVerificationStatus({
    required this.bankIdVerified,
    this.personalNumber,
    this.verifiedAt,
    this.displayName,
    this.role,
  });

  factory BankIdVerificationStatus.fromJson(Map<String, dynamic> json) {
    return BankIdVerificationStatus(
      bankIdVerified: json['bankIdVerified'] == true,
      personalNumber: json['bankIdPersonalNumber']?.toString(),
      verifiedAt: json['bankIdVerifiedAt']?.toString(),
      displayName: json['displayName']?.toString(),
      role: json['role']?.toString(),
    );
  }
}

class BankIdService {
  final http.Client _client;

  BankIdService({http.Client? client}) : _client = client ?? http.Client();

  Future<BankIdInitiateResponse?> initiate({
    String? personalNumber,
    required String role,
    String? displayName,
  }) async {
    try {
      final response = await _client.post(
        ApiConfig.apiUri('/api/v1/auth/bankid/initiate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          if (personalNumber != null && personalNumber.isNotEmpty)
            'personalNumber': personalNumber,
          'role': role,
          if (displayName != null && displayName.isNotEmpty)
            'displayName': displayName,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return BankIdInitiateResponse.fromJson(data);
      }
      debugPrint('BankID initiate failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Error initiating BankID: $e');
    }
    return null;
  }

  Future<BankIdCollectResponse?> collect({required String orderRef}) async {
    try {
      final response = await _client.post(
        ApiConfig.apiUri('/api/v1/auth/bankid/collect'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'orderRef': orderRef}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return BankIdCollectResponse.fromJson(data);
      }
      debugPrint('BankID collect failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Error collecting BankID status: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> verifyUser({
    required String token,
    String? orderRef,
    String? personalNumber,
  }) async {
    try {
      final response = await _client.post(
        ApiConfig.apiUri('/api/v1/users/verify-bankid'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          if (orderRef != null) 'orderRef': orderRef,
          if (personalNumber != null) 'personalNumber': personalNumber,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      debugPrint('BankID verify user failed: ${response.statusCode} ${response.body}');
    } catch (e) {
      debugPrint('Error verifying user with BankID: $e');
    }
    return null;
  }

  Future<BankIdVerificationStatus?> getVerificationStatus({
    required String token,
  }) async {
    try {
      final response = await _client.get(
        ApiConfig.apiUri('/api/v1/users/verification-status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return BankIdVerificationStatus.fromJson(data);
      }
      debugPrint('BankID get status failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error getting BankID verification status: $e');
    }
    return null;
  }
}
