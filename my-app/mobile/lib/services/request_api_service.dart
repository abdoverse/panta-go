import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/chat_message.dart';
import '../models/request_model.dart';
import 'api_config.dart';

class RequestApiService {
  final http.Client _client;

  RequestApiService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<RecyclingRequest>> fetchRequests({required String token}) async {
    try {
      final response = await _client.get(
        ApiConfig.apiUri('/api/v1/requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data
            .whereType<Map<String, dynamic>>()
            .map(parseRecyclingRequest)
            .toList();
      }
      debugPrint('Failed to load requests: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error fetching requests: $e');
    }
    return [];
  }

  Future<String?> uploadRequestImage({
    required String token,
    required Uint8List imageBytes,
    required String fileName,
    required String mimeType,
  }) async {
    final request = http.MultipartRequest(
      'POST',
      ApiConfig.apiUri('/api/v1/uploads/request-image'),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.files.add(
      http.MultipartFile.fromBytes(
        'file',
        imageBytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ),
    );

    try {
      final streamedResponse = await _client.send(request);
      final response = await http.Response.fromStream(streamedResponse);
      if (response.statusCode == 201) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        return payload['uploadKey'] as String?;
      }
      debugPrint(
        'Failed to upload request image: ${response.statusCode} ${response.body}',
      );
    } catch (e) {
      debugPrint('Error uploading request image: $e');
    }
    return null;
  }

  Future<bool> createRequest({
    required String token,
    required String title,
    required DateTime from,
    required DateTime to,
    required String location,
    double? locationLatitude,
    double? locationLongitude,
    String description = '',
    double reward = 0.0,
    double splitPercentage = 70.0,
    bool leaveAtDoor = false,
    String? doorInstructions,
    String? imageUploadKey,
    String? fcmToken,
  }) async {
    final body = json.encode({
      'title': title,
      'scheduledFrom': from.toUtc().toIso8601String(),
      'scheduledTo': to.toUtc().toIso8601String(),
      'location': location,
      'locationLatitude': locationLatitude,
      'locationLongitude': locationLongitude,
      'description': description,
      'reward': reward,
      'splitPercentage': splitPercentage,
      'leaveAtDoor': leaveAtDoor,
      'doorInstructions': doorInstructions,
      'imageUrl': null,
      'imageUploadKey': imageUploadKey,
      'isRated': false,
      'creatorDeviceToken': fcmToken,
    });

    try {
      final response = await _client.post(
        ApiConfig.apiUri('/api/v1/requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );
      return response.statusCode == 201;
    } catch (e) {
      debugPrint('Error creating request: $e');
      return false;
    }
  }

  Future<RecyclingRequest?> acceptRequest({
    required String token,
    required String id,
  }) async {
    try {
      final response = await _client.post(
        ApiConfig.apiUri('/api/v1/requests/accept'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'id': id}),
      );
      if (response.statusCode == 200) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        return parseRecyclingRequest(payload);
      }
    } catch (e) {
      debugPrint('Error accepting request: $e');
    }
    return null;
  }

  Future<RecyclingRequest?> completeRequest({
    required String token,
    required String id,
    double? receiptAmount,
    String? receiptImageUrl,
    double? splitPercentage,
    String? dropoffPhotoUrl,
  }) async {
    try {
      final bodyMap = <String, dynamic>{'id': id};
      if (receiptAmount != null && receiptAmount > 0) {
        bodyMap['receiptAmount'] = receiptAmount;
      }
      if (receiptImageUrl != null && receiptImageUrl.isNotEmpty) {
        bodyMap['receiptImageUrl'] = receiptImageUrl;
      }
      if (splitPercentage != null && splitPercentage > 0) {
        bodyMap['splitPercentage'] = splitPercentage;
      }
      if (dropoffPhotoUrl != null && dropoffPhotoUrl.isNotEmpty) {
        bodyMap['dropoffPhotoUrl'] = dropoffPhotoUrl;
      }

      final response = await _client.post(
        ApiConfig.apiUri('/api/v1/requests/complete'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(bodyMap),
      );
      if (response.statusCode == 200) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        return parseRecyclingRequest(payload);
      }
    } catch (e) {
      debugPrint('Error completing request: $e');
    }
    return null;
  }

  Future<RecyclingRequest?> cancelRequest({
    required String token,
    required String id,
  }) async {
    try {
      final response = await _client.post(
        ApiConfig.apiUri('/api/v1/requests/cancel'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'id': id}),
      );
      if (response.statusCode == 200) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        return parseRecyclingRequest(payload);
      }
    } catch (e) {
      debugPrint('Error canceling request: $e');
    }
    return null;
  }

  Future<RecyclingRequest?> markArrivedAtDoor({
    required String token,
    required String id,
  }) async {
    try {
      final response = await _client.post(
        ApiConfig.apiUri('/api/v1/requests/arrived'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({'id': id}),
      );
      if (response.statusCode == 200) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        return parseRecyclingRequest(payload);
      }
    } catch (e) {
      debugPrint('Error marking arrived at door: $e');
    }
    return null;
  }

  Future<RecyclingRequest?> updateHelperLocation({
    required String token,
    required String id,
    required double lat,
    required double lng,
    int? etaMinutes,
    String? milestone,
  }) async {
    try {
      final bodyMap = <String, dynamic>{
        'id': id,
        'helperLatitude': lat,
        'helperLongitude': lng,
      };
      if (etaMinutes != null) bodyMap['etaMinutes'] = etaMinutes;
      if (milestone != null) bodyMap['milestone'] = milestone;

      final response = await _client.post(
        ApiConfig.apiUri('/api/v1/requests/location'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode(bodyMap),
      );
      if (response.statusCode == 200) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        return parseRecyclingRequest(payload);
      }
    } catch (e) {
      debugPrint('Error updating helper location: $e');
    }
    return null;
  }

  Future<bool> rateHelper({
    required String token,
    required String id,
    required double rating,
    String? comment,
  }) async {
    try {
      final response = await _client.post(
        ApiConfig.apiUri('/api/v1/requests/rate'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'id': id,
          'rating': rating,
          'comment': comment ?? '',
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error rating helper: $e');
      return false;
    }
  }

  Future<List<SavedAddress>> fetchSavedAddresses({
    required String token,
  }) async {
    try {
      final response = await _client.get(
        ApiConfig.apiUri('/api/v1/requests/saved-addresses'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        final items = payload['savedAddresses'] as List<dynamic>? ?? const [];
        return items
            .whereType<Map>()
            .map(
              (item) => parseSavedAddress(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading saved addresses: $e');
    }
    return [];
  }

  Future<List<RequestTemplate>> fetchRequestTemplates({
    required String token,
  }) async {
    try {
      final response = await _client.get(
        ApiConfig.apiUri('/api/v1/requests/templates'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final payload = json.decode(response.body) as Map<String, dynamic>;
        final items = payload['templates'] as List<dynamic>? ?? const [];
        return items
            .whereType<Map>()
            .map(
              (item) => parseRequestTemplate(
                item.map((key, value) => MapEntry(key.toString(), value)),
              ),
            )
            .toList();
      }
    } catch (e) {
      debugPrint('Error loading request templates: $e');
    }
    return [];
  }

  Future<bool> saveSavedAddresses({
    required String token,
    required List<SavedAddress> addresses,
  }) async {
    try {
      final response = await _client.put(
        ApiConfig.apiUri('/api/v1/requests/saved-addresses'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'savedAddresses':
              addresses.map((item) => item.toJson()).toList(growable: false),
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error saving addresses: $e');
      return false;
    }
  }

  Future<bool> saveRequestTemplates({
    required String token,
    required List<RequestTemplate> templates,
  }) async {
    try {
      final response = await _client.put(
        ApiConfig.apiUri('/api/v1/requests/templates'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'templates':
              templates.map((item) => item.toJson()).toList(growable: false),
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error saving templates: $e');
      return false;
    }
  }

  // --- Parser Utilities ---

  static RecyclingRequest parseRecyclingRequest(Map<String, dynamic> json) {
    return RecyclingRequest(
      id: json['id'],
      title: json['title'],
      imageUrl: parseImageUrl(json['imageUrl']),
      scheduledFrom: DateTime.parse(json['scheduledFrom']),
      scheduledTo: DateTime.parse(json['scheduledTo']),
      location: json['location'],
      locationLatitude: json['locationLatitude'] != null
          ? double.tryParse(json['locationLatitude'].toString())
          : null,
      locationLongitude: json['locationLongitude'] != null
          ? double.tryParse(json['locationLongitude'].toString())
          : null,
      description: json['description'] ?? '',
      reward: json['reward'] != null
          ? double.tryParse(json['reward'].toString()) ?? 0.0
          : 0.0,
      status: parseStatus(json['status']),
      helperId: json['helperId'],
      canceledHelperIds: (json['canceledHelperIds'] as List<dynamic>?)
              ?.map((item) => item.toString())
              .toList(growable: false) ??
          const [],
      isRated: json['isRated'] ?? false,
      rating: json['rating'] != null
          ? double.tryParse(json['rating'].toString())
          : null,
      ratingComment: json['ratingComment'],
      receiptImageUrl: json['receiptImageUrl']?.toString(),
      receiptAmount: json['receiptAmount'] != null
          ? double.tryParse(json['receiptAmount'].toString())
          : null,
      receiptScannedAt: json['receiptScannedAt'] != null
          ? DateTime.tryParse(json['receiptScannedAt'].toString())
          : null,
      helperLatitude: json['helperLatitude'] != null
          ? double.tryParse(json['helperLatitude'].toString())
          : null,
      helperLongitude: json['helperLongitude'] != null
          ? double.tryParse(json['helperLongitude'].toString())
          : null,
      etaMinutes: json['etaMinutes'] != null
          ? int.tryParse(json['etaMinutes'].toString())
          : null,
      milestone: json['milestone']?.toString(),
      splitPercentage: json['splitPercentage'] != null
          ? double.tryParse(json['splitPercentage'].toString()) ?? 70.0
          : 70.0,
      recyclerPayout: json['recyclerPayout'] != null
          ? double.tryParse(json['recyclerPayout'].toString())
          : null,
      helperPayout: json['helperPayout'] != null
          ? double.tryParse(json['helperPayout'].toString())
          : null,
      leaveAtDoor: json['leaveAtDoor'] == true,
      doorInstructions: json['doorInstructions']?.toString(),
      dropoffPhotoUrl: json['dropoffPhotoUrl']?.toString(),
      dropoffConfirmedAt: json['dropoffConfirmedAt'] != null
          ? DateTime.tryParse(json['dropoffConfirmedAt'].toString())
          : null,
      arrivedAtDoor: json['arrivedAtDoor'] != null
          ? DateTime.tryParse(json['arrivedAtDoor'].toString())
          : null,
      messages: (json['messages'] as List<dynamic>?)
              ?.map((m) => ChatMessage.fromJson(m as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  static RequestStatus parseStatus(String status) {
    switch (status) {
      case 'accepted':
        return RequestStatus.accepted;
      case 'pickedUp':
        return RequestStatus.pickedUp;
      default:
        return RequestStatus.pending;
    }
  }

  static String? parseImageUrl(dynamic value) {
    final imageUrl = value?.toString().trim();
    if (imageUrl == null ||
        imageUrl.isEmpty ||
        imageUrl == 'assets/images/generic.png') {
      return null;
    }
    return imageUrl;
  }

  static SavedAddress parseSavedAddress(Map<String, dynamic> json) {
    return SavedAddress(
      label: (json['label'] ?? json['location'] ?? '').toString(),
      location: (json['location'] ?? '').toString(),
      latitude: json['latitude'] != null
          ? double.tryParse(json['latitude'].toString())
          : null,
      longitude: json['longitude'] != null
          ? double.tryParse(json['longitude'].toString())
          : null,
    );
  }

  static RequestTemplate parseRequestTemplate(Map<String, dynamic> json) {
    return RequestTemplate(
      name: (json['name'] ?? json['title'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      reward: json['reward'] != null
          ? double.tryParse(json['reward'].toString()) ?? 0.0
          : 0.0,
    );
  }
}
