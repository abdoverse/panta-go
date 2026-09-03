enum RequestStatus { pending, accepted, pickedUp }

class SavedAddress {
  final String label;
  final String location;
  final double? latitude;
  final double? longitude;

  const SavedAddress({
    required this.label,
    required this.location,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}

class RequestTemplate {
  final String name;
  final String title;
  final String description;
  final double reward;

  const RequestTemplate({
    required this.name,
    required this.title,
    required this.description,
    required this.reward,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'title': title,
      'description': description,
      'reward': reward,
    };
  }
}

class RecyclingRequest {
  final String id;
  final String title;
  final String? imageUrl;
  final DateTime scheduledFrom;
  final DateTime scheduledTo;
  final String location;
  final double? locationLatitude;
  final double? locationLongitude;
  final String description;
  final double?
      reward; // Changed to nullable to safe-guard against hot-reload nulls
  final RequestStatus status;
  final String? helperId;
  final List<String> canceledHelperIds;
  final bool isRated;
  final double? rating;
  final String? ratingComment;
  final String? receiptImageUrl;
  final double? receiptAmount;
  final DateTime? receiptScannedAt;
  final double? helperLatitude;
  final double? helperLongitude;
  final int? etaMinutes;
  final String? milestone;
  final double splitPercentage;
  final double? recyclerPayout;
  final double? helperPayout;
  final bool leaveAtDoor;
  final String? doorInstructions;
  final String? dropoffPhotoUrl;
  final DateTime? dropoffConfirmedAt;

  RecyclingRequest({
    required this.id,
    required this.title,
    this.imageUrl,
    required this.scheduledFrom,
    required this.scheduledTo,
    required this.location,
    this.locationLatitude,
    this.locationLongitude,
    this.description = '',
    this.reward = 0.0,
    this.status = RequestStatus.pending,
    this.helperId,
    this.canceledHelperIds = const [],
    this.isRated = false,
    this.rating,
    this.ratingComment,
    this.receiptImageUrl,
    this.receiptAmount,
    this.receiptScannedAt,
    this.helperLatitude,
    this.helperLongitude,
    this.etaMinutes,
    this.milestone,
    this.splitPercentage = 70.0,
    this.recyclerPayout,
    this.helperPayout,
    this.leaveAtDoor = false,
    this.doorInstructions,
    this.dropoffPhotoUrl,
    this.dropoffConfirmedAt,
  });

  RecyclingRequest copyWith({
    RequestStatus? status,
    String? helperId,
    List<String>? canceledHelperIds,
    bool? isRated,
    double? rating,
    String? ratingComment,
    String? description,
    double? reward,
    double? locationLatitude,
    double? locationLongitude,
    String? receiptImageUrl,
    double? receiptAmount,
    DateTime? receiptScannedAt,
    double? helperLatitude,
    double? helperLongitude,
    int? etaMinutes,
    String? milestone,
    double? splitPercentage,
    double? recyclerPayout,
    double? helperPayout,
    bool? leaveAtDoor,
    String? doorInstructions,
    String? dropoffPhotoUrl,
    DateTime? dropoffConfirmedAt,
  }) {
    return RecyclingRequest(
      id: id,
      title: title,
      imageUrl: imageUrl,
      scheduledFrom: scheduledFrom,
      scheduledTo: scheduledTo,
      location: location,
      locationLatitude: locationLatitude ?? this.locationLatitude,
      locationLongitude: locationLongitude ?? this.locationLongitude,
      description: description ?? this.description,
      reward: reward ?? this.reward,
      status: status ?? this.status,
      helperId: helperId ?? this.helperId,
      canceledHelperIds: canceledHelperIds ?? this.canceledHelperIds,
      isRated: isRated ?? this.isRated,
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
      receiptImageUrl: receiptImageUrl ?? this.receiptImageUrl,
      receiptAmount: receiptAmount ?? this.receiptAmount,
      receiptScannedAt: receiptScannedAt ?? this.receiptScannedAt,
      helperLatitude: helperLatitude ?? this.helperLatitude,
      helperLongitude: helperLongitude ?? this.helperLongitude,
      etaMinutes: etaMinutes ?? this.etaMinutes,
      milestone: milestone ?? this.milestone,
      splitPercentage: splitPercentage ?? this.splitPercentage,
      recyclerPayout: recyclerPayout ?? this.recyclerPayout,
      helperPayout: helperPayout ?? this.helperPayout,
      leaveAtDoor: leaveAtDoor ?? this.leaveAtDoor,
      doorInstructions: doorInstructions ?? this.doorInstructions,
      dropoffPhotoUrl: dropoffPhotoUrl ?? this.dropoffPhotoUrl,
      dropoffConfirmedAt: dropoffConfirmedAt ?? this.dropoffConfirmedAt,
    );
  }

  bool get hasImage {
    final value = imageUrl?.trim();
    return value != null &&
        value.isNotEmpty &&
        value != 'assets/images/generic.png';
  }
}
