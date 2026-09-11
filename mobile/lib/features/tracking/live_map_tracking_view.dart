import 'package:flutter/material.dart';
import '../../../core/localization/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme/app_theme.dart';
import '../../models/request_model.dart';
import '../../services/eta_service.dart';

class LiveMapTrackingView extends StatefulWidget {
  final RecyclingRequest request;
  final bool isHelperView;
  final Function(double lat, double lng, int eta, String milestone)?
      onLocationSimulated;

  const LiveMapTrackingView({
    super.key,
    required this.request,
    this.isHelperView = false,
    this.onLocationSimulated,
  });

  @override
  State<LiveMapTrackingView> createState() => _LiveMapTrackingViewState();
}

class _LiveMapTrackingViewState extends State<LiveMapTrackingView> {
  // Coordinate defaults (Stockholm center if not specified)
  late double _pickupLat;
  late double _pickupLng;
  late double _helperLat;
  late double _helperLng;

  @override
  void initState() {
    super.initState();
    _pickupLat = widget.request.locationLatitude ?? 59.3293;
    _pickupLng = widget.request.locationLongitude ?? 18.0686;
    _helperLat = widget.request.helperLatitude ?? (_pickupLat + 0.012);
    _helperLng = widget.request.helperLongitude ?? (_pickupLng + 0.014);
  }

  Future<void> _openExternalMaps() async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$_pickupLat,$_pickupLng',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  void _stepSimulation() {
    // Move helper 25% closer to pickup
    setState(() {
      _helperLat = _helperLat + (_pickupLat - _helperLat) * 0.35;
      _helperLng = _helperLng + (_pickupLng - _helperLng) * 0.35;
    });

    final eta = EtaService.computeEta(
      helperLat: _helperLat,
      helperLng: _helperLng,
      pickupLat: _pickupLat,
      pickupLng: _pickupLng,
    );

    if (widget.onLocationSimulated != null) {
      widget.onLocationSimulated!(
        _helperLat,
        _helperLng,
        eta.etaMinutes,
        EtaService.milestoneToString(eta.milestone),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final etaInfo = EtaService.computeEta(
      helperLat: _helperLat,
      helperLng: _helperLng,
      pickupLat: _pickupLat,
      pickupLng: _pickupLng,
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 220,
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(
                  (_pickupLat + _helperLat) / 2,
                  (_pickupLng + _helperLng) / 2,
                ),
                zoom: 12.8,
              ),
              markers: {
                Marker(
                  markerId: const MarkerId('pickup'),
                  position: LatLng(_pickupLat, _pickupLng),
                  infoWindow: const InfoWindow(title: 'Pickup location'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueRed,
                  ),
                ),
                Marker(
                  markerId: const MarkerId('helper'),
                  position: LatLng(_helperLat, _helperLng),
                  infoWindow: const InfoWindow(title: 'Helper'),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                    BitmapDescriptor.hueGreen,
                  ),
                ),
              },
              polylines: {
                Polyline(
                  polylineId: const PolylineId('helper-to-pickup'),
                  points: [
                    LatLng(_helperLat, _helperLng),
                    LatLng(_pickupLat, _pickupLng),
                  ],
                  color: AppTheme.primaryGreen,
                  width: 5,
                ),
              },
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              myLocationButtonEnabled: false,
              compassEnabled: false,
            ),
          ),
          // Milestone Stepper & Actions
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      etaInfo.statusText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openExternalMaps,
                      icon: const Icon(Icons.navigation_outlined, size: 16),
                      label: Text(context.l10n.openMaps,
                          style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Stepper Row
                Row(
                  children: [
                    _MilestoneStep(
                      title: 'On way',
                      isCompleted: true,
                      isActive: etaInfo.milestone == DeliveryMilestone.onTheWay,
                    ),
                    _MilestoneConnector(
                      isCompleted:
                          etaInfo.milestone == DeliveryMilestone.arrivingSoon ||
                              etaInfo.milestone == DeliveryMilestone.arrived,
                    ),
                    _MilestoneStep(
                      title: 'Near (<1km)',
                      isCompleted:
                          etaInfo.milestone == DeliveryMilestone.arrivingSoon ||
                              etaInfo.milestone == DeliveryMilestone.arrived,
                      isActive:
                          etaInfo.milestone == DeliveryMilestone.arrivingSoon,
                    ),
                    _MilestoneConnector(
                      isCompleted:
                          etaInfo.milestone == DeliveryMilestone.arrived,
                    ),
                    _MilestoneStep(
                      title: 'Arrived',
                      isCompleted:
                          etaInfo.milestone == DeliveryMilestone.arrived,
                      isActive: etaInfo.milestone == DeliveryMilestone.arrived,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Helper Simulation Button
                OutlinedButton.icon(
                  onPressed: _stepSimulation,
                  icon: const Icon(Icons.play_arrow, size: 16),
                  label: const Text('Simulate Helper GPS Movement (Test ETA)'),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: AppTheme.primaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneStep extends StatelessWidget {
  final String title;
  final bool isCompleted;
  final bool isActive;

  const _MilestoneStep({
    required this.title,
    required this.isCompleted,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: isCompleted ? AppTheme.primaryGreen : Colors.grey.shade300,
            shape: BoxShape.circle,
            border: isActive ? Border.all(color: Colors.white, width: 2) : null,
          ),
          child: isCompleted
              ? const Icon(Icons.check, size: 12, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isCompleted ? Colors.black87 : Colors.grey,
          ),
        ),
      ],
    );
  }
}

class _MilestoneConnector extends StatelessWidget {
  final bool isCompleted;

  const _MilestoneConnector({required this.isCompleted});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 3,
        margin: const EdgeInsets.only(bottom: 16, left: 4, right: 4),
        color: isCompleted ? AppTheme.primaryGreen : Colors.grey.shade300,
      ),
    );
  }
}
