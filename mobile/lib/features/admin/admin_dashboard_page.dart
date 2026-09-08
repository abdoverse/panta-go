import 'package:flutter/material.dart';
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
    recyclerLimit: 10,
    helperLimit: 15,
  );
  List<CityTrendModel> _cities = [];
  List<AdminLogModel> _logs = [];
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
        recyclerLimit: 10,
        helperLimit: 15,
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
        message: 'Personal quota enforced: 10 max requests per Recycler, 15 active jobs per Helper',
        city: 'Sweden (National)',
      ),
      AdminLogModel(
        id: 'log-seed-2',
        timestamp: now.subtract(const Duration(minutes: 15)).toIso8601String(),
        level: 'METRIC',
        category: 'ANTI_SPAM',
        message: 'National spam check: All accounts within 10/15 limit. Violations: 0',
        city: 'Stockholm',
      ),
      AdminLogModel(
        id: 'log-seed-3',
        timestamp: now.subtract(const Duration(minutes: 30)).toIso8601String(),
        level: 'SUCCESS',
        category: 'PAYOUT',
        message: 'Disbursed 70/30 pant revenue: 175.00 SEK to Anna Recycler, 75.00 SEK to Erik Helper',
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
              content: Text('Simulated Event Logged [${newLog.category}]: ${newLog.message}'),
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
          message: 'Simulated pickup accepted in Stockholm Vasastan (ETA: 12 min)',
          city: 'Stockholm',
        );
        setState(() {
          _logs.insert(0, mockLog);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Simulated Event Triggered (Local fallback)'),
              backgroundColor: Colors.blueGrey,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Simulation error: $e')),
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
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Panta Operations & Market Oversight',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Personal Caps: 10 Recycler / 15 Helper',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Market Data',
            onPressed: _isLoading ? null : _loadAdminData,
          ),
          IconButton(
            icon: const Icon(Icons.switch_account_outlined),
            tooltip: 'Switch to User View',
            onPressed: () async {
              await provider.switchDemoRole();
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log Out',
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
          _isSimulating ? 'Simulating...' : 'Simulate Market Event',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
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
          const Icon(Icons.shield_outlined, color: AppTheme.primaryGreen, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Anti-Spam & Anti-Hoarding Protection Active',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                Text(
                  'Personal recycler market cap: ${_summary.recyclerLimit} active requests | Personal helper cap: ${_summary.helperLimit} active jobs.',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
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
            child: const Text(
              'ACTIVE',
              style: TextStyle(
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
              title: 'Active Pickups',
              value: '${_summary.activeRequests}',
              subtitle: '${_summary.pendingRequests} pend / ${_summary.inProgressRequests} in transit',
              icon: Icons.local_shipping,
              color: Colors.blue.shade700,
            ),
            _buildKpiCard(
              title: 'Total Pant Scanned',
              value: '${_summary.totalPantAmount.toStringAsFixed(0)} SEK',
              subtitle: '70% User / 30% Helper',
              icon: Icons.recycling,
              color: AppTheme.primaryGreen,
            ),
            _buildKpiCard(
              title: 'Recycler Limit',
              value: '${_summary.recyclerLimit} / user',
              subtitle: 'Anti-spam individual quota',
              icon: Icons.person_outline,
              color: Colors.purple.shade700,
            ),
            _buildKpiCard(
              title: 'Helper Limit',
              value: '${_summary.helperLimit} / helper',
              subtitle: 'Anti-hoarding capacity cap',
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
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.map, color: AppTheme.primaryGreen),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sweden Country & City Map Visualization',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_cities.length} Monitored Hubs',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Interactive geographic map representing live market load and helper availability across Sweden. Tap any city node to inspect.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 240,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Stylized geographic background canvas
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F4F8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: CustomPaint(
                          painter: _SwedenMapPainter(),
                          size: Size.infinite,
                        ),
                      ),
                      // City nodes on map
                      for (final city in _cities)
                        _buildCityMapNode(city, constraints.maxWidth, constraints.maxHeight),
                    ],
                  );
                },
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

  Widget _buildCityMapNode(CityTrendModel city, double width, double height) {
    // Relative coordinates mapping Sweden Lat (55.5 - 60.5) and Lng (11.5 - 18.5)
    final double relativeY = 1.0 - ((city.latitude - 55.4) / 4.8).clamp(0.05, 0.95);
    final double relativeX = ((city.longitude - 11.5) / 7.2).clamp(0.1, 0.9);

    final isSelected = _selectedCity?.cityName == city.cityName;
    final color = _getStatusColor(city.status);

    final posX = width * relativeX;
    final posY = height * relativeY;

    return Positioned(
      left: posX - 28,
      top: posY - 28,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCity = city;
          });
        },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: isSelected ? 34 : 26,
                  height: isSelected ? 34 : 26,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.85),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.white : color,
                      width: isSelected ? 3 : 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: isSelected ? 10 : 4,
                        spreadRadius: isSelected ? 3 : 1,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${city.activeRequests}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryGreen : Colors.white.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade400,
                      width: 0.8,
                    ),
                  ),
                  child: Text(
                    city.cityName,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
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
                'Selected Node: ${city.cityName} (${city.countryCode})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              _buildStatusBadge(city.status),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetricPill('Active Requests', '${city.activeRequests}', Colors.blue.shade700),
              _buildMetricPill('Pending', '${city.pendingRequests}', Colors.orange.shade700),
              _buildMetricPill('Active Helpers', '${city.activeHelpers}', AppTheme.primaryGreen),
              _buildMetricPill('Avg ETA', '${city.avgEtaMinutes} min', Colors.purple.shade700),
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
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
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
            const Row(
              children: [
                Icon(Icons.location_city, color: AppTheme.primaryGreen),
                SizedBox(width: 8),
                Text(
                  'City Breakdown & Capacity Trends',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final city in _cities) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: _getStatusColor(city.status).withValues(alpha: 0.15),
                  child: Icon(
                    Icons.location_pin,
                    color: _getStatusColor(city.status),
                  ),
                ),
                title: Text(
                  city.cityName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  'Active: ${city.activeRequests} | Pending: ${city.pendingRequests} | Helpers: ${city.activeHelpers} | ETA: ~${city.avgEtaMinutes}m',
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
                const Row(
                  children: [
                    Icon(Icons.receipt_long, color: AppTheme.primaryGreen),
                    SizedBox(width: 8),
                    Text(
                      'Live System & Audit Logs',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Text(
                  '${_logs.length} events',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Real-time audit log of dispatch actions, payout events, and market quota enforcement.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            if (_logs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24.0),
                child: Center(child: Text('No system logs recorded yet.')),
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
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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

class _SwedenMapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD6E4DE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final fillPaint = Paint()
      ..color = const Color(0xFFE8F1EC)
      ..style = PaintingStyle.fill;

    // Stylized Sweden landmass silhouette
    final path = Path();
    path.moveTo(size.width * 0.45, size.height * 0.08); // Northern tip
    path.lineTo(size.width * 0.60, size.height * 0.25);
    path.lineTo(size.width * 0.68, size.height * 0.45);
    path.lineTo(size.width * 0.72, size.height * 0.65); // Stockholm coast
    path.lineTo(size.width * 0.65, size.height * 0.85); // South-east
    path.lineTo(size.width * 0.48, size.height * 0.94); // Skåne / Malmö
    path.lineTo(size.width * 0.35, size.height * 0.82); // Göteborg coast
    path.lineTo(size.width * 0.38, size.height * 0.50);
    path.lineTo(size.width * 0.42, size.height * 0.20);
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, paint);

    // Subtle coordinate gridlines
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.15)
      ..strokeWidth = 0.8;

    for (double y = 0.2; y < 1.0; y += 0.2) {
      canvas.drawLine(
        Offset(0, size.height * y),
        Offset(size.width, size.height * y),
        gridPaint,
      );
    }
    for (double x = 0.2; x < 1.0; x += 0.2) {
      canvas.drawLine(
        Offset(size.width * x, 0),
        Offset(size.width * x, size.height),
        gridPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
