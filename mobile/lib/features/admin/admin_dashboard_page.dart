import 'package:flutter/material.dart';
import '../../core/localization/app_localizations.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/panta_provider.dart';
import '../../services/admin_api_service.dart';
import '../../services/auth_service.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  final AdminApiService _adminApiService = AdminApiService();
  final AuthService _authService = AuthService();

  AdminMarketSummary _summary = const AdminMarketSummary(
    recyclerLimit: 20,
    helperLimit: 30,
  );
  List<CityTrendModel> _cities = [];
  List<AdminLogModel> _logs = [];
  List<AdminFeedbackModel> _feedback = [];
  CityTrendModel? _selectedCity;

  bool _isLoading = true;
  bool _isSimulating = false;

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  Future<void> _loadAdminData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _authService.getToken() ?? '';
      final overview = await _adminApiService.fetchOverview(token: token);
      final logs = await _adminApiService.fetchLogs(token: token);
      final feedback = await _adminApiService.fetchFeedback(token: token);

      if (overview != null) {
        setState(() {
          _summary = overview.summary;
          _cities = overview.cities;
          if (_cities.isNotEmpty && _selectedCity == null) {
            _selectedCity = _cities.first;
          }
        });
      } else {
        // Fallback demo data if backend is offline or in mock mode
        _loadFallbackData();
      }

      if (feedback.isNotEmpty) {
        setState(() {
          _feedback = feedback;
        });
      }

      if (logs.isNotEmpty) {
        setState(() {
          _logs = logs;
        });
      } else if (_logs.isEmpty) {
        _loadFallbackLogs();
      }
    } catch (e) {
      debugPrint('Error loading admin data: $e');
      _loadFallbackData();
      _loadFallbackLogs();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadFallbackData() {
    setState(() {
      _summary = const AdminMarketSummary(
        totalRequests: 28,
        activeRequests: 11,
        pendingRequests: 6,
        inProgressRequests: 5,
        completedRequests: 17,
        cancelledRequests: 0,
        totalPantAmount: 2450.0,
        totalRecyclerPayout: 1715.0,
        totalHelperPayout: 735.0,
        recyclerLimit: 20,
        helperLimit: 30,
        activeRecyclersCount: 9,
        activeHelpersCount: 6,
      );

      _cities = const [
        CityTrendModel(
          cityName: 'Stockholm',
          countryCode: 'SE',
          latitude: 59.3293,
          longitude: 18.0686,
          activeRequests: 6,
          pendingRequests: 3,
          acceptedRequests: 3,
          completedRequests: 12,
          activeHelpers: 4,
          avgEtaMinutes: 11,
          status: 'optimal',
          districts: ['Södermalm', 'Norrmalm', 'Östermalm', 'Vasastan'],
        ),
        CityTrendModel(
          cityName: 'Göteborg',
          countryCode: 'SE',
          latitude: 57.7089,
          longitude: 11.9746,
          activeRequests: 3,
          pendingRequests: 2,
          acceptedRequests: 1,
          completedRequests: 4,
          activeHelpers: 2,
          avgEtaMinutes: 16,
          status: 'optimal',
          districts: ['Centrum', 'Majorna', 'Haga'],
        ),
        CityTrendModel(
          cityName: 'Malmö',
          countryCode: 'SE',
          latitude: 55.6050,
          longitude: 13.0038,
          activeRequests: 2,
          pendingRequests: 1,
          acceptedRequests: 1,
          completedRequests: 1,
          activeHelpers: 1,
          avgEtaMinutes: 22,
          status: 'high_demand',
          districts: ['Västra Hamnen', 'Möllevången'],
        ),
        CityTrendModel(
          cityName: 'Uppsala',
          countryCode: 'SE',
          latitude: 59.8586,
          longitude: 17.6389,
          activeRequests: 1,
          pendingRequests: 1,
          acceptedRequests: 0,
          completedRequests: 0,
          activeHelpers: 1,
          avgEtaMinutes: 25,
          status: 'optimal',
          districts: ['Centrum', 'Luthagen'],
        ),
      ];

      if (_cities.isNotEmpty && _selectedCity == null) {
        _selectedCity = _cities.first;
      }
    });
  }

  void _loadFallbackLogs() {
    final now = DateTime.now().toUtc();
    _logs = [
      AdminLogModel(
        id: 'log-seed-1',
        timestamp: now.subtract(const Duration(minutes: 5)).toIso8601String(),
        level: 'INFO',
        category: 'MARKET_LIMIT',
        message:
            'Personal quota enforced: 20 max requests per Recycler, 30 active jobs per Helper', // l10n-ignore
        city: 'Sweden (National)',
      ),
      AdminLogModel(
        id: 'log-seed-2',
        timestamp: now.subtract(const Duration(minutes: 15)).toIso8601String(),
        level: 'METRIC',
        category: 'ANTI_SPAM',
        message:
            'National spam check: All accounts within 20/30 limit. Violations: 0', // l10n-ignore
        city: 'Stockholm',
      ),
      AdminLogModel(
        id: 'log-seed-3',
        timestamp: now.subtract(const Duration(minutes: 30)).toIso8601String(),
        level: 'SUCCESS',
        category: 'PAYOUT',
        message:
            'Disbursed 70/30 pant revenue: 175.00 SEK to Anna Recycler, 75.00 SEK to Erik Helper', // l10n-ignore
        city: 'Stockholm',
      ),
    ];
  }

  Future<void> _simulateBackendLog() async {
    setState(() {
      _isSimulating = true;
    });

    try {
      final token = await _authService.getToken() ?? '';
      final newLog = await _adminApiService.simulateLog(token: token);

      if (newLog != null) {
        setState(() {
          _logs.insert(0, newLog);
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.simulatedEventLogged(newLog.category, newLog.message),
              ),
              backgroundColor: AppTheme.primaryGreen,
              duration: const Duration(seconds: 4),
            ),
          );
        }

        // Refresh overview metrics from real backend
        final overview = await _adminApiService.fetchOverview(token: token);
        if (overview != null && mounted) {
          setState(() {
            _summary = overview.summary;
            _cities = overview.cities;
          });
        }
      } else {
        // Local simulation fallback
        final mockLog = AdminLogModel(
          id: 'sim-${DateTime.now().millisecondsSinceEpoch}',
          timestamp: DateTime.now().toUtc().toIso8601String(),
          level: 'INFO',
          category: 'DISPATCH',
          message:
              'Simulated pickup accepted in Stockholm Vasastan (ETA: 12 min)', // l10n-ignore
          city: 'Stockholm',
        );
        setState(() {
          _logs.insert(0, mockLog);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.simulatedEventTriggeredLocal),
              backgroundColor: Colors.blueGrey,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.simulationError('$e'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSimulating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.operationsAndMarketOversight,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              context.l10n.personalCaps(20, 30),
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: context.l10n.refreshMarketData,
            onPressed: _isLoading ? null : _loadAdminData,
          ),
          IconButton(
            icon: const Icon(Icons.switch_account_outlined),
            tooltip: context.l10n.switchToUserView,
            onPressed: () async {
              await provider.switchDemoRole();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: context.l10n.logOut,
            onPressed: () async {
              await provider.logout();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAdminData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildQuotaBanner(),
                    const SizedBox(height: 16),
                    _buildKpiGrid(),
                    const SizedBox(height: 20),
                    _buildMapSection(),
                    const SizedBox(height: 20),
                    _buildCityBreakdownSection(),
                    const SizedBox(height: 20),
                    _buildLogsSection(),
                    const SizedBox(height: 20),
                    _buildFeedbackSection(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSimulating ? null : _simulateBackendLog,
        backgroundColor: AppTheme.primaryGreen,
        icon: _isSimulating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.bolt, color: Colors.white),
        label: Text(
          _isSimulating
              ? context.l10n.simulating
              : context.l10n.simulateMarketEvent,
          style:
              const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildQuotaBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined,
              color: AppTheme.primaryGreen, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.antiSpamProtectionActive,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                Text(
                  context.l10n.adminQuotaDescription(_summary.recyclerLimit, _summary.helperLimit),
                  style:
                      const TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              context.l10n.statusActive,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 600 ? 4 : 2;
        final aspectRatio = constraints.maxWidth > 600 ? 1.25 : 1.15;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: aspectRatio,
          children: [
            _buildKpiCard(
              title: context.l10n.activePickups,
              value: '${_summary.activeRequests}',
              subtitle: context.l10n.kpiActivePickupsSubtitle(
                _summary.pendingRequests,
                _summary.inProgressRequests,
              ),
              icon: Icons.local_shipping,
              color: Colors.blue.shade700,
            ),
            _buildKpiCard(
              title: context.l10n.totalPantScanned,
              value: '${_summary.totalPantAmount.toStringAsFixed(0)} SEK',
              subtitle: context.l10n.kpiPantSplitSubtitle,
              icon: Icons.recycling,
              color: AppTheme.primaryGreen,
            ),
            _buildKpiCard(
              title: context.l10n.recyclerLimit,
              value: '${_summary.recyclerLimit} / user',
              subtitle: context.l10n.recyclerLimitSubtitle,
              icon: Icons.person_outline,
              color: Colors.purple.shade700,
            ),
            _buildKpiCard(
              title: context.l10n.helperLimit,
              value: '${_summary.helperLimit} / helper',
              subtitle: context.l10n.helperLimitSubtitle,
              icon: Icons.delivery_dining,
              color: Colors.orange.shade800,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: color, size: 18),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMapSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.map, color: AppTheme.primaryGreen),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.swedenMapVisualizationTitle,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.monitoredHubsCount(_cities.length),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.swedenMapDescription,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(58.5, 15.0),
                    zoom: 4.7,
                  ),
                  zoomControlsEnabled: true,
                  mapToolbarEnabled: false,
                  myLocationButtonEnabled: false,
                  markers: {
                    for (final city in _cities)
                      Marker(
                        markerId: MarkerId(city.cityName),
                        position: LatLng(city.latitude, city.longitude),
                        infoWindow: InfoWindow(
                          title: city.cityName,
                          snippet:
                              '${city.activeRequests} active pickups • ${city.status}',
                        ),
                        onTap: () => setState(() => _selectedCity = city),
                      ),
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildMapLegend(),
            if (_selectedCity != null) ...[
              const Divider(height: 24),
              _buildSelectedCityDetail(_selectedCity!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMapLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLegendDot(Colors.green.shade600, 'Optimal Balance'),
        const SizedBox(width: 16),
        _buildLegendDot(Colors.orange.shade700, 'High Demand'),
        const SizedBox(width: 16),
        _buildLegendDot(Colors.red.shade600, 'Helper Shortage'),
      ],
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildSelectedCityDetail(CityTrendModel city) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBF9),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.selectedNodeCity(city.cityName, city.countryCode),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              _buildStatusBadge(city.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricPill('Active Requests', '${city.activeRequests}',
                  Colors.blue.shade700),
              _buildMetricPill(
                  'Pending', '${city.pendingRequests}', Colors.orange.shade700),
              _buildMetricPill('Active Helpers', '${city.activeHelpers}',
                  AppTheme.primaryGreen),
              _buildMetricPill('Avg ETA', '${city.avgEtaMinutes} min',
                  Colors.purple.shade700),
            ],
          ),
          if (city.districts.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: city.districts
                  .map(
                    (d) => Chip(
                      label: Text(d, style: const TextStyle(fontSize: 10)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricPill(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
              fontWeight: FontWeight.bold, fontSize: 16, color: color),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildCityBreakdownSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_city, color: AppTheme.primaryGreen),
                const SizedBox(width: 8),
                Text(
                  context.l10n.cityBreakdownTitle,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final city in _cities) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor:
                      _getStatusColor(city.status).withValues(alpha: 0.15),
                  child: Icon(
                    Icons.location_pin,
                    color: _getStatusColor(city.status),
                  ),
                ),
                title: Text(
                  city.cityName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  context.l10n.cityCapacityStats(city.activeRequests, city.pendingRequests, city.activeHelpers, city.avgEtaMinutes),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                trailing: _buildStatusBadge(city.status),
                onTap: () {
                  setState(() {
                    _selectedCity = city;
                  });
                },
              ),
              if (city != _cities.last) const Divider(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFeedbackSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  const Icon(Icons.feedback_outlined, color: AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  Text(context.l10n.userFeedbackTitle,
                      style:
                          const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ]),
                Text(context.l10n.feedbackSubmissionsCount(_feedback.length),
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Text(context.l10n.feedbackMarketDescription,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            if (_feedback.isEmpty)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text(context.l10n.noFeedbackReceivedYet)))
            else
              ..._feedback.take(20).map(_buildFeedbackItem),
          ],
        ),
      ),
    );
  }

  String _formatFeedbackDate(String value) {
    final parsed = DateTime.tryParse(value)?.toLocal();
    if (parsed == null) return value;
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${parsed.year}-${twoDigits(parsed.month)}-${twoDigits(parsed.day)} '
        '${twoDigits(parsed.hour)}:${twoDigits(parsed.minute)}';
  }

  Widget _buildFeedbackItem(AdminFeedbackModel feedback) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Chip(label: Text(feedback.category)),
          const Spacer(),
          if (feedback.contactRequested)
            const Icon(Icons.contact_mail_outlined,
                size: 18, color: AppTheme.primaryGreen),
        ]),
        Text(feedback.message),
        const SizedBox(height: 6),
        Text(
            '${_formatFeedbackDate(feedback.createdAt)} • ${feedback.userName.isEmpty ? context.l10n.unknownUser : feedback.userName}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
      ]),
    );
  }

  Widget _buildLogsSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.receipt_long, color: AppTheme.primaryGreen),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.liveSystemAuditLogs,
                      style:
                          const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  context.l10n.eventsCount(_logs.length),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              context.l10n.auditLogDescription,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            if (_logs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Center(child: Text(context.l10n.noSystemLogsRecordedYet)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _logs.length.clamp(0, 10),
                separatorBuilder: (context, index) => const Divider(height: 12),
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  return _buildLogItem(log);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogItem(AdminLogModel log) {
    Color categoryColor = Colors.blueGrey;
    if (log.category == 'ANTI_SPAM' || log.category == 'MARKET_LIMIT') {
      categoryColor = Colors.purple.shade700;
    } else if (log.category == 'PAYOUT') {
      categoryColor = AppTheme.primaryGreen;
    } else if (log.category == 'DISPATCH') {
      categoryColor = Colors.blue.shade700;
    } else if (log.category == 'GEO_HEALTH') {
      categoryColor = Colors.orange.shade800;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              log.category,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: categoryColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  log.message,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(
                  '${log.city} • ${log.timestamp.length > 19 ? log.timestamp.substring(11, 19) : log.timestamp}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'optimal':
        return Colors.green.shade600;
      case 'high_demand':
        return Colors.orange.shade700;
      case 'helper_shortage':
        return Colors.red.shade600;
      default:
        return Colors.blue.shade600;
    }
  }

  Widget _buildStatusBadge(String status) {
    final color = _getStatusColor(status);
    final text = status.replaceAll('_', ' ').toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
