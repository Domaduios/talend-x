import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'user_profile_screen.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({Key? key}) : super(key: key);

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen>
    with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  List<Map<String, dynamic>> _topTeachers = [];
  bool _isLoading = true;
  String _selectedPeriod = 'month'; // week, month, allTime

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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          if (_tabController.index == 0) {
            _selectedPeriod = 'week';
          } else if (_tabController.index == 1) {
            _selectedPeriod = 'month';
          } else {
            _selectedPeriod = 'allTime';
          }
        });
        _loadLeaderboard();
      }
    });
    _loadLeaderboard();
  }

  @override
  void dispose() {
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    try {
      setState(() => _isLoading = true);

      final now = DateTime.now();
      DateTime? startDate;

      if (_selectedPeriod == 'week') {
        startDate = now.subtract(const Duration(days: 7));
      } else if (_selectedPeriod == 'month') {
        startDate = now.subtract(const Duration(days: 30));
      }

      // Get all users with completed sessions
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('profileCompleted', isEqualTo: true)
          .limit(50)
          .get();

      final List<Map<String, dynamic>> teachers = [];

      for (var userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userId = userDoc.id;

        // Get completed teaching sessions
        Query query = FirebaseFirestore.instance
            .collection('sessions')
            .where('teacherId', isEqualTo: userId)
            .where('status', isEqualTo: 'completed');

        if (startDate != null) {
          query = query.where(
            'completedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate),
          );
        }

        final sessionsSnapshot = await query.get();
        final sessionsCount = sessionsSnapshot.docs.length;

        if (sessionsCount == 0) continue;

        // Get average rating
        final reviewsSnapshot = await FirebaseFirestore.instance
            .collection('reviews')
            .where('revieweeId', isEqualTo: userId)
            .get();

        double averageRating = 0.0;
        if (reviewsSnapshot.docs.isNotEmpty) {
          final ratings = reviewsSnapshot.docs
              .map((doc) => (doc.data()['rating'] as num?)?.toDouble() ?? 0.0)
              .where((r) => r > 0)
              .toList();
          if (ratings.isNotEmpty) {
            averageRating = ratings.reduce((a, b) => a + b) / ratings.length;
          }
        }

        // Calculate points (sessions * 50 + rating * 10)
        final points = (sessionsCount * 50) + (averageRating * 10).round();

        teachers.add({
          'id': userId,
          'rank': 0, // Will be set after sorting
          'name': userData['name'] ?? 'Unknown',
          'avatar': (userData['name'] ?? 'U')[0].toUpperCase(),
          'points': points,
          'sessions': sessionsCount,
          'rating': averageRating > 0 ? averageRating : 4.5,
          'badge': null,
        });
      }

      // Sort by points
      teachers.sort((a, b) => b['points'].compareTo(a['points']));

      // Assign ranks and badges
      for (int i = 0; i < teachers.length; i++) {
        teachers[i]['rank'] = i + 1;
        if (i == 0) {
          teachers[i]['badge'] = '👑';
        } else if (i == 1) {
          teachers[i]['badge'] = '🥈';
        } else if (i == 2) {
          teachers[i]['badge'] = '🥉';
        }
      }

      if (mounted) {
        setState(() {
          _topTeachers = teachers.take(20).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading leaderboard: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
                            : _topTeachers.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.emoji_events,
                                      size: 80,
                                      color: Colors.grey.shade300,
                                    ),
                                    const SizedBox(height: 20),
                                    const Text(
                                      'No Data Yet',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      'Complete sessions to appear on leaderboard',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : Column(
                                children: [
                                  if (_topTeachers.length >= 3)
                                    _buildTopThree(),
                                  _buildTabBar(),
                                  Expanded(child: _buildLeaderboardList()),
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
                  'Leaderboard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Top performers this month',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopThree() {
    if (_topTeachers.length < 3) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _buildPodiumCard(_topTeachers[1], 80, Colors.grey),
          _buildPodiumCard(_topTeachers[0], 100, Colors.amber),
          _buildPodiumCard(_topTeachers[2], 70, Colors.brown),
        ],
      ),
    );
  }

  Widget _buildPodiumCard(
    Map<String, dynamic> user,
    double height,
    Color color,
  ) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(userId: user['id']),
          ),
        );
      },
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 3),
                ),
                child: Center(
                  child: Text(
                    user['avatar'],
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (user.containsKey('badge') && user['badge'] != null)
                Positioned(
                  top: -5,
                  right: -5,
                  child: Text(
                    user['badge'],
                    style: const TextStyle(fontSize: 28),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            user['name'].split(' ')[0],
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          Container(
            width: 80,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${user['points']}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'points',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(15),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        tabs: const [
          Tab(text: 'This Week'),
          Tab(text: 'This Month'),
          Tab(text: 'All Time'),
        ],
      ),
    );
  }

  Widget _buildLeaderboardList() {
    return TabBarView(
      controller: _tabController,
      children: [_buildList(), _buildList(), _buildList()],
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _topTeachers.length,
      itemBuilder: (context, index) {
        final user = _topTeachers[index];
        return _buildLeaderboardCard(user);
      },
    );
  }

  Widget _buildLeaderboardCard(Map<String, dynamic> user) {
    final isTopThree = user['rank'] <= 3;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(userId: user['id']),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isTopThree
              ? const Color(0xFF667eea).withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isTopThree
                ? const Color(0xFF667eea).withOpacity(0.3)
                : Colors.grey.shade200,
          ),
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
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                gradient: isTopThree
                    ? const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      )
                    : null,
                color: isTopThree ? null : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${user['rank']}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isTopThree ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  user['avatar'],
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['name'],
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 5),
                      Text(
                        (user['rating'] as double).toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Icon(Icons.school, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 5),
                      Text(
                        '${user['sessions']} sessions',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${user['points']}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF667eea),
                  ),
                ),
                const Text(
                  'points',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
