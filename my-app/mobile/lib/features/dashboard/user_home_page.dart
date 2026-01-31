import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/panta_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/request_model.dart';
import 'create_request_page.dart';
import '../shared/profile_screen.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';

class UserHomePage extends StatefulWidget {
  const UserHomePage({super.key});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  int _currentIndex = 0;
  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    // Initialize WebSocket connection
    _connectWebSocket();
  }

  void _connectWebSocket() async {
    final token = await AuthService().getToken();
    if (token == null) return;

    // Convert http(s) to ws(s)
    String wsUrl = ApiConfig.baseUrl.replaceAll('http', 'ws');
    // Ensure we handle https -> wss
    if (ApiConfig.baseUrl.startsWith('https')) {
       wsUrl = ApiConfig.baseUrl.replaceAll('https', 'wss');
    }

    // Connect to /api/v1/ws with token param as a fallback/simpler auth for WS
    // Note: IOClient supports headers, but ensuring cross-platform compat with query params is safer
    // unless standard library prevents headers cleanly.
    // But our backend supports query param 'token' now.
    final uri = Uri.parse('$wsUrl/api/v1/ws').replace(queryParameters: {'token': token});

    try {
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (message) {
          if (message.toString().contains('"type":"refresh"')) {
            if (mounted) {
              context.read<PantaProvider>().fetchRequests(silent: true);
            }
          }
        },
        onError: (error) {
          debugPrint('WS Error: $error');
          // Simple reconnect logic could go here
        },
        onDone: () {
          debugPrint('WS Closed');
        },
      );
    } catch (e) {
      debugPrint('WS Connection Error: $e');
    }
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const _DashboardView(),
          const _HistoryView(),
          const ProfileScreen(isHelper: false),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
             icon: Icon(Icons.dashboard_outlined),
             selectedIcon: Icon(Icons.dashboard),
             label: 'Home'
          ),
          NavigationDestination(
             icon: Icon(Icons.history_outlined),
             selectedIcon: Icon(Icons.history),
             label: 'History'
          ),
          NavigationDestination(
             icon: Icon(Icons.person_outline),
             selectedIcon: Icon(Icons.person),
             label: 'Profile'
          ),
        ],
      ),
      floatingActionButton: _currentIndex == 0 ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateRequestPage()));
        },
        backgroundColor: AppTheme.primaryGreen,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Recycle Now", style: TextStyle(color: Colors.white)),
      ) : null,
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final ongoing = provider.ongoingRequests;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 180,
          backgroundColor: AppTheme.primaryGreen,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
            title: const Text("Welcome Back!",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)
            ),
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primaryGreen, AppTheme.primaryGreen.withOpacity(0.8)],
                ),
              ),
              child: Stack(
                children: [
                   Positioned(
                    right: 8,
                    top: 8,
                    child: IconButton(
                      icon: const Icon(Icons.refresh, color: Colors.white70),
                      onPressed: () {
                         context.read<PantaProvider>().fetchRequests();
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Refreshing requests...")));
                      },
                    ),
                  ),
                  Positioned(
                    right: -20,
                    top: -20,
                    child: Icon(Icons.eco, size: 150, color: Colors.white.withOpacity(0.1)),
                  ),
                ],
              ),
            ),
          ),
        ),

        if (provider.isLoading)
           const SliverFillRemaining(
             child: Center(child: CircularProgressIndicator()),
           )
        else
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Ongoing Requests",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 16),
                if (ongoing.isEmpty)
                  _EmptyState(message: "No ongoing recycling requests.\nStart recycling today!"),

                ...ongoing.asMap().entries.map((e) => _RequestCard(request: e.value, isInteractable: false, index: e.key)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final history = provider.previousRequests;

    return Scaffold(
      appBar: AppBar(title: const Text("History")),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: history.length,
        itemBuilder: (context, index) {
          return _RequestCard(request: history[index], isInteractable: true, index: index);
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(40),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.recycling, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final RecyclingRequest request;
  final bool isInteractable;
  final int? index;

  const _RequestCard({required this.request, this.isInteractable = false, this.index});

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    String statusText;

    switch (request.status) {
      case RequestStatus.pending:
        statusColor = Colors.orange;
        statusText = "Waiting for Helper";
        break;
      case RequestStatus.accepted:
        statusColor = Colors.blue;
        statusText = "Helper on the way";
        break;
      case RequestStatus.pickedUp:
        statusColor = Colors.green;
        statusText = "Picked Up";
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                if (index != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Text(
                      "#${index! + 1}",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[400],
                      ),
                    ),
                  ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2_outlined, color: AppTheme.primaryGreen),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(request.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                          const SizedBox(width: 4),
                          Text(request.location, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                )
              ],
            ),
            const SizedBox(height: 12),
            if (isInteractable && request.status == RequestStatus.pickedUp && !request.isRated)
              OutlinedButton(
                onPressed: () {
                  _showRatingDialog(context, request);
                },
                child: const Text("Rate Helper"),
              ),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog(BuildContext context, RecyclingRequest request) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rate your Helper"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("How was the pickup service?"),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) => IconButton(
                onPressed: () {
                   context.read<PantaProvider>().rateHelper(request.id, index + 1.0);
                   Navigator.pop(ctx);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Thank you for your rating!")));
                },
                icon: const Icon(Icons.star_border, size: 32, color: Colors.amber),
              )),
            ),
          ],
        ),
      ),
    );
  }
}
