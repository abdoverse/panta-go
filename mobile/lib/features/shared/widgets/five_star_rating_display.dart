import 'package:flutter/material.dart';

import '../../../core/localization/app_localizations.dart';
import '../../dashboard/widgets/helper_job_card.dart' show formatRatingValue;

/// Visual 5-star rating and feedback display widget for Pickup History views.
///
/// Displays visual 5-star icons (e.g. 4 filled stars out of 5) corresponding to
/// the user's rating moment, along with score badge and feedback comments.
class FiveStarRatingDisplay extends StatelessWidget {
  final double? rating;
  final String? comment;
  final double starSize;
  final bool showScoreBadge;

  const FiveStarRatingDisplay({
    super.key,
    required this.rating,
    this.comment,
    this.starSize = 20.0,
    this.showScoreBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final score = rating ?? 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB), // warm amber tint (amber-50)
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFFDE68A), // amber-200
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...List.generate(5, (index) {
                    final int starValue = index + 1;
                    IconData icon;
                    if (score >= starValue) {
                      icon = Icons.star_rounded;
                    } else if (score >= starValue - 0.5) {
                      icon = Icons.star_half_rounded;
                    } else {
                      icon = Icons.star_outline_rounded;
                    }
                    return Padding(
                      padding: EdgeInsets.only(right: index == 4 ? 0 : 2),
                      child: Icon(
                        icon,
                        size: starSize,
                        color: const Color(0xFFF59E0B), // amber-500
                      ),
                    );
                  }),
                  const SizedBox(width: 6),
                  Text(
                    l10n.ratedValue(
                      rating == null
                          ? l10n.naLabel
                          : formatRatingValue(rating!),
                    ),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFFB45309), // amber-700
                    ),
                  ),
                ],
              ),
              if (showScoreBadge && rating != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7), // amber-100
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFFCD34D), // amber-300
                    ),
                  ),
                  child: Text(
                    '${formatRatingValue(rating!)} / 5',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      color: Color(0xFF92400E), // amber-800
                    ),
                  ),
                ),
            ],
          ),
          if (comment != null && comment!.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '"${comment!.trim()}"',
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade800,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
