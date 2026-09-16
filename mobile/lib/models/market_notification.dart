enum MarketNotificationSeverity {
  info,
  warning,
  critical,
  incident;

  static MarketNotificationSeverity fromString(String? val) {
    switch (val?.toLowerCase().trim()) {
      case 'critical':
        return MarketNotificationSeverity.critical;
      case 'incident':
        return MarketNotificationSeverity.incident;
      case 'info':
        return MarketNotificationSeverity.info;
      case 'warning':
      default:
        return MarketNotificationSeverity.warning;
    }
  }

  String toValue() => name;
}

class MarketNotification {
  final String id;
  final String market;
  final String title;
  final String? titleSv;
  final String message;
  final String? messageSv;
  final MarketNotificationSeverity severity;
  final bool active;
  final bool dismissible;
  final String? actionUrl;
  final String? actionLabel;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const MarketNotification({
    required this.id,
    required this.market,
    required this.title,
    this.titleSv,
    required this.message,
    this.messageSv,
    this.severity = MarketNotificationSeverity.warning,
    this.active = true,
    this.dismissible = true,
    this.actionUrl,
    this.actionLabel,
    this.createdAt,
    this.updatedAt,
  });

  String localizedTitle(bool isSwedish) {
    if (isSwedish && titleSv != null && titleSv!.isNotEmpty) {
      return titleSv!;
    }
    return title;
  }

  String localizedMessage(bool isSwedish) {
    if (isSwedish && messageSv != null && messageSv!.isNotEmpty) {
      return messageSv!;
    }
    return message;
  }

  factory MarketNotification.fromJson(Map<String, dynamic> json) {
    return MarketNotification(
      id: json['id']?.toString() ?? '',
      market: json['market']?.toString() ?? 'ALL',
      title: json['title']?.toString() ?? '',
      titleSv: json['titleSv']?.toString(),
      message: json['message']?.toString() ?? '',
      messageSv: json['messageSv']?.toString(),
      severity:
          MarketNotificationSeverity.fromString(json['severity']?.toString()),
      active: json['active'] == true,
      dismissible: json['dismissible'] != false, // defaults to true
      actionUrl: json['actionUrl']?.toString(),
      actionLabel: json['actionLabel']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'market': market,
      'title': title,
      if (titleSv != null) 'titleSv': titleSv,
      'message': message,
      if (messageSv != null) 'messageSv': messageSv,
      'severity': severity.toValue(),
      'active': active,
      'dismissible': dismissible,
      if (actionUrl != null) 'actionUrl': actionUrl,
      if (actionLabel != null) 'actionLabel': actionLabel,
      if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    };
  }

  MarketNotification copyWith({
    String? id,
    String? market,
    String? title,
    String? titleSv,
    String? message,
    String? messageSv,
    MarketNotificationSeverity? severity,
    bool? active,
    bool? dismissible,
    String? actionUrl,
    String? actionLabel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MarketNotification(
      id: id ?? this.id,
      market: market ?? this.market,
      title: title ?? this.title,
      titleSv: titleSv ?? this.titleSv,
      message: message ?? this.message,
      messageSv: messageSv ?? this.messageSv,
      severity: severity ?? this.severity,
      active: active ?? this.active,
      dismissible: dismissible ?? this.dismissible,
      actionUrl: actionUrl ?? this.actionUrl,
      actionLabel: actionLabel ?? this.actionLabel,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
