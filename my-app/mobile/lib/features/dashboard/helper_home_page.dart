import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/panta_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/request_model.dart';
import '../shared/profile_screen.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart';

class HelperHomePage extends StatefulWidget {
  const HelperHomePage({super.key});

  @override
  State<HelperHomePage> createState() => _HelperHomePageState();
}

class _HelperHomePageState extends State<HelperHomePage> {
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
    if (token == null) {
      debugPrint('WS Error: No Auth Token available');
      return;
    }

    // Parse the base URL to correctly switch scheme from http -> ws / https -> wss
    final baseUri = Uri.parse(ApiConfig.baseUrl);
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';

    // Connect to /api/v1/ws with token param
    final uri = baseUri.replace(
      scheme: wsScheme,
      path: '/api/v1/ws',
      queryParameters: {'token': token},
    );

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
          const _MarketplaceView(),
          const _MyJobsView(),
          const _HistoryView(), // New History Tab
          const ProfileScreen(isHelper: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
             icon: Icon(Icons.explore_outlined),
             selectedIcon: Icon(Icons.explore),
             label: 'Available'
          ),
          NavigationDestination(
             icon: Icon(Icons.check_circle_outline),
             selectedIcon: Icon(Icons.check_circle),
             label: 'My Jobs'
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
    );
  }
}

class _MarketplaceView extends StatelessWidget {
  const _MarketplaceView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final jobs = provider.availableJobs;

    return CustomScrollView(
       slivers: [
        SliverAppBar(
          expandedHeight: 120,
          backgroundColor: AppTheme.primaryGreen,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
             title: const Text("Available Pickups",
              style: TextStyle(fontWeight: FontWeight.bold)
            ),
             background: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: IconButton(
                  icon: const Icon(Icons.refresh, color: Colors.white70),
                  onPressed: () {
                     context.read<PantaProvider>().fetchRequests();
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Checking for new jobs...")));
                  },
                ),
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
                if (jobs.isEmpty)
                   const Center(child: Padding(padding: EdgeInsets.all(40), child: Text("No jobs available right now."))),

                ...jobs.asMap().entries.map((e) => _JobCard(job: e.value, isAcceptable: true, index: e.key)),
              ],
            ),
          ),
        ),
       ],
    );
  }
}

class _MyJobsView extends StatelessWidget {
  const _MyJobsView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final jobs = provider.acceptedJobs;

    return Scaffold(
      appBar: AppBar(title: const Text("My Active Jobs")),
      body: jobs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("No Active Jobs",
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600])),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: Text(
                      "Go to the 'Available' tab to find recycling requests nearby.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                return _JobCard(job: jobs[index], isAcceptable: false, index: index);
              },
            ),
    );
  }
}

class _HistoryView extends StatelessWidget {
  const _HistoryView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PantaProvider>();
    final jobs = provider.completedJobs;

    return Scaffold(
      appBar: AppBar(title: const Text("Pickup History")),
      body: jobs.isEmpty
          ? const Center(child: Text("No completed jobs yet."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              itemBuilder: (context, index) {
                return _JobCard(job: jobs[index], isAcceptable: false, isCompleted: true, index: index);
              },
            ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final RecyclingRequest job;
  final bool isAcceptable;
  final bool isCompleted;
  final int? index;

  const _JobCard({
    required this.job,
    required this.isAcceptable,
    this.isCompleted = false,
    this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 120,
            width: double.infinity,
            color: Colors.grey[200],
            child: Image.asset(job.imageUrl, fit: BoxFit.cover, errorBuilder: (_,__,___) =>
               const Center(child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey))
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     if (index != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8.0, top: 2.0),
                          child: Text(
                            "#${index! + 1}",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                     Expanded(child: Text(
                        job.title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)
                     )),
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                       decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                       child: Text("${30} CO2e", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                     )
                   ],
                 ),
                 const SizedBox(height: 8),
                 Row(
                   children: [
                      const Icon(Icons.location_on, size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Expanded(child: Text(job.location, style: const TextStyle(color: Colors.grey))),
                   ],
                 ),
                  const SizedBox(height: 16),
                 if (isCompleted)
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Container(
                         width: double.infinity,
                         padding: const EdgeInsets.all(12),
                         decoration: BoxDecoration(
                           color: Colors.grey[100],
                           borderRadius: BorderRadius.circular(8),
                           border: Border.all(color: Colors.grey[300]!)
                         ),
                         child: const Center(
                           child: Text(
                             "Completed",
                             style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                           ),
                         ),
                       ),
                       if (job.isRated)
                         Padding(
                           padding: const EdgeInsets.only(top: 12.0),
                           child: Container(
                             width: double.infinity,
                             padding: const EdgeInsets.all(12),
                             decoration: BoxDecoration(
                               color: Colors.amber.withOpacity(0.1),
                               borderRadius: BorderRadius.circular(8),
                               border: Border.all(color: Colors.amber.withOpacity(0.3)),
                             ),
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.star, size: 16, color: Colors.amber),
                                      const SizedBox(width: 4),
                                      Text(
                                        "Rated ${job.rating?.toStringAsFixed(1) ?? 'N/A'}",
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
                                      ),
                                    ],
                                  ),
                                  if (job.ratingComment != null && job.ratingComment!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        "\"${job.ratingComment}\"",
                                        style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[700]),
                                      ),
                                    ),
                               ],
                             ),
                           ),
                         ),
                     ],
                   )
                 else if (isAcceptable)
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton(
                       onPressed: () {
                          context.read<PantaProvider>().acceptRequest(job.id);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Job Accepted! Head to My Jobs.")));
                       },
                       child: const Text("Accept Pickup"),
                     ),
                   )
                 else
                    SizedBox(
                     width: double.infinity,
                     child: OutlinedButton(
                       onPressed: () {
                          context.read<PantaProvider>().completeRequest(job.id);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Marked as Picked Up!")));
                       },
                       child: const Text("Mark Complete"),
                     ),
                   )
              ],
            ),
          )
        ],
      ),
    );
  }
}
