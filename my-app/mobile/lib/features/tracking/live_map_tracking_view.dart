import 'dart:math';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../models/request_model.dart';
import '../../services/eta_service.dart';

class LiveMapTrackingView extends StatefulWidget {
  final RecyclingRequest request;
  final bool isHelperView;
  final Function(double lat, double lng, int eta, String milestone)? onLocationSimulated;

  const LiveMapTrackingView({
    super.key,
    required this.request,
    this.isHelperView = false,
    this.onLocationSimulated,
  });

  @override
  State<LiveMapTrackingView> createState() => _LiveMapTrackingViewState();
}

class _LiveMapTrackingViewState extends State<LiveMapTrackingView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Coordinate defaults (Stockholm center if not specified)
  late double _pickupLat;
  late double _pickupLng;
  late double _helperLat;
  late double _helperLng;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pickupLat = widget.request.locationLatitude ?? 59.3293;
    _pickupLng = widget.request.locationLongitude ?? 18.0686;
    _helperLat = widget.request.helperLatitude ?? (_pickupLat + 0.012);
    _helperLng = widget.request.helperLongitude ?? (_pickupLng + 0.014);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
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
          // Visual Map Area
          Container(
            height: 180,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE5F4EC), Color(0xFFD3EDE0)],
              ),
            ),
            child: Stack(
              children: [
                // Stylized map grid lines
                CustomPaint(
                  size: const Size(double.infinity, 180),
                  painter: _MapGridPainter(),
                ),
                // Route line between Helper and Pickup
                CustomPaint(
                  size: const Size(double.infinity, 180),
                  painter: _RouteLinePainter(),
                ),
                // Pickup Pin (Dest)
                Positioned(
                  top: 35,
                  right: 50,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.3),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.home,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                        ),
                        child: const Text(
                          'Pickup',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                // Helper Moving Pin
                Positioned(
                  bottom: 35,
                  left: 60,
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryGreen,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.primaryGreen.withOpacity(0.4),
                                    blurRadius: 10,
                                    spreadRadius: 3,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.directions_bike,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4)],
                              ),
                              child: const Text(
                                'Helper',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryGreen,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                // Live ETA Badge (Top Left)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.92),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: etaInfo.isArrivingSoon ? Colors.orange : AppTheme.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'ETA: ${etaInfo.etaMinutes} min (${etaInfo.distanceKm} km)',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
                      label: const Text('Open Maps', style: TextStyle(fontSize: 12)),
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
                      isCompleted: etaInfo.milestone == DeliveryMilestone.arrivingSoon ||
                          etaInfo.milestone == DeliveryMilestone.arrived,
                    ),
                    _MilestoneStep(
                      title: 'Near (<1km)',
                      isCompleted: etaInfo.milestone == DeliveryMilestone.arrivingSoon ||
                          etaInfo.milestone == DeliveryMilestone.arrived,
                      isActive: etaInfo.milestone == DeliveryMilestone.arrivingSoon,
                    ),
                    _MilestoneConnector(
                      isCompleted: etaInfo.milestone == DeliveryMilestone.arrived,
                    ),
                    _MilestoneStep(
                      title: 'Arrived',
                      isCompleted: etaInfo.milestone == DeliveryMilestone.arrived,
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

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1.5;

    // Road grid lines
    canvas.drawLine(const Offset(0, 50), Offset(size.width, 50), paint);
    canvas.drawLine(const Offset(0, 110), Offset(size.width, 110), paint);
    canvas.drawLine(const Offset(90, 0), Offset(90, size.height), paint);
    canvas.drawLine(const Offset(220, 0), Offset(220, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RouteLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryGreen.withOpacity(0.6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(85, size.height - 55)
      ..cubicTo(120, size.height - 70, 180, 80, size.width - 70, 55);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
