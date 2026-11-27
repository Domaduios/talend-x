import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'dart:math' as math;

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({Key? key}) : super(key: key);

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen>
    with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<Map<String, dynamic>> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _particleControllers = List.generate(
      8,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: 5000 + math.Random(index).nextInt(3000),
        ),
      )..repeat(),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _fadeController.forward();
    _loadActivities();
  }

  @override
  void dispose() {
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadActivities() async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) return;

      final List<Map<String, dynamic>> activities = [];

      // Load completed sessions
      final sessionsSnapshot = await SupabaseDb.instance
          .collection('sessions')
          .where('participants', arrayContains: currentUser.uid)
          .where('status', isEqualTo: 'completed')
          .orderBy('completedAt', descending: true)
          .limit(10)
          .get();

      for (var doc in sessionsSnapshot.docs) {
        final data = doc.data();
        final completedAt = parseDbDate(data['completedAt']);
        final participants = List<String>.from(data['participants'] ?? []);
        final otherUserId = participants.firstWhere(
          (id) => id != currentUser.uid,
          orElse: () => '',
        );

        if (otherUserId.isNotEmpty) {
          final userDoc = await SupabaseDb.instance
              .collection('users')
              .doc(otherUserId)
              .get();

          final userName = userDoc.data()?['name'] ?? 'Unknown';
          activities.add({
            'id': doc.id,
            'type': 'session_completed',
            'title': 'Session Completed',
            'description': 'You completed a session with $userName',
            'icon': Icons.check_circle,
            'color': Colors.green,
            'timestamp': completedAt?.toDate() ?? DateTime.now(),
            'details': {
              'sessionTitle': data['title'] ?? 'Session',
              'duration': data['duration'] ?? 60,
            },
          });
        }
      }

      // Load connection acceptances
      final connectionsSnapshot = await SupabaseDb.instance
          .collection('connections')
          .where('connectedUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'accepted')
          .orderBy('acceptedAt', descending: true)
          .limit(5)
          .get();

      for (var doc in connectionsSnapshot.docs) {
        final data = doc.data();
        final acceptedAt = parseDbDate(data['acceptedAt']);
        final userId = data['userId'] as String?;

        if (userId != null) {
          final userDoc = await SupabaseDb.instance
              .collection('users')
              .doc(userId)
              .get();

          final userName = userDoc.data()?['name'] ?? 'Unknown';
          activities.add({
            'id': doc.id,
            'type': 'connection_accepted',
            'title': 'Connection Accepted',
            'description': '$userName accepted your connection request',
            'icon': Icons.people,
            'color': Colors.blue,
            'timestamp': acceptedAt?.toDate() ?? DateTime.now(),
          });
        }
      }

      // Load reviews received
      final reviewsSnapshot = await SupabaseDb.instance
          .collection('reviews')
          .where('revieweeId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      for (var doc in reviewsSnapshot.docs) {
        final data = doc.data();
        final createdAt = parseDbDate(data['createdAt']);
        final reviewerId = data['reviewerId'] as String?;
        final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;

        if (reviewerId != null) {
          final userDoc = await SupabaseDb.instance
              .collection('users')
              .doc(reviewerId)
              .get();

          final userName = userDoc.data()?['name'] ?? 'Unknown';
          activities.add({
            'id': doc.id,
            'type': 'review_received',
            'title': 'New Review',
            'description': '$userName left you a ${rating.toInt()}-star review',
            'icon': Icons.star,
            'color': Colors.amber,
            'timestamp': createdAt?.toDate() ?? DateTime.now(),
            'details': {'rating': rating, 'comment': data['comment'] ?? ''},
          });
        }
      }

      // Load scheduled sessions
      final upcomingSessionsSnapshot = await SupabaseDb.instance
          .collection('sessions')
          .where('participants', arrayContains: currentUser.uid)
          .where('status', isEqualTo: 'scheduled')
          .orderBy('scheduledDate', descending: false)
          .limit(5)
          .get();

      for (var doc in upcomingSessionsSnapshot.docs) {
        final data = doc.data();
        final scheduledDate = parseDbDate(data['scheduledDate']);
        final participants = List<String>.from(data['participants'] ?? []);
        final otherUserId = participants.firstWhere(
          (id) => id != currentUser.uid,
          orElse: () => '',
        );

        if (otherUserId.isNotEmpty) {
          final userDoc = await SupabaseDb.instance
              .collection('users')
              .doc(otherUserId)
              .get();

          final userName = userDoc.data()?['name'] ?? 'Unknown';
          activities.add({
            'id': doc.id,
            'type': 'session_scheduled',
            'title': 'Session Scheduled',
            'description': 'New session scheduled with $userName',
            'icon': Icons.calendar_today,
            'color': Colors.orange,
            'timestamp': scheduledDate?.toDate() ?? DateTime.now(),
          });
        }
      }

      // Sort by timestamp
      activities.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );

      if (mounted) {
        setState(() {
          _activities = activities;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading activities: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: Stack(
          children: [
            ...List.generate(8, (index) => _buildParticle(index)),
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                        ),
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _activities.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.history,
                                      size: 80,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'No Activities',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Your activities will appear here',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                  _buildStatsOverview(),
                                  const SizedBox(height: 25),
                                  _buildSectionTitle('Recent Activity'),
                                  const SizedBox(height: 15),
                                  ..._activities.map(
                                    (activity) => _buildActivityCard(activity),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Activity',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Your recent activities',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsOverview() {
    final sessionsCount = _activities
        .where((a) => a['type'] == 'session_completed')
        .length;
    final reviewsCount = _activities
        .where((a) => a['type'] == 'review_received')
        .length;
    final connectionsCount = _activities
        .where((a) => a['type'] == 'connection_accepted')
        .length;

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Sessions',
            '$sessionsCount',
            Icons.video_library,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Reviews',
            '$reviewsCount',
            Icons.star,
            Colors.amber,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            'Connections',
            '$connectionsCount',
            Icons.people,
            Colors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> activity) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: activity['color'].withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(activity['icon'], color: activity['color'], size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity['title'],
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  activity['description'],
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                if (activity.containsKey('details')) ...[
                  const SizedBox(height: 8),
                  _buildActivityDetails(activity['details']),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _formatTimestamp(activity['timestamp']),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityDetails(Map<String, dynamic> details) {
    if (details.containsKey('rating')) {
      return Row(
        children: List.generate(5, (index) {
          return Icon(
            index < (details['rating'] as double).toInt()
                ? Icons.star
                : Icons.star_border,
            color: Colors.amber,
            size: 14,
          );
        }),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildParticle(int index) {
    if (_particleControllers == null) return const SizedBox.shrink();

    final random = math.Random(index);
    final size = random.nextDouble() * 20 + 5;
    final left = random.nextDouble() * MediaQuery.of(context).size.width;
    final top = random.nextDouble() * 200;

    return Positioned(
      left: left,
      top: top,
      child: AnimatedBuilder(
        animation: _particleControllers![index],
        builder: (context, child) {
          final value = _particleControllers![index].value;
          return Transform.translate(
            offset: Offset(
              math.sin(value * 2 * math.pi) * 20,
              -math.cos(value * 2 * math.pi) * 30,
            ),
            child: Opacity(
              opacity: (0.1 + (math.sin(value * 2 * math.pi) * 0.3)).clamp(
                0.0,
                1.0,
              ),
              child: child,
            ),
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
