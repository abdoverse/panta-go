import 'package:flutter/material.dart';

class GlobalDebugBanner extends StatelessWidget {
  final String latestChange;

  const GlobalDebugBanner({
    super.key,
    required this.latestChange,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.1),
          border: const Border(bottom: BorderSide(color: Colors.redAccent)),
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Colors.redAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Latest Change: $latestChange",
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    decoration: TextDecoration.none,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
