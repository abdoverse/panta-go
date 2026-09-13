import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';

/// Systematic circular numbering badge used uniformly across Recycler and Helper cards.
class IndexBadge extends StatelessWidget {
  final int index;

  const IndexBadge({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          '${index + 1}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryGreen,
          ),
        ),
      ),
    );
  }
}


