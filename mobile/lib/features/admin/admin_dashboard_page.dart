import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shimmer/shimmer.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/market_notification.dart';
import '../../providers/panta_provider.dart';
import '../../services/api_config.dart';
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
  List<UserBlockModel> _userBlocks = [];
  List<SuspensionHistoryModel> _suspensionHistory = [];
  List<AdminUserModel> _adminUsers = [];
  List<MarketNotification> _marketNotifications = [];
  int _suspensionTab = 0; // 0 = Active, 1 = History
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
      final blocks = await _adminApiService.fetchUserBlocks(token: token);
      final hist = await _adminApiService.fetchSuspensionHistory(token: token);
      final users = await _adminApiService.fetchAdminUsers(token: token);
      final notifs =
          await _adminApiService.fetchMarketNotificationsAdmin(token: token);

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

      setState(() {
        _userBlocks = blocks;
        if (hist.isNotEmpty) {
          _suspensionHistory = hist;
        } else if (_suspensionHistory.isEmpty) {
          _loadFallbackSuspensionHistory();
        }
        if (users.isNotEmpty) {
          _adminUsers = users;
        } else if (_adminUsers.isEmpty) {
          _loadFallbackAdminUsers();
        }
        if (notifs.isNotEmpty) {
          _marketNotifications = notifs;
        } else if (_marketNotifications.isEmpty) {
          _loadFallbackMarketNotifications();
        }
      });

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
      _loadFallbackSuspensionHistory();
      _loadFallbackAdminUsers();
      _loadFallbackMarketNotifications();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _loadFallbackMarketNotifications() {
    setState(() {
      _marketNotifications = [
        MarketNotification(
          id: 'market-notice-tech-issue-1', // l10n-ignore
          market: 'ALL', // l10n-ignore
          title: 'Technical Issues', // l10n-ignore
          titleSv: 'Tekniska problem', // l10n-ignore
          message:
              'We are experiencing some technical issues and are looking into it.', // l10n-ignore
          messageSv:
              'Vi upplever för närvarande vissa tekniska problem och undersöker saken.', // l10n-ignore
          severity: MarketNotificationSeverity.warning,
          active: true,
          dismissible: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      ];
    });
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

  void _loadFallbackSuspensionHistory() {
    _suspensionHistory = const [
      SuspensionHistoryModel(
        id: 'hist-demo-1',
        action: 'LIFTED',
        userId: 'user-lars-123',
        email: 'lars.recycler@example.com',
        caseReferenceId: 'CASE-2026-SE-0012',
        reason: 'BankID identity verified after security check',
        actor: 'Admin Operator',
        timestamp: '2026-09-13T14:30:00Z',
      ),
    ];
  }

  void _loadFallbackAdminUsers() {
    _adminUsers = const [
      AdminUserModel(
        userId: 'anna-recycler-id',
        displayName: 'Anna Recycler',
        email: 'anna.recycler@example.com',
        role: 'user',
      ),
      AdminUserModel(
        userId: 'erik-helper-id',
        displayName: 'Erik Helper',
        email: 'erik.helper@example.com',
        role: 'helper',
      ),
      AdminUserModel(
        userId: 'johan-recycler-id',
        displayName: 'Johan Recycler',
        email: 'johan.recycler@example.com',
        role: 'user',
      ),
      AdminUserModel(
        userId: 'sara-recycler-id',
        displayName: 'Sara Recycler',
        email: 'sara.recycler@example.com',
        role: 'user',
      ),
      AdminUserModel(
        userId: 'karin-recycler-id',
        displayName: 'Karin Recycler',
        email: 'karin.recycler@example.com',
        role: 'user',
      ),
      AdminUserModel(
        userId: 'oskar-helper-id',
        displayName: 'Oskar Helper',
        email: 'oskar.helper@example.com',
        role: 'helper',
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
          PopupMenuButton<Locale>(
            key: const Key('admin_language_button'),
            icon: const Icon(Icons.language),
            tooltip: context.l10n.chooseLanguage,
            onSelected: (Locale locale) async {
              await provider.setLocale(locale);
            },
            itemBuilder: (context) => [
              PopupMenuItem<Locale>(
                value: const Locale('sv', 'SE'),
                child: Row(
                  children: [
                    const Icon(Icons.language, size: 18),
                    const SizedBox(width: 8),
                    Text(context.l10n.swedishNative),
                    if (provider.locale.languageCode == 'sv') ...[
                      const Spacer(),
                      const Icon(Icons.check,
                          color: AppTheme.primaryGreen, size: 18),
                    ],
                  ],
                ),
              ),
              PopupMenuItem<Locale>(
                value: const Locale('en', 'US'),
                child: Row(
                  children: [
                    const Icon(Icons.language_outlined, size: 18),
                    const SizedBox(width: 8),
                    Text(context.l10n.englishNative),
                    if (provider.locale.languageCode == 'en') ...[
                      const Spacer(),
                      const Icon(Icons.check,
                          color: AppTheme.primaryGreen, size: 18),
                    ],
                  ],
                ),
              ),
            ],
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
                    const SizedBox(height: 20),
                    _buildMarketAnnouncementsSection(),
                    const SizedBox(height: 20),
                    _buildUserSuspensionsSection(),
                    const SizedBox(height: 20),
                    _buildLanguageSettingsSection(context, provider),
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
                child: ApiConfig.baseUrl.contains("localhost") || ApiConfig.baseUrl.contains("192.168")
                    ? Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.map_outlined, size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 8),
                              Text(
                                "Live Map Disabled\n(Local Dev Mode: Missing API Key)",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      )
                    : GoogleMap(
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

  Widget _buildMarketAnnouncementsSection() {
    final isSwedish =
        Localizations.localeOf(context).languageCode == 'sv'; // l10n-ignore

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.campaign_outlined,
                        color: AppTheme.primaryGreen, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.marketAnnouncementsTitle,
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('simulate_outage_action_button'),
                      onPressed: _simulateOutage,
                      icon: const Icon(Icons.warning_amber_rounded, size: 16),
                      label: Text(context.l10n.simulateTechnicalIssue),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange.shade800,
                        side: BorderSide(color: Colors.orange.shade300),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                    ),
                    FilledButton.icon(
                      key: const Key('broadcast_announcement_action_button'),
                      onPressed: _showBroadcastDialog,
                      icon: const Icon(Icons.add_alert_rounded, size: 16),
                      label: Text(context.l10n.broadcastNewAnnouncement),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              context.l10n.marketAnnouncementsSubtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            if (_marketNotifications.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    context.l10n.noActiveAnnouncements,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic),
                  ),
                ),
              )
            else
              ..._marketNotifications.map((notif) =>
                  _buildMarketNotificationCard(notif, isSwedish)),
          ],
        ),
      ),
    );
  }

  Widget _buildMarketNotificationCard(
      MarketNotification notif, bool isSwedish) {
    final title = notif.localizedTitle(isSwedish);
    final message = notif.localizedMessage(isSwedish);

    Color badgeColor;
    Color badgeTextColor;
    if (notif.severity == MarketNotificationSeverity.critical ||
        notif.severity == MarketNotificationSeverity.incident) {
      badgeColor = Colors.red.shade50;
      badgeTextColor = Colors.red.shade700;
    } else if (notif.severity == MarketNotificationSeverity.info) {
      badgeColor = Colors.blue.shade50;
      badgeTextColor = Colors.blue.shade700;
    } else {
      badgeColor = Colors.amber.shade50;
      badgeTextColor = Colors.amber.shade900;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: notif.active ? AppTheme.surfaceWhite : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: notif.active
              ? badgeTextColor.withValues(alpha: 0.3)
              : Colors.grey.shade300,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              children: [
                Text(
                  notif.market,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: badgeTextColor,
                  ),
                ),
                Text(
                  notif.severity.toValue().toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: badgeTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: notif.active
                        ? AppTheme.textPrimary
                        : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    color: notif.active
                        ? AppTheme.textSecondary
                        : Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: notif.active,
            activeColor: AppTheme.primaryGreen,
            onChanged: (val) => _toggleNotification(notif, val),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleNotification(
      MarketNotification notif, bool newActive) async {
    final token = await _authService.getToken() ?? '';
    final success = await _adminApiService.toggleMarketNotification(
      token: token,
      id: notif.id,
      active: newActive,
    );

    if (success || token.isEmpty) {
      setState(() {
        final idx =
            _marketNotifications.indexWhere((n) => n.id == notif.id);
        if (idx != -1) {
          _marketNotifications[idx] = notif.copyWith(active: newActive);
        }
      });
      if (mounted) {
        Provider.of<PantaProvider>(context, listen: false)
            .fetchMarketNotifications();
      }
    }
  }

  Future<void> _simulateOutage() async {
    final token = await _authService.getToken() ?? '';
    final result =
        await _adminApiService.simulateMarketNotification(token: token);

    if (result != null) {
      setState(() {
        _marketNotifications.insert(0, result);
      });
      if (mounted) {
        Provider.of<PantaProvider>(context, listen: false)
            .fetchMarketNotifications();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.simulateTechnicalIssueSuccess),
            backgroundColor: Colors.orange.shade800,
          ),
        );
      }
    }
  }

  void _showBroadcastDialog() {
    final titleEnCtrl = TextEditingController();
    final titleSvCtrl = TextEditingController();
    final messageEnCtrl = TextEditingController();
    final messageSvCtrl = TextEditingController();
    String selectedMarket = 'ALL'; // l10n-ignore
    String selectedSeverity = 'warning'; // l10n-ignore
    bool dismissible = true;

    showDialog(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.campaign_rounded,
                      color: AppTheme.primaryGreen),
                  const SizedBox(width: 8),
                  Text(context.l10n.broadcastNewAnnouncement),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedMarket,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.marketTargetLabel,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'ALL', child: Text('ALL (*)')), // l10n-ignore
                        DropdownMenuItem(value: 'SE', child: Text('Sweden (SE)')), // l10n-ignore
                        DropdownMenuItem(value: 'NO', child: Text('Norway (NO)')), // l10n-ignore
                        DropdownMenuItem(value: 'DK', child: Text('Denmark (DK)')), // l10n-ignore
                        DropdownMenuItem(value: 'FI', child: Text('Finland (FI)')), // l10n-ignore
                        DropdownMenuItem(value: 'DE', child: Text('Germany (DE)')), // l10n-ignore
                        DropdownMenuItem(value: 'US', child: Text('United States (US)')), // l10n-ignore
                        DropdownMenuItem(value: 'GB', child: Text('United Kingdom (GB)')), // l10n-ignore
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedMarket = val);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: selectedSeverity,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: context.l10n.severityLabel,
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'warning', child: Text('Warning')), // l10n-ignore
                        DropdownMenuItem(value: 'critical', child: Text('Critical')), // l10n-ignore
                        DropdownMenuItem(value: 'info', child: Text('Info')), // l10n-ignore
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedSeverity = val);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleEnCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.announcementTitleLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: titleSvCtrl,
                      decoration: InputDecoration(
                        labelText: context.l10n.announcementTitleSvLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: messageEnCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.l10n.announcementMessageLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: messageSvCtrl,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: context.l10n.announcementMessageSvLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    CheckboxListTile(
                      value: dismissible,
                      title: Text(context.l10n.dismissibleLabel),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (val) {
                        setDialogState(() => dismissible = val ?? true);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text(context.l10n.cancel),
                ),
                FilledButton(
                  key: const Key('submit_announcement_button'),
                  onPressed: () async {
                    final title = titleEnCtrl.text.trim();
                    final message = messageEnCtrl.text.trim();
                    if (message.isEmpty) return;

                    final token = await _authService.getToken() ?? '';
                    final created =
                        await _adminApiService.createMarketNotification(
                      token: token,
                      market: selectedMarket,
                      title: title.isEmpty ? 'Service Notice' : title, // l10n-ignore
                      titleSv: titleSvCtrl.text.trim(),
                      message: message,
                      messageSv: messageSvCtrl.text.trim(),
                      severity: selectedSeverity,
                      dismissible: dismissible,
                    );

                    if (mounted) {
                      Navigator.of(dialogCtx).pop();
                      if (created != null) {
                        setState(() {
                          _marketNotifications.insert(0, created);
                        });
                        Provider.of<PantaProvider>(context, listen: false)
                            .fetchMarketNotifications();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(context.l10n.broadcastSuccess),
                            backgroundColor: AppTheme.primaryGreen,
                          ),
                        );
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                  ),
                  child: Text(context.l10n.broadcastNewAnnouncement),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildUserSuspensionsSection() {
    final activeBlocks =
        _userBlocks.where((b) => b.status == 'BLOCKED').toList(); // l10n-ignore

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
                      const Icon(Icons.shield_outlined,
                          color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.userSuspensionsTitle,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                FilledButton.icon(
                  key: const Key('suspend_user_action_button'),
                  onPressed: _showSuspendUserDialog,
                  icon: const Icon(Icons.block, size: 16),
                  label: Text(context.l10n.suspendUserAction),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Tab selector for Active vs History
            SegmentedButton<int>(
              key: const Key('suspension_tab_selector'),
              segments: [
                ButtonSegment<int>(
                  value: 0,
                  icon: const Icon(Icons.shield, size: 16),
                  label: Text(
                      '${context.l10n.activeTabLabel} (${activeBlocks.length})'),
                ),
                ButtonSegment<int>(
                  value: 1,
                  icon: const Icon(Icons.history, size: 16),
                  label: Text(
                      '${context.l10n.historyTabLabel} (${_suspensionHistory.length})'),
                ),
              ],
              selected: {_suspensionTab},
              onSelectionChanged: (selected) {
                setState(() {
                  _suspensionTab = selected.first;
                });
              },
            ),
            const SizedBox(height: 14),

            if (_suspensionTab == 0) ...[
              if (activeBlocks.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      context.l10n.noActiveSuspensions,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              else
                ...activeBlocks.map(_buildUserBlockCard),
            ] else ...[
              if (_suspensionHistory.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      context.l10n.noSuspensionHistory,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                )
              else
                ..._suspensionHistory.map(_buildSuspensionHistoryCard),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUserBlockCard(UserBlockModel block) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  block.email.isNotEmpty ? block.email : block.userId,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: () => _showUnblockUserDialog(block),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.black87,
                  side: BorderSide(color: Colors.grey.shade400),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: const Size(0, 32),
                ),
                child: Text(context.l10n.unblockUserAction),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${context.l10n.caseReferenceIdLabel}: ${block.caseReferenceId}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '${context.l10n.suspensionReasonLabel}: ${block.reason}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          if (block.expiresAt != null && block.expiresAt!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '${context.l10n.optionalExpiryDateLabel}: ${block.expiresAt}',
              style: TextStyle(fontSize: 11, color: Colors.red.shade700),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSuspensionHistoryCard(SuspensionHistoryModel hist) {
    final isSuspended = hist.action == 'SUSPENDED'; // l10n-ignore
    final isLifted = hist.action == 'LIFTED'; // l10n-ignore

    final Color badgeBg;
    final Color badgeText;
    final String actionLabel;
    final IconData actionIcon;

    if (isSuspended) {
      badgeBg = Colors.red.shade100;
      badgeText = Colors.red.shade900;
      actionLabel = context.l10n.historyActionSuspended;
      actionIcon = Icons.block;
    } else if (isLifted) {
      badgeBg = Colors.green.shade100;
      badgeText = Colors.green.shade900;
      actionLabel = context.l10n.historyActionLifted;
      actionIcon = Icons.check_circle_outline;
    } else {
      badgeBg = Colors.orange.shade100;
      badgeText = Colors.orange.shade900;
      actionLabel = context.l10n.historyActionExpired;
      actionIcon = Icons.timer_outlined;
    }

    final formattedDate = hist.timestamp.length >= 16
        ? hist.timestamp.substring(0, 16).replaceAll('T', ' ')
        : hist.timestamp;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  hist.email.isNotEmpty ? hist.email : hist.userId,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(actionIcon, size: 12, color: badgeText),
                    const SizedBox(width: 4),
                    Text(
                      actionLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${context.l10n.caseReferenceIdLabel}: ${hist.caseReferenceId}',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '${context.l10n.suspensionReasonLabel}: ${hist.reason}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                context.l10n.performedByLabel(hist.actor),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const Spacer(),
              Text(
                formattedDate,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showSuspendUserDialog() async {
    final now = DateTime.now();
    final defaultCaseId =
        'CASE-${now.year}-${now.millisecondsSinceEpoch.toString().substring(7)}';
    final caseController = TextEditingController(text: defaultCaseId);

    // Prepare known users for dropdown
    final availableUsers = _adminUsers.isNotEmpty
        ? _adminUsers
        : const [
            AdminUserModel(
              userId: 'anna-id',
              displayName: 'Anna Recycler',
              email: 'anna.recycler@example.com',
            ),
            AdminUserModel(
              userId: 'erik-id',
              displayName: 'Erik Helper',
              email: 'erik.helper@example.com',
            ),
            AdminUserModel(
              userId: 'johan-id',
              displayName: 'Johan Recycler',
              email: 'johan.recycler@example.com',
            ),
          ];

    String selectedUserValue = availableUsers.first.email.isNotEmpty
        ? availableUsers.first.email
        : availableUsers.first.userId;
    final userController = TextEditingController(text: selectedUserValue);
    bool isCustomUser = false;

    // Standard Reasons
    final l10n = context.l10n;
    final standardReasons = [
      l10n.reasonMissedPickups,
      l10n.reasonFraudulentReceipt,
      l10n.reasonHarassment,
      l10n.reasonMultiAccount,
      l10n.reasonSafetyViolation,
      l10n.reasonIdentityReview,
    ];
    String selectedReasonValue = standardReasons.first;
    final reasonController = TextEditingController(text: selectedReasonValue);
    bool isCustomReason = false;

    // Durations: Indefinite (0), 1d, 3d, 7d, 14d, 30d, custom (-1)
    int selectedDurationDays = 0;
    final expiryController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dl10n = dialogCtx.l10n;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.block, color: Colors.redAccent, size: 22),
                const SizedBox(width: 8),
                Text(dl10n.suspendUserAction),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. User Dropdown
                  Text(
                    dl10n.selectUserDropdownLabel,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    key: const Key('suspend_user_dropdown'),
                    value: isCustomUser ? '__custom__' : selectedUserValue, // l10n-ignore
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    items: [
                      ...availableUsers.map((u) {
                        final identifier =
                            u.email.isNotEmpty ? u.email : u.userId;
                        final label = u.displayName.isNotEmpty
                            ? '${u.displayName} ($identifier)'
                            : identifier;
                        return DropdownMenuItem<String>(
                          value: identifier,
                          child: Text(label, overflow: TextOverflow.ellipsis),
                        );
                      }),
                      DropdownMenuItem<String>(
                        value: '__custom__', // l10n-ignore
                        child: Text(dl10n.customUserOption,
                            style:
                                const TextStyle(fontStyle: FontStyle.italic)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setDialogState(() {
                        if (val == '__custom__') { // l10n-ignore
                          isCustomUser = true;
                          userController.text = '';
                        } else {
                          isCustomUser = false;
                          selectedUserValue = val;
                          userController.text = val;
                        }
                      });
                    },
                  ),
                  if (isCustomUser) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: userController,
                      decoration: InputDecoration(
                        labelText: dl10n.userIdOrEmailLabel,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // 2. Reason Dropdown
                  Text(
                    dl10n.selectReasonDropdownLabel,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<String>(
                    key: const Key('suspend_reason_dropdown'),
                    value:
                        isCustomReason ? '__custom__' : selectedReasonValue, // l10n-ignore
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    items: [
                      ...standardReasons.map((r) => DropdownMenuItem<String>(
                            value: r,
                            child: Text(r, overflow: TextOverflow.ellipsis),
                          )),
                      DropdownMenuItem<String>(
                        value: '__custom__', // l10n-ignore
                        child: Text(dl10n.customReasonOption,
                            style:
                                const TextStyle(fontStyle: FontStyle.italic)),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setDialogState(() {
                        if (val == '__custom__') { // l10n-ignore
                          isCustomReason = true;
                          reasonController.text = '';
                        } else {
                          isCustomReason = false;
                          selectedReasonValue = val;
                          reasonController.text = val;
                        }
                      });
                    },
                  ),
                  if (isCustomReason) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: reasonController,
                      decoration: InputDecoration(
                        labelText: dl10n.suspensionReasonLabel,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // 3. Duration Dropdown
                  Text(
                    dl10n.selectDurationDropdownLabel,
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  DropdownButtonFormField<int>(
                    key: const Key('suspend_duration_dropdown'),
                    value: selectedDurationDays,
                    isExpanded: true,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    items: [
                      DropdownMenuItem<int>(
                        value: 0,
                        child: Text(dl10n.durationIndefinite),
                      ),
                      DropdownMenuItem<int>(
                        value: 1,
                        child: Text(dl10n.duration1Day),
                      ),
                      DropdownMenuItem<int>(
                        value: 3,
                        child: Text(dl10n.duration3Days),
                      ),
                      DropdownMenuItem<int>(
                        value: 7,
                        child: Text(dl10n.duration7Days),
                      ),
                      DropdownMenuItem<int>(
                        value: 14,
                        child: Text(dl10n.duration14Days),
                      ),
                      DropdownMenuItem<int>(
                        value: 30,
                        child: Text(dl10n.duration30Days),
                      ),
                      DropdownMenuItem<int>(
                        value: -1,
                        child: Text(dl10n.durationCustom),
                      ),
                    ],
                    onChanged: (val) {
                      if (val == null) return;
                      setDialogState(() {
                        selectedDurationDays = val;
                        if (val == 0) {
                          expiryController.text = '';
                        } else if (val > 0) {
                          expiryController.text = DateTime.now()
                              .add(Duration(days: val))
                              .toIso8601String();
                        } else {
                          expiryController.text = '';
                        }
                      });
                    },
                  ),
                  if (selectedDurationDays == -1) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: expiryController,
                      decoration: InputDecoration(
                        labelText: dl10n.durationCustom,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // 4. Case Reference ID
                  TextField(
                    controller: caseController,
                    decoration: InputDecoration(
                      labelText: dl10n.caseReferenceIdLabel,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(dl10n.cancel),
              ),
              FilledButton(
                key: const Key('confirm_suspend_button'),
                style:
                    FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                onPressed: () async {
                  final user = userController.text.trim();
                  final caseId = caseController.text.trim();
                  final reason = reasonController.text.trim();
                  final expiry = expiryController.text.trim();

                  if (user.isEmpty || caseId.isEmpty || reason.isEmpty) return;

                  final token = await _authService.getToken() ?? '';
                  final success = await _adminApiService.blockUser(
                    token: token,
                    userId: user,
                    email: user.contains('@') ? user : null,
                    caseReferenceId: caseId,
                    reason: reason,
                    expiresAt: expiry.isNotEmpty ? expiry : null,
                  );

                  if (mounted && dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop();
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(context.l10n.userSuspendedSuccess)),
                      );
                      _loadAdminData();
                    }
                  }
                },
                child: Text(dl10n.confirm),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showUnblockUserDialog(UserBlockModel block) async {
    final l10n = context.l10n;
    final standardUnblockReasons = [
      l10n.unblockAppealApproved,
      l10n.unblockPenaltyServed,
      l10n.unblockFalseReport,
      l10n.unblockDisputeResolved,
      l10n.unblockAdminError,
    ];

    String selectedUnblockReason = standardUnblockReasons.first;
    final reasonController = TextEditingController(text: selectedUnblockReason);
    bool isCustomReason = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final dl10n = dialogCtx.l10n;

          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle_outline,
                    color: Colors.green, size: 22),
                const SizedBox(width: 8),
                Text(dl10n.unblockUserAction),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dl10n.caseReferenceIdLabel}: ${block.caseReferenceId}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text(
                  dl10n.selectUnblockReasonDropdownLabel,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  key: const Key('unblock_reason_dropdown'),
                  value: isCustomReason ? '__custom__' : selectedUnblockReason, // l10n-ignore
                  isExpanded: true,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                  ),
                  items: [
                    ...standardUnblockReasons
                        .map((r) => DropdownMenuItem<String>(
                              value: r,
                              child:
                                  Text(r, overflow: TextOverflow.ellipsis),
                            )),
                    DropdownMenuItem<String>(
                      value: '__custom__', // l10n-ignore
                      child: Text(dl10n.customReasonOption,
                          style:
                              const TextStyle(fontStyle: FontStyle.italic)),
                    ),
                  ],
                  onChanged: (val) {
                    if (val == null) return;
                    setDialogState(() {
                      if (val == '__custom__') { // l10n-ignore
                        isCustomReason = true;
                        reasonController.text = '';
                      } else {
                        isCustomReason = false;
                        selectedUnblockReason = val;
                        reasonController.text = val;
                      }
                    });
                  },
                ),
                if (isCustomReason) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      labelText: dl10n.suspensionReasonLabel,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: Text(dl10n.cancel),
              ),
              FilledButton(
                key: const Key('confirm_unblock_button'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
                onPressed: () async {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) return;

                  final token = await _authService.getToken() ?? '';
                  final success = await _adminApiService.unblockUser(
                    token: token,
                    userId: block.userId,
                    reason: reason,
                    caseReferenceId: block.caseReferenceId,
                  );

                  if (mounted && dialogCtx.mounted) {
                    Navigator.of(dialogCtx).pop();
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(context.l10n.userUnblockedSuccess)),
                      );
                      _loadAdminData();
                    }
                  }
                },
                child: Text(dl10n.confirm),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLanguageSettingsSection(
      BuildContext context, PantaProvider provider) {
    final l10n = context.l10n;
    final isSwedish = provider.locale.languageCode == 'sv';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.language, color: AppTheme.primaryGreen, size: 22),
                const SizedBox(width: 8),
                Text(
                  l10n.language,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isSwedish ? l10n.swedishNative : l10n.englishNative,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.appLanguageDescription,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              key: const Key('admin_language_segmented_button'),
              segments: [
                ButtonSegment<String>(
                  value: 'sv',
                  label: Text(l10n.swedishNative),
                  icon: const Icon(Icons.language, size: 18),
                ),
                ButtonSegment<String>(
                  value: 'en',
                  label: Text(l10n.englishNative),
                  icon: const Icon(Icons.language_outlined, size: 18),
                ),
              ],
              selected: {provider.locale.languageCode},
              onSelectionChanged: (selected) async {
                final code = selected.first;
                await provider.setLocale(
                  code == 'sv'
                      ? const Locale('sv', 'SE')
                      : const Locale('en', 'US'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
