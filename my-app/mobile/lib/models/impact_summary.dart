import 'request_model.dart';

class ImpactActivityItem {
  final String id;
  final String title;
  final DateTime completedAt;
  final double receiptAmount;
  final double earnings;
  final double co2SavedKg;

  ImpactActivityItem({
    required this.id,
    required this.title,
    required this.completedAt,
    required this.receiptAmount,
    required this.earnings,
    required this.co2SavedKg,
  });

  factory ImpactActivityItem.fromJson(Map<String, dynamic> json) {
    return ImpactActivityItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Pickup',
      completedAt: json['completedAt'] != null
          ? DateTime.tryParse(json['completedAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      receiptAmount: (json['receiptAmount'] as num?)?.toDouble() ?? 0.0,
      earnings: (json['earnings'] as num?)?.toDouble() ?? 0.0,
      co2SavedKg: (json['co2SavedKg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ImpactSummary {
  final int totalPickups;
  final double totalReceiptAmount;
  final double totalEarnings;
  final int containersRecycled;
  final double co2SavedKg;
  final double treesEquivalent;
  final List<ImpactActivityItem> recentActivity;

  ImpactSummary({
    required this.totalPickups,
    required this.totalReceiptAmount,
    required this.totalEarnings,
    required this.containersRecycled,
    required this.co2SavedKg,
    required this.treesEquivalent,
    this.recentActivity = const [],
  });

  factory ImpactSummary.fromJson(Map<String, dynamic> json) {
    return ImpactSummary(
      totalPickups: (json['totalPickups'] as num?)?.toInt() ?? 0,
      totalReceiptAmount: (json['totalReceiptAmount'] as num?)?.toDouble() ?? 0.0,
      totalEarnings: (json['totalEarnings'] as num?)?.toDouble() ?? 0.0,
      containersRecycled: (json['containersRecycled'] as num?)?.toInt() ?? 0,
      co2SavedKg: (json['co2SavedKg'] as num?)?.toDouble() ?? 0.0,
      treesEquivalent: (json['treesEquivalent'] as num?)?.toDouble() ?? 0.0,
      recentActivity: (json['recentActivity'] as List<dynamic>?)
              ?.map((item) => ImpactActivityItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  factory ImpactSummary.fromRequests(List<RecyclingRequest> requests, {bool isHelper = false}) {
    double totalReceipt = 0;
    double totalEarned = 0;
    int count = 0;
    final activities = <ImpactActivityItem>[];

    for (final req in requests) {
      if (req.status != RequestStatus.pickedUp) continue;
      count++;
      final receipt = req.receiptAmount ?? 0.0;
      totalReceipt += receipt;

      final earned = isHelper
          ? (req.helperPayout ?? (receipt * (100.0 - req.splitPercentage) / 100.0))
          : (req.recyclerPayout ?? (receipt * req.splitPercentage / 100.0));
      totalEarned += earned;

      activities.add(ImpactActivityItem(
        id: req.id,
        title: req.title,
        completedAt: req.receiptScannedAt ?? req.scheduledTo,
        receiptAmount: receipt,
        earnings: earned,
        co2SavedKg: double.parse((receipt * 0.08).toStringAsFixed(2)),
      ));
    }

    final containers = (totalReceipt / 1.5).round();
    final co2 = double.parse((containers * 0.09).toStringAsFixed(2));
    final trees = double.parse((co2 / 21.0).toStringAsFixed(2));

    return ImpactSummary(
      totalPickups: count,
      totalReceiptAmount: double.parse(totalReceipt.toStringAsFixed(2)),
      totalEarnings: double.parse(totalEarned.toStringAsFixed(2)),
      containersRecycled: containers,
      co2SavedKg: co2,
      treesEquivalent: trees,
      recentActivity: activities,
    );
  }
}
