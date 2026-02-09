enum RequestStatus { pending, accepted, pickedUp }

class RecyclingRequest {
  final String id;
  final String title;
  final String imageUrl;
  final DateTime scheduledFrom;
  final DateTime scheduledTo;
  final String location;
  final String description;
  final double? reward; // Changed to nullable to safe-guard against hot-reload nulls
  final RequestStatus status;
  final String? helperId;
  final bool isRated;
  final double? rating;
  final String? ratingComment;

  RecyclingRequest({
    required this.id,
    required this.title,
    required this.imageUrl,
    required this.scheduledFrom,
    required this.scheduledTo,
    required this.location,
    this.description = '',
    this.reward = 0.0,
    this.status = RequestStatus.pending,
    this.helperId,
    this.isRated = false,
    this.rating,
    this.ratingComment,
  });

  RecyclingRequest copyWith({
    RequestStatus? status,
    String? helperId,
    bool? isRated,
    double? rating,
    String? ratingComment,
    String? description,
    double? reward,
  }) {
    return RecyclingRequest(
      id: id,
      title: title,
      imageUrl: imageUrl,
      scheduledFrom: scheduledFrom,
      scheduledTo: scheduledTo,
      location: location,
      description: description ?? this.description,
      reward: reward ?? this.reward,
      status: status ?? this.status,
      helperId: helperId ?? this.helperId,
      isRated: isRated ?? this.isRated,
      rating: rating ?? this.rating,
      ratingComment: ratingComment ?? this.ratingComment,
    );
  }
}
