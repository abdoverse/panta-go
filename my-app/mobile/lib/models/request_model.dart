enum RequestStatus { pending, accepted, pickedUp }

class RecyclingRequest {
  final String id;
  final String title;
  final String imageUrl;
  final DateTime scheduledFrom;
  final DateTime scheduledTo;
  final String location;
  final RequestStatus status;
  final String? helperId;
  final bool isRated;

  RecyclingRequest({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.scheduledFrom,
    required this.scheduledTo,
    required this.location,
    this.status = RequestStatus.pending,
    this.helperId,
    this.isRated = false,
  });

  RecyclingRequest copyWith({
    RequestStatus? status,
    String? helperId,
    bool? isRated,
  }) {
    return RecyclingRequest(
      id: id,
      title: title,
      imageUrl: imageUrl,
      scheduledFrom: scheduledFrom,
      scheduledTo: scheduledTo,
      location: location,
      status: status ?? this.status,
      helperId: helperId ?? this.helperId,
      isRated: isRated ?? this.isRated,
    );
  }
}
