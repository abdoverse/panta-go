import 'package:flutter/foundation.dart';
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
                  await launchMapApp(
                    context: context,
                    addressOrCoordinates: address,
                    directions: directions,
                    preferAppleMaps: false,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.map_outlined),
                title: Text(context.l10n.appleMaps),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await launchMapApp(
                    context: context,
                    addressOrCoordinates: address,
                    directions: directions,
                    preferAppleMaps: true,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Launches the map app directly using non-browser native intent schemes
  /// (such as `google.navigation:` or `geo:` on Android, `maps://` on iOS)
  /// preventing browser popups or lingering blank web tabs.
  static Future<bool> launchMapApp({
    required BuildContext context,
    required String addressOrCoordinates,
    required bool directions,
    bool preferAppleMaps = false,
  }) async {
    final destination = addressOrCoordinates.trim();
    if (destination.isEmpty) return false;

    bool launched = false;
    final String label = preferAppleMaps
        ? context.l10n.appleMaps
        : context.l10n.googleMaps;

    if (preferAppleMaps) {
      final nativeUri = appleMapsNativeUri(
        queryOrDestination: destination,
        directions: directions,
      );
      final webUri = appleMapsWebUri(
        queryOrDestination: destination,
        directions: directions,
      );

      if (!kIsWeb) {
        if (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS) {
          try {
            if (await canLaunchUrl(nativeUri)) {
              launched = await launchUrl(
                nativeUri,
                mode: LaunchMode.externalNonBrowserApplication,
              );
            }
          } catch (_) {
            launched = false;
          }
        }
      } else {
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          try {
            launched = await launchUrl(
              nativeUri,
              mode: LaunchMode.platformDefault,
              webOnlyWindowName: '_self',
            );
          } catch (_) {
            launched = false;
          }
        }
      }

      if (!launched) {
        try {
          launched = await launchUrl(
            webUri,
            mode: kIsWeb
                ? LaunchMode.platformDefault
                : LaunchMode.externalApplication,
            webOnlyWindowName: kIsWeb ? '_blank' : null,
          );
        } catch (_) {
          launched = false;
        }
      }
    } else {
      final nativeUri = googleMapsNativeUri(
        queryOrDestination: destination,
        directions: directions,
      );
      final webUri = googleMapsWebUri(
        queryOrDestination: destination,
        directions: directions,
      );

      if (!kIsWeb) {
        if (defaultTargetPlatform == TargetPlatform.android) {
          // 1. Try google.navigation: or geo: on Android with externalNonBrowserApplication.
          // This directly switches to Google Maps app without launching Chrome or leaving a blank tab.
          try {
            if (await canLaunchUrl(nativeUri)) {
              launched = await launchUrl(
                nativeUri,
                mode: LaunchMode.externalNonBrowserApplication,
              );
            }
          } catch (_) {
            launched = false;
          }

          // 2. Secondary fallback on Android: geo:0,0?q= (if directions was true and navigation wasn't handled)
          if (!launched && directions) {
            final geoFallback =
                Uri.parse('geo:0,0?q=${Uri.encodeComponent(destination)}');
            try {
              if (await canLaunchUrl(geoFallback)) {
                launched = await launchUrl(
                  geoFallback,
                  mode: LaunchMode.externalNonBrowserApplication,
                );
              }
            } catch (_) {
              launched = false;
            }
          }
        } else if (defaultTargetPlatform == TargetPlatform.iOS) {
          try {
            if (await canLaunchUrl(nativeUri)) {
              launched = await launchUrl(
                nativeUri,
                mode: LaunchMode.externalNonBrowserApplication,
              );
            }
          } catch (_) {
            launched = false;
          }
        }
      } else {
        if (defaultTargetPlatform == TargetPlatform.android) {
          try {
            launched = await launchUrl(
              nativeUri,
              mode: LaunchMode.platformDefault,
              webOnlyWindowName: '_self',
            );
          } catch (_) {
            launched = false;
          }
        }
      }

      // Fallback to web URL if native app wasn't launched
      if (!launched) {
        try {
          launched = await launchUrl(
            webUri,
            mode: kIsWeb
                ? LaunchMode.platformDefault
                : LaunchMode.externalApplication,
            webOnlyWindowName: kIsWeb ? '_blank' : null,
          );
        } catch (_) {
          launched = false;
        }
      }
    }

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.couldNotOpenMap(label))),
      );
    }

    return launched;
  }

  static Uri googleMapsNativeUri({
    required String queryOrDestination,
    required bool directions,
    TargetPlatform? platform,
  }) {
    final targetPlatform = platform ?? defaultTargetPlatform;
    final encoded = Uri.encodeComponent(queryOrDestination);
    if (targetPlatform == TargetPlatform.iOS) {
      return directions
          ? Uri.parse('comgooglemaps://?daddr=$encoded&directionsmode=driving')
          : Uri.parse('comgooglemaps://?q=$encoded');
    }
    return directions
        ? Uri.parse('google.navigation:q=$encoded')
        : Uri.parse('geo:0,0?q=$encoded');
  }

  static Uri googleMapsWebUri({
    required String queryOrDestination,
    required bool directions,
  }) {
    if (directions) {
      return Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': queryOrDestination,
      });
    }
    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': queryOrDestination,
    });
  }

  static Uri appleMapsNativeUri({
    required String queryOrDestination,
    required bool directions,
    TargetPlatform? platform,
  }) {
    final encoded = Uri.encodeComponent(queryOrDestination);
    return directions
        ? Uri.parse('maps://?daddr=$encoded')
        : Uri.parse('maps://?q=$encoded');
  }

  static Uri appleMapsWebUri({
    required String queryOrDestination,
    required bool directions,
  }) {
    return Uri.https(
      'maps.apple.com',
      '/',
      directions
          ? {
              'daddr': queryOrDestination,
              'dirflg': 'd',
            }
          : {
              'q': queryOrDestination,
            },
    );
  }
}
