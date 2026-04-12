import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';

class LocationActions extends StatelessWidget {
  final String address;
  final bool showDirections;

  const LocationActions({
    super.key,
    required this.address,
    this.showDirections = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showMapChooser(context, directions: false),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.location_on,
                    size: 18,
                    color: AppTheme.primaryGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    address,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryGreen,
                          decoration: TextDecoration.underline,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (showDirections)
              OutlinedButton.icon(
                onPressed: () => _showMapChooser(context, directions: true),
                icon: const Icon(Icons.directions_outlined),
                label: const Text('Get directions'),
              ),
          ],
        ),
      ],
    );
  }

  Future<void> _showMapChooser(
    BuildContext context, {
    required bool directions,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(directions
                    ? 'Choose map for directions'
                    : 'Choose map app'),
                subtitle: Text(address),
              ),
              ListTile(
                leading: const Icon(Icons.map_rounded),
                title: const Text('Google Maps'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _launchMapOption(
                    context,
                    label: 'Google Maps',
                    uri: _googleMapsUri(directions: directions),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: const Text('Apple Maps'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _launchMapOption(
                    context,
                    label: 'Apple Maps',
                    uri: _appleMapsUri(directions: directions),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchMapOption(
    BuildContext context, {
    required String label,
    required Uri uri,
  }) async {
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted || launched) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open $label for this address.')),
    );
  }

  Uri _googleMapsUri({required bool directions}) {
    if (directions) {
      return Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': address,
      });
    }
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': address,
    });
  }

  Uri _appleMapsUri({required bool directions}) {
    return Uri.https(
        'maps.apple.com',
        '/',
        directions
            ? {
                'daddr': address,
                'dirflg': 'd',
              }
            : {
                'q': address,
              });
  }
}
