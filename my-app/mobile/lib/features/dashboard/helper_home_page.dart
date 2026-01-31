import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/panta_provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/request_model.dart';
import '../shared/profile_screen.dart';

class HelperHomePage extends StatefulWidget {
  const HelperHomePage({super.key});

  @override
  State<HelperHomePage> createState() => _HelperHomePageState();
}

class _HelperHomePageState extends State<HelperHomePage> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const _MarketplaceView(),
          const _MyJobsView(),
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

                ...jobs.map((job) => _JobCard(job: job, isAcceptable: true)),
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
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: jobs.length,
        itemBuilder: (context, index) {
          return _JobCard(job: jobs[index], isAcceptable: false);
        },
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  final RecyclingRequest job;
  final bool isAcceptable;

  const _JobCard({required this.job, required this.isAcceptable});

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
                   children: [
                     Expanded(child: Text(job.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
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
                 if (isAcceptable)
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
