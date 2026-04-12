import 'dart:math' as math;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import '../../providers/panta_provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../models/request_model.dart';
import 'package:intl/intl.dart';
import '../shared/profile_screen.dart';
import '../../core/constants/app_constants.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../../services/auth_service.dart';
import '../../services/api_config.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../shared/widgets/loading_skeletons.dart';
import '../shared/widgets/location_actions.dart';

String _formatRatingValue(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<PantaProvider>().refreshHelperLocation();
    });
  }

  void _connectWebSocket() async {
    final token = await AuthService().getToken();
    if (token == null) {
      debugPrint('WS Error: No Auth Token available');
      return;
    }

    final uri = ApiConfig.webSocketUri(queryParameters: {'token': token});

    try {
      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(
        (message) {
          if (!mounted) return;
          context
              .read<PantaProvider>()
              .handleRealtimeMessage(message.toString());
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
  void reassemble() {
    super.reassemble();
    // Force refresh data on hot reload to handle model changes
    context.read<PantaProvider>().fetchRequests(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: IndexedStack(
        index: _currentIndex,
        children: const [
          _MarketplaceView(),
          _MyJobsView(),
          _HistoryView(), // New History Tab
          ProfileScreen(isHelper: true),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Available'),
          NavigationDestination(
              icon: Icon(Icons.check_circle_outline),
              selectedIcon: Icon(Icons.check_circle),
              label: 'My Jobs'),
          NavigationDestination(
              icon: Icon(Icons.history_outlined),
              selectedIcon: Icon(Icons.history),
              label: 'History'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
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
    final displayName = provider.currentUserDisplayName;

    return RefreshIndicator(
      onRefresh: () async {
        await context.read<PantaProvider>().refreshHelperLocation();
        await context.read<PantaProvider>().fetchRequests();
      },
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120,
            backgroundColor: AppTheme.primaryGreen,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              title: Text(
                displayName == null || displayName.isEmpty
                    ? 'Welcome Back!'
                    : 'Welcome Back, $displayName!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              background: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Icon(Icons.eco,
                      size: 100, color: Colors.white.withOpacity(0.1)),
                ),
              ),
            ),
          ),
          if (provider.isLoading && jobs.isEmpty)
            const SliverFillRemaining(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: MarketplaceSkeleton(),
              ),
            )
          else
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: provider.isSortingJobsByDistance
                            ? AppTheme.accentLeaf
                            : AppTheme.surfaceMuted,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            provider.isSortingJobsByDistance
                                ? Icons.near_me_rounded
                                : Icons.location_disabled_outlined,
                            color: AppTheme.primaryGreen,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              provider.helperLocationSortingMessage,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          if (provider.isResolvingHelperLocation)
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (jobs.isEmpty)
                      const Center(
                              child: Padding(
                                  padding: EdgeInsets.all(40),
                                  child: Text("No jobs available right now.")))
                          .animate()
                          .fadeIn(),
                    ...jobs.asMap().entries.map((e) =>
                        _JobCard(job: e.value, isAcceptable: true, index: e.key)
                            .animate()
                            .fadeIn(delay: (100 * e.key).ms)
                            .slideY(begin: 0.1, end: 0)),
                  ],
                ),
              ),
            ),
        ],
      ),
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
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<PantaProvider>().fetchRequests();
        },
        child: jobs.isEmpty
            ? LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment_outlined,
                              size: 80, color: Colors.grey[300]),
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
                    ),
                  ),
                ),
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  return _JobCard(
                      job: jobs[index], isAcceptable: false, index: index);
                },
              ),
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
      body: RefreshIndicator(
        onRefresh: () async {
          await context.read<PantaProvider>().fetchRequests();
        },
        child: jobs.isEmpty
            ? LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: const Center(child: Text("No completed jobs yet.")),
                  ),
                ),
              )
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: jobs.length,
                itemBuilder: (context, index) {
                  return _JobCard(
                      job: jobs[index],
                      isAcceptable: false,
                      isCompleted: true,
                      index: index);
                },
              ),
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
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (job.hasImage)
            Stack(
              children: [
                Container(
                  height: 140, // Increased height
                  width: double.infinity,
                  color: Colors.grey[200],
                  child: _RequestImage(imageUrl: job.imageUrl),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                      Colors.black.withOpacity(0.4),
                      Colors.transparent
                    ], begin: Alignment.bottomCenter, end: Alignment.topCenter)),
                  ),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.all(20),
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
                    Expanded(
                        child: Text(job.title,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge // Use theme
                            )),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                          color: AppTheme.primaryGreen, // Solid accent
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                          "${AppConstants.currencySymbol}${(job.reward as num?)?.toStringAsFixed(0) ?? '0'}",
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16)),
                    )
                  ],
                ),
                if (job.description.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    job.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
                const SizedBox(height: 16),
                LocationActions(
                  address: job.location,
                  showDirections: true,
                ),
                if (job.locationLatitude != null &&
                    job.locationLongitude != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Distance-aware sorting is enabled for this pickup.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.access_time_outlined,
                            size: 18, color: AppTheme.primaryGreen)),
                    const SizedBox(width: 12),
                    Text(
                      "${DateFormat('d MMM, HH:mm', AppConstants.defaultLocaleId).format(job.scheduledFrom)} - ${DateFormat('HH:mm', AppConstants.defaultLocaleId).format(job.scheduledTo)}",
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (!isAcceptable && !isCompleted)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _TimeRemainingDisplay(deadline: job.scheduledTo),
                  ),
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
                            border: Border.all(color: Colors.grey[300]!)),
                        child: const Center(
                          child: Text(
                            "Completed",
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold),
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
                              border: Border.all(
                                  color: Colors.amber.withOpacity(0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.star,
                                        size: 16, color: Colors.amber),
                                    const SizedBox(width: 4),
                                    Text(
                                      "Rated ${job.rating == null ? 'N/A' : _formatRatingValue(job.rating!)}",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.amber),
                                    ),
                                  ],
                                ),
                                if (job.ratingComment != null &&
                                    job.ratingComment!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4.0),
                                    child: Text(
                                      "\"${job.ratingComment}\"",
                                      style: TextStyle(
                                          fontStyle: FontStyle.italic,
                                          color: Colors.grey[700]),
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
                        context
                            .read<PantaProvider>()
                            .acceptRequest(job.id)
                            .then((accepted) {
                          if (!context.mounted) return;
                          if (!accepted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Could not accept this pickup."),
                              ),
                            );
                            return;
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text("Job Accepted! Head to My Jobs.")));
                        });
                      },
                      child: const Text("Accept Pickup"),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (dialogContext) => AlertDialog(
                                title: const Text("Cancel pickup?"),
                                content: const Text(
                                  "This job will become available again for another helper, and the recycler will be notified.",
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(false),
                                    child: const Text("Keep Job"),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.of(dialogContext).pop(true),
                                    child: const Text("Cancel Pickup"),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed != true || !context.mounted) {
                              return;
                            }

                            final cancelled = await context
                                .read<PantaProvider>()
                                .cancelRequest(job.id);
                            if (!context.mounted) return;
                            if (!cancelled) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text("Could not cancel this pickup."),
                                ),
                              );
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  "Pickup cancelled. The request is available to other helpers again.",
                                ),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.error,
                          ),
                          child: const Text("Cancel Pickup"),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () async {
                            final completed = await context
                                .read<PantaProvider>()
                                .completeRequest(job.id);
                            if (!context.mounted) return;
                            if (!completed) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content:
                                      Text("Could not complete this pickup."),
                                ),
                              );
                              return;
                            }
                            await _showCompletionCelebration(
                                context, job.title);
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Marked as Picked Up!"),
                              ),
                            );
                          },
                          child: const Text("Mark Complete"),
                        ),
                      ),
                    ],
                  )
              ],
            ),
          )
        ],
      ),
    );
  }

  Future<void> _showCompletionCelebration(
    BuildContext context,
    String jobTitle,
  ) async {
    final controller = ConfettiController(
      duration: const Duration(seconds: 2),
    );
    controller.play();

    final dialogFuture = showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => _CompletionCelebrationDialog(
        controller: controller,
        jobTitle: jobTitle,
      ),
    );

    await Future.delayed(const Duration(seconds: 2));
    if (context.mounted &&
        Navigator.of(context, rootNavigator: true).canPop()) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    await dialogFuture;
    controller.dispose();
  }
}

class _CompletionCelebrationDialog extends StatelessWidget {
  final ConfettiController controller;
  final String jobTitle;

  const _CompletionCelebrationDialog({
    required this.controller,
    required this.jobTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 40),
            padding: const EdgeInsets.fromLTRB(24, 56, 24, 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentLeaf,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.celebration_rounded,
                    color: AppTheme.primaryGreen,
                    size: 38,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pickup completed!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  jobTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Nice work. This pickup is now marked as completed.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          ConfettiWidget(
            confettiController: controller,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            emissionFrequency: 0.08,
            numberOfParticles: 24,
            gravity: 0.18,
            minBlastForce: 8,
            maxBlastForce: 18,
            colors: const [
              AppTheme.primaryGreen,
              Color(0xFFF59E0B),
              Color(0xFF60A5FA),
              Color(0xFFFB7185),
            ],
            blastDirection: -math.pi / 2,
          ),
        ],
      ),
    );
  }
}

class _RequestImage extends StatelessWidget {
  final String? imageUrl;

  const _RequestImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final normalizedImageUrl = imageUrl?.trim();
    if (normalizedImageUrl == null || normalizedImageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final hasRemoteSource =
        normalizedImageUrl.startsWith('http') ||
        normalizedImageUrl.startsWith('data:image/');

    if (hasRemoteSource) {
      return Image.network(
        normalizedImageUrl,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => const Center(
          child: Icon(Icons.image_not_supported, size: 40, color: Colors.grey),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _TimeRemainingDisplay extends StatelessWidget {
  final DateTime deadline;

  const _TimeRemainingDisplay({required this.deadline});

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return "${d.inDays} day${d.inDays > 1 ? 's' : ''}";
    if (d.inHours > 0) return "${d.inHours} hr${d.inHours > 1 ? 's' : ''}";
    if (d.inMinutes > 0) {
      return "${d.inMinutes} min${d.inMinutes > 1 ? 's' : ''}";
    }
    return "moments";
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final difference = deadline.difference(now);
    final isOverdue = difference.isNegative;
    final duration = difference.abs();

    final color = isOverdue
        ? AppTheme.lightTheme.colorScheme.error
        : AppTheme.primaryGreen;
    final label = isOverdue
        ? "OVERDUE: ${_formatDuration(duration)}"
        : "${_formatDuration(duration)} LEFT";

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timer_outlined, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }
}
