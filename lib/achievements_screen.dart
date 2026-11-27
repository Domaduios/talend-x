import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'dart:math' as math;

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({Key? key}) : super(key: key);

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen>
    with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<Map<String, dynamic>> _achievements = [];
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
    _loadAchievements();
  }

  @override
  void dispose() {
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadAchievements() async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) return;

      // Load user's sessions
      final sessionsSnapshot = await SupabaseDb.instance
          .collection('sessions')
          .where('participants', arrayContains: currentUser.uid)
          .where('status', isEqualTo: 'completed')
          .get();

      final completedSessions = sessionsSnapshot.docs.length;

      // Load connections
      final connectionsSnapshot = await SupabaseDb.instance
          .collection('connections')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      final connectionsCount = connectionsSnapshot.docs.length;

      // Load reviews
      final reviewsSnapshot = await SupabaseDb.instance
          .collection('reviews')
          .where('revieweeId', isEqualTo: currentUser.uid)
          .get();

      final fiveStarReviews = reviewsSnapshot.docs.where((doc) {
        final rating = (doc.data()['rating'] as num?)?.toDouble() ?? 0.0;
        return rating >= 5.0;
      }).length;

      // Calculate hours learned
      int totalHours = 0;
      for (var doc in sessionsSnapshot.docs) {
        final data = doc.data();
        totalHours += (data['duration'] as num? ?? 60).toInt() ~/ 60;
      }

      // Load learning skills
      final userDoc = await SupabaseDb.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final learningSkills = List<String>.from(
        userDoc.data()?['learningSkills'] ?? [],
      );

      final List<Map<String, dynamic>> achievements = [];

      // First Session
      achievements.add({
        'id': '1',
        'title': 'First Session',
        'description': 'Complete your first session',
        'icon': Icons.star,
        'unlocked': completedSessions >= 1,
        'date': completedSessions >= 1
            ? DateTime.now().subtract(Duration(days: 30 - completedSessions))
            : null,
        'color': Colors.amber,
      });

      // 10 Sessions Master
      achievements.add({
        'id': '2',
        'title': '10 Sessions Master',
        'description': 'Complete 10 sessions',
        'icon': Icons.military_tech,
        'unlocked': completedSessions >= 10,
        'date': completedSessions >= 10
            ? DateTime.now().subtract(Duration(days: 15))
            : null,
        'progress': completedSessions < 10
            ? (completedSessions / 10).clamp(0.0, 1.0)
            : null,
        'color': Colors.orange,
      });

      // 5-Star Teacher
      achievements.add({
        'id': '3',
        'title': '5-Star Teacher',
        'description': 'Get 10 five-star reviews',
        'icon': Icons.emoji_events,
        'unlocked': fiveStarReviews >= 10,
        'date': fiveStarReviews >= 10
            ? DateTime.now().subtract(Duration(days: 7))
            : null,
        'progress': fiveStarReviews < 10
            ? (fiveStarReviews / 10).clamp(0.0, 1.0)
            : null,
        'color': Colors.purple,
      });

      // 50 Hours Learned
      achievements.add({
        'id': '4',
        'title': '50 Hours Learned',
        'description': 'Spend 50 hours learning',
        'icon': Icons.access_time,
        'unlocked': totalHours >= 50,
        'date': totalHours >= 50
            ? DateTime.now().subtract(Duration(days: 20))
            : null,
        'progress': totalHours < 50 ? (totalHours / 50).clamp(0.0, 1.0) : null,
        'color': Colors.blue,
      });

      // Social Butterfly
      achievements.add({
        'id': '5',
        'title': 'Social Butterfly',
        'description': 'Connect with 20 users',
        'icon': Icons.people,
        'unlocked': connectionsCount >= 20,
        'date': connectionsCount >= 20
            ? DateTime.now().subtract(Duration(days: 10))
            : null,
        'progress': connectionsCount < 20
            ? (connectionsCount / 20).clamp(0.0, 1.0)
            : null,
        'color': Colors.green,
      });

      // Knowledge Seeker
      achievements.add({
        'id': '6',
        'title': 'Knowledge Seeker',
        'description': 'Learn 5 different skills',
        'icon': Icons.school,
        'unlocked': learningSkills.length >= 5,
        'date': learningSkills.length >= 5
            ? DateTime.now().subtract(Duration(days: 5))
            : null,
        'progress': learningSkills.length < 5
            ? (learningSkills.length / 5).clamp(0.0, 1.0)
            : null,
        'color': Colors.red,
      });

      if (mounted) {
        setState(() {
          _achievements = achievements;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading achievements: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _getUnlockedCount() {
    return _achievements.where((a) => a['unlocked'] == true).length;
  }

  @override
  Widget build(BuildContext context) {
    final unlocked = _getUnlockedCount();
    final total = _achievements.length;

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
                    _buildHeader(unlocked, total),
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
                            : ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                  _buildProgressCard(unlocked, total),
                                  const SizedBox(height: 25),
                                  _buildSectionTitle('Unlocked Achievements'),
                                  const SizedBox(height: 15),
                                  ..._achievements
                                      .where((a) => a['unlocked'] == true)
                                      .map(
                                        (achievement) =>
                                            _buildAchievementCard(achievement),
                                      ),
                                  const SizedBox(height: 25),
                                  _buildSectionTitle('Locked Achievements'),
                                  const SizedBox(height: 15),
                                  ..._achievements
                                      .where((a) => a['unlocked'] == false)
                                      .map(
                                        (achievement) =>
                                            _buildAchievementCard(achievement),
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

  Widget _buildHeader(int unlocked, int total) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Achievements',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$unlocked of $total unlocked',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressCard(int unlocked, int total) {
    final percentage = total > 0 ? (unlocked / total * 100).toInt() : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.emoji_events, color: Colors.white, size: 50),
          const SizedBox(height: 15),
          Text(
            '$percentage% Complete',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: unlocked / total,
              backgroundColor: Colors.white.withOpacity(0.3),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '$unlocked / $total achievements',
            style: const TextStyle(fontSize: 14, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildAchievementCard(Map<String, dynamic> achievement) {
    final isUnlocked = achievement['unlocked'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isUnlocked
            ? achievement['color'].withOpacity(0.1)
            : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isUnlocked
              ? achievement['color'].withOpacity(0.3)
              : Colors.grey.shade300,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: isUnlocked
                  ? LinearGradient(
                      colors: [
                        achievement['color'],
                        achievement['color'].withOpacity(0.7),
                      ],
                    )
                  : null,
              color: isUnlocked ? null : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(
              achievement['icon'],
              color: isUnlocked ? Colors.white : Colors.grey.shade600,
              size: 32,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement['title'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isUnlocked ? Colors.black87 : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement['description'],
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                if (!isUnlocked && achievement.containsKey('progress')) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: LinearProgressIndicator(
                      value: achievement['progress'] as double,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        achievement['color'],
                      ),
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${((achievement['progress'] as double) * 100).toInt()}% complete',
                    style: TextStyle(
                      fontSize: 11,
                      color: achievement['color'],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
                if (isUnlocked && achievement.containsKey('date')) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        size: 12,
                        color: Colors.grey.shade600,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Unlocked ${_formatDate(achievement['date'])}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (isUnlocked)
            Icon(Icons.check_circle, color: achievement['color'], size: 28),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
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
