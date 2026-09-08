import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/app_localizations.dart';
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
    final l10n = context.l10n;
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
                 label: Text(l10n.getDirections),
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
                    ? context.l10n.chooseMapForDirections
                    : context.l10n.chooseMapApp),
                subtitle: Text(address),
              ),
              ListTile(
                leading: const Icon(Icons.map_rounded),
                title: Text(context.l10n.googleMaps),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _launchMapOption(
                    context,
                    label: context.l10n.googleMaps,
                    uri: _googleMapsUri(directions: directions),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: Text(context.l10n.appleMaps),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _launchMapOption(
                    context,
                    label: context.l10n.appleMaps,
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
      SnackBar(content: Text(context.l10n.couldNotOpenMap(label))),
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
