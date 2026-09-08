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

class StreakData {
  final int currentStreakWeeks;
  final int longestStreakWeeks;
  final bool isActive;

  StreakData({
    this.currentStreakWeeks = 0,
    this.longestStreakWeeks = 0,
    this.isActive = false,
  });

  factory StreakData.fromJson(Map<String, dynamic>? json) {
    if (json == null) return StreakData();
    return StreakData(
      currentStreakWeeks: (json['currentStreakWeeks'] as num?)?.toInt() ?? 0,
      longestStreakWeeks: (json['longestStreakWeeks'] as num?)?.toInt() ?? 0,
      isActive: json['isActive'] == true,
    );
  }
}

class EcoBadge {
  final String id;
  final String title;
  final String description;
  final String icon;
  final bool isUnlocked;
  final double progress;
  final int current;
  final int target;

  EcoBadge({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isUnlocked,
    required this.progress,
    required this.current,
    required this.target,
  });

  factory EcoBadge.fromJson(Map<String, dynamic> json) {
    return EcoBadge(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '🌱',
      isUnlocked: json['isUnlocked'] == true,
      progress: (json['progress'] as num?)?.toDouble() ?? 0.0,
      current: (json['current'] as num?)?.toInt() ?? 0,
      target: (json['target'] as num?)?.toInt() ?? 1,
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
  final StreakData streak;
  final List<EcoBadge> badges;
  final List<ImpactActivityItem> recentActivity;

  ImpactSummary({
    required this.totalPickups,
    required this.totalReceiptAmount,
    required this.totalEarnings,
    required this.containersRecycled,
    required this.co2SavedKg,
    required this.treesEquivalent,
    StreakData? streak,
    this.badges = const [],
    this.recentActivity = const [],
  }) : streak = streak ?? StreakData();

  factory ImpactSummary.fromJson(Map<String, dynamic> json) {
    return ImpactSummary(
      totalPickups: (json['totalPickups'] as num?)?.toInt() ?? 0,
      totalReceiptAmount: (json['totalReceiptAmount'] as num?)?.toDouble() ?? 0.0,
      totalEarnings: (json['totalEarnings'] as num?)?.toDouble() ?? 0.0,
      containersRecycled: (json['containersRecycled'] as num?)?.toInt() ?? 0,
      co2SavedKg: (json['co2SavedKg'] as num?)?.toDouble() ?? 0.0,
      treesEquivalent: (json['treesEquivalent'] as num?)?.toDouble() ?? 0.0,
      streak: json['streak'] != null
          ? StreakData.fromJson(json['streak'] as Map<String, dynamic>)
          : null,
      badges: (json['badges'] as List<dynamic>?)
              ?.map((item) => EcoBadge.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
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
    final activeWeeks = <String>{};

    for (final req in requests) {
      if (req.status != RequestStatus.pickedUp) continue;
      count++;
      final receipt = req.receiptAmount ?? 0.0;
      totalReceipt += receipt;

      final earned = isHelper
          ? (req.helperPayout ?? (receipt * (100.0 - req.splitPercentage) / 100.0))
          : (req.recyclerPayout ?? (receipt * req.splitPercentage / 100.0));
      totalEarned += earned;

      final date = req.receiptScannedAt ?? req.scheduledTo;
      final weekKey = '${date.year}-${(date.difference(DateTime(date.year, 1, 1)).inDays / 7).ceil()}';
      activeWeeks.add(weekKey);

      activities.add(ImpactActivityItem(
        id: req.id,
        title: req.title,
        completedAt: date,
        receiptAmount: receipt,
        earnings: earned,
        co2SavedKg: double.parse((receipt * 0.08).toStringAsFixed(2)),
      ));
    }

    final containers = (totalReceipt / 1.5).round();
    final co2 = double.parse((containers * 0.09).toStringAsFixed(2));
    final trees = double.parse((co2 / 21.0).toStringAsFixed(2));

    final streakWeeks = activeWeeks.length;
    final streak = StreakData(
      currentStreakWeeks: streakWeeks,
      longestStreakWeeks: streakWeeks,
      isActive: streakWeeks > 0,
    );

    final badges = [
      EcoBadge(
        id: 'first_step',
        title: 'First Step',
        description: 'Complete your first pant pickup',
        icon: '🌱',
        isUnlocked: count >= 1,
        progress: count >= 1 ? 1.0 : 0.0,
        current: count,
        target: 1,
      ),
      EcoBadge(
        id: 'centurion',
        title: 'Centurion Recycler',
        description: 'Recycle 100+ cans & bottles',
        icon: '🥫',
        isUnlocked: containers >= 100,
        progress: containers >= 100 ? 1.0 : (containers / 100).clamp(0.0, 1.0),
        current: containers,
        target: 100,
      ),
      EcoBadge(
        id: 'carbon_crusher',
        title: 'Carbon Crusher',
        description: 'Offset at least 10 kg of CO₂',
        icon: '🌍',
        isUnlocked: co2 >= 10.0,
        progress: co2 >= 10.0 ? 1.0 : (co2 / 10.0).clamp(0.0, 1.0),
        current: co2.toInt(),
        target: 10,
      ),
      EcoBadge(
        id: 'streak_master',
        title: 'Streak Master',
        description: 'Maintain a 3-week recycling streak',
        icon: '🔥',
        isUnlocked: streakWeeks >= 3,
        progress: streakWeeks >= 3 ? 1.0 : (streakWeeks / 3.0).clamp(0.0, 1.0),
        current: streakWeeks,
        target: 3,
      ),
      EcoBadge(
        id: 'pant_legend',
        title: 'Pant Legend',
        description: 'Complete 10+ recycling pickups',
        icon: '🏆',
        isUnlocked: count >= 10,
        progress: count >= 10 ? 1.0 : (count / 10.0).clamp(0.0, 1.0),
        current: count,
        target: 10,
      ),
      EcoBadge(
        id: 'eco_champion',
        title: 'Eco Champion',
        description: 'Earn/refund over 500 SEK in pant',
        icon: '⚡',
        isUnlocked: totalEarned >= 500.0,
        progress: totalEarned >= 500.0 ? 1.0 : (totalEarned / 500.0).clamp(0.0, 1.0),
        current: totalEarned.toInt(),
        target: 500,
      ),
    ];

    return ImpactSummary(
      totalPickups: count,
      totalReceiptAmount: double.parse(totalReceipt.toStringAsFixed(2)),
      totalEarnings: double.parse(totalEarned.toStringAsFixed(2)),
      containersRecycled: containers,
      co2SavedKg: co2,
      treesEquivalent: trees,
      streak: streak,
      badges: badges,
      recentActivity: activities,
    );
  }
}
