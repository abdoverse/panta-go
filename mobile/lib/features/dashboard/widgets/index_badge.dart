import 'package:flutter/material.dart';

/// Systematic "#" numbering label used uniformly across Recycler and Helper cards.
class IndexBadge extends StatelessWidget {
  final int index;

  const IndexBadge({super.key, required this.index});

  @override
  Widget build(BuildContext context) {
    return Text(
      '#${index + 1}',
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.grey[400],
      ),
    );
  }
}

