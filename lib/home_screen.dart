import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'dart:async';
import 'dart:math' as math;
import 'browse_screen.dart';
import 'user_profile_screen.dart';
import 'chat_list_screen.dart';
import 'my_profile_screen.dart';
import 'notifications_screen.dart';
import 'search_screen.dart';
import 'favorites_screen.dart';
import 'reviews_screen.dart';
import 'connections_screen.dart';
import 'activity_screen.dart';
import 'learning_progress_screen.dart';
import 'teaching_dashboard_screen.dart';
import 'match_details_screen.dart';
import 'resources_screen.dart';
import 'community_screen.dart';
import 'calendar_screen.dart';
import 'leaderboard_screen.dart';
import 'wallet_screen.dart';
import 'referral_screen.dart';
import 'utils/app_localizations.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  int _selectedIndex = 0;
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // User Data from Firestore
  String userName = "User";
  String userFaculty = "";
  List<String> userTeachSkills = [];
  List<String> userLearnSkills = [];
  Map<String, dynamic>? userData;

  // Matched Users
  List<Map<String, dynamic>> _matchedUsers = [];

  // Recent Activities
  List<Map<String, dynamic>> _recentActivities = [];

  // Unread notifications count
  int _unreadNotificationsCount = 0;
  StreamSubscription<DbQuerySnapshot>? _notificationsSubscription;
  
  // Unread messages count
  int _unreadMessagesCount = 0;
  StreamSubscription<DbQuerySnapshot>? _messagesSubscription;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
    _loadMatchedUsers();
    _loadRecentActivities();
    _loadUnreadNotificationsCount();
    _setupNotificationsListener();
    _loadUnreadMessagesCount();
    _setupMessagesListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reload user data when returning to this screen
    _loadUserData();
  }

  void _initializeAnimations() {
    _particleControllers = List.generate(
      10,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: 5000 + math.Random(index).nextInt(3000),
        ),
      )..repeat(),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _fadeController.forward();
  }

  Future<void> _loadUserData() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    try {
      final userDoc = await SupabaseDb.instance
          .collection('users')
          .doc(user.id)
          .get();

      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        if (data != null) {
          setState(() {
            userData = data;
            userName = data['name'] as String? ?? user.userMetadata?['name'] as String? ?? 'User';
            userFaculty = data['faculty'] as String? ?? '';
            userTeachSkills = List<String>.from(data['teachSkills'] as List<dynamic>? ?? []);
            userLearnSkills = List<String>.from(data['learnSkills'] as List<dynamic>? ?? []);
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  Future<void> _loadMatchedUsers() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    try {
      // Get current user's skills
      final currentUserDoc = await SupabaseDb.instance
          .collection('users')
          .doc(user.id)
          .get();

      if (!currentUserDoc.exists) return;

      final currentUserData = currentUserDoc.data();
      if (currentUserData == null) return;
      
      final currentTeachSkills = List<String>.from(
        currentUserData['teachSkills'] as List<dynamic>? ?? [],
      );
      final currentLearnSkills = List<String>.from(
        currentUserData['learnSkills'] as List<dynamic>? ?? [],
      );

      // Find users with matching skills
      final allUsers = await SupabaseDb.instance
          .collection('users')
          .where('profileCompleted', isEqualTo: true)
          .get();

      List<Map<String, dynamic>> matches = [];

      for (var doc in allUsers.docs) {
        if (doc.id == user.id) continue; // Skip current user

        final otherUserData = doc.data();
        final otherTeachSkills = List<String>.from(
          otherUserData['teachSkills'] ?? [],
        );
        final otherLearnSkills = List<String>.from(
          otherUserData['learnSkills'] ?? [],
        );

        // Calculate match: user wants to learn what other can teach
        int matchCount = 0;
        for (var skill in currentLearnSkills) {
          if (otherTeachSkills.contains(skill)) {
            matchCount++;
          }
        }

        // Also check if other wants to learn what user can teach
        for (var skill in currentTeachSkills) {
          if (otherLearnSkills.contains(skill)) {
            matchCount++;
          }
        }

        if (matchCount > 0) {
          final totalSkills =
              (currentLearnSkills.length + currentTeachSkills.length);
          final matchPercentage = ((matchCount / totalSkills) * 100).round();

          matches.add({
            'id': doc.id,
            'name': otherUserData['name'] ?? 'Unknown',
            'faculty': otherUserData['faculty'] ?? '',
            'teachSkills': otherTeachSkills,
            'learnSkills': otherLearnSkills,
            'matchPercentage': matchPercentage.clamp(0, 100),
            'rating': 4.5,
            'availability': otherUserData['availability'] ?? 'Available',
            'bio': otherUserData['bio'] ?? 'No bio available',
          });
        }
      }

      // Sort by match percentage
      matches.sort(
        (a, b) => b['matchPercentage'].compareTo(a['matchPercentage']),
      );

      if (mounted) {
        setState(() {
          _matchedUsers = matches.take(10).toList();
        });
      }
    } catch (e) {
      print('Error loading matched users: $e');
    }
  }

  Future<void> _loadUnreadNotificationsCount() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    try {
      final unreadQuery = await SupabaseDb.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.id)
          .where('read', isEqualTo: false)
          .get();

      if (mounted) {
        setState(() {
          _unreadNotificationsCount = unreadQuery.docs.length;
        });
      }
    } catch (e) {
      print('Error loading unread notifications count: $e');
    }
  }

  void _setupNotificationsListener() {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    _notificationsSubscription = SupabaseDb.instance
        .collection('notifications')
        .where('userId', isEqualTo: user.id)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _unreadNotificationsCount = snapshot.docs.length;
            });
          }
        });
  }

  Future<void> _loadRecentActivities() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    try {
      final List<Map<String, dynamic>> activities = [];

      // Get recent notifications
      final notificationsQuery = await SupabaseDb.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.id)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();

      for (var doc in notificationsQuery.docs) {
        final data = doc.data();
        final createdAt = parseDbDate(data['createdAt']);
        final type = data['type'] ?? 'general';

        IconData icon = Icons.notifications;
        Color color = Colors.blue;
        String activityType = 'notification';

        if (type == 'connection') {
          icon = Icons.person_add;
          color = Colors.blue;
          activityType = 'new_match';
        } else if (type == 'review') {
          icon = Icons.star;
          color = Colors.amber;
          activityType = 'review_received';
        }

        activities.add({
          'type': activityType,
          'user': data['senderName'] ?? 'System',
          'skill': data['message'] ?? '',
          'time': createdAt?.toDate() ?? DateTime.now(),
          'icon': icon,
          'color': color,
        });
      }

      // Sort by time
      activities.sort(
        (a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime),
      );

      if (mounted) {
        setState(() {
          _recentActivities = activities.take(5).map((activity) {
            final time = activity['time'] as DateTime;
            final now = DateTime.now();
            final difference = now.difference(time);

            String timeStr;
            if (difference.inMinutes < 60) {
              timeStr = '${difference.inMinutes}m ago';
            } else if (difference.inHours < 24) {
              timeStr = '${difference.inHours}h ago';
            } else {
              timeStr = '${difference.inDays}d ago';
            }

            return {...activity, 'time': timeStr};
          }).toList();
        });
      }
    } catch (e) {
      print('Error loading recent activities: $e');
      // Fallback to empty list
      if (mounted) {
        setState(() {
          _recentActivities = [];
        });
      }
    }
  }

  Future<void> _loadUnreadMessagesCount() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    try {
      final unreadQuery = await SupabaseDb.instance
          .collection('messages')
          .where('receiverId', isEqualTo: user.id)
          .where('read', isEqualTo: false)
          .get();

      if (mounted) {
        setState(() {
          _unreadMessagesCount = unreadQuery.docs.length;
        });
      }
    } catch (e) {
      print('Error loading unread messages count: $e');
    }
  }

  void _setupMessagesListener() {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    _messagesSubscription = SupabaseDb.instance
        .collection('messages')
        .where('receiverId', isEqualTo: user.id)
        .where('read', isEqualTo: false)
        .snapshots()
        .listen((snapshot) {
          if (mounted) {
            setState(() {
              _unreadMessagesCount = snapshot.docs.length;
            });
          }
        });
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    _messagesSubscription?.cancel();
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    super.dispose();
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
            // Floating particles
            ...List.generate(10, (index) => _buildParticle(index)),
            // Main Content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    // Header
                    _buildHeader(),
                    // Content
                    Expanded(
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(30),
                            topRight: Radius.circular(30),
                          ),
                        ),
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 100),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 25),
                              // Stats Cards
                              _buildStatsSection(),
                              const SizedBox(height: 30),
                              // Matched Users Section
                              _buildSectionHeader(
                                'Perfect Matches For You',
                                'Based on your learning goals',
                                Icons.people_alt_outlined,
                              ),
                              _buildMatchedUsersSection(),
                              const SizedBox(height: 30),
                              // Your Skills Overview
                              _buildSectionHeader(
                                'Your Skills',
                                'What you teach and learn',
                                Icons.auto_awesome,
                              ),
                              _buildSkillsOverview(),
                              const SizedBox(height: 30),
                              // Recent Activities
                              _buildSectionHeader(
                                'Recent Activities',
                                'Your latest interactions',
                                Icons.history,
                              ),
                              _buildRecentActivities(),
                              const SizedBox(height: 30),
                              // Quick Actions
                              _buildSectionHeader(
                                'Quick Actions',
                                'What would you like to do?',
                                Icons.flash_on,
                              ),
                              _buildQuickActions(),
                              const SizedBox(height: 20),
                            ],
                          ),
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
      bottomNavigationBar: _buildBottomNavBar(),
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(25, 20, 25, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.welcomeBack,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    if (userFaculty.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.school,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              userFaculty,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Profile Avatar & Notifications
              Row(
                children: [
                  // Notifications
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        IconButton(
                          onPressed: () {
                            // Navigate to Notifications Screen
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const NotificationsScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.notifications_outlined,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        if (_unreadNotificationsCount > 0)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Profile Avatar
                  GestureDetector(
                    onTap: () {
                      // Navigate to My Profile Screen
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MyProfileScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF667eea),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _buildStatCard(
            icon: Icons.school_outlined,
            label: 'Teaching',
            value: '${userTeachSkills.length}',
            color: const Color(0xFF667eea),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: Icons.auto_stories_outlined,
            label: 'Learning',
            value: '${userLearnSkills.length}',
            color: const Color(0xFF764ba2),
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            icon: Icons.people_outline,
            label: 'Matches',
            value: '${_matchedUsers.length}',
            color: Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
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
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF667eea),
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              // See all action
            },
            child: const Text(
              'See All',
              style: TextStyle(
                color: Color(0xFF667eea),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchedUsersSection() {
    if (_matchedUsers.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            children: [
              Icon(Icons.people_outline, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No matches found yet',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Complete your profile to find matches',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 280,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _matchedUsers.length,
        itemBuilder: (context, index) {
          final user = _matchedUsers[index];
          return _buildUserCard(user);
        },
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 15,
            spreadRadius: 2,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with avatar and match percentage
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667eea).withOpacity(0.8),
                  const Color(0xFF764ba2).withOpacity(0.8),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      user['name'][0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF667eea),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user['faculty'] ?? '',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Body
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Match percentage
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 16,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${user['matchPercentage']}% Match',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 16),
                          const SizedBox(width: 3),
                          Text(
                            user['rating'].toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Can teach
                  Text(
                    'Can teach:',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 5,
                    runSpacing: 5,
                    children: ((user['teachSkills'] as List<dynamic>?) ?? []).take(2).map(
                      (skill) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF667eea).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            skill,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF667eea),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ).toList(),
                  ),
                  const Spacer(),
                  // Match percentage button
                  InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MatchDetailsScreen(matchData: user),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite,
                            color: Colors.red,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${user['matchPercentage']}% Match',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Connect Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // Navigate to user profile
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                UserProfileScreen(userData: user),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF667eea),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Connect',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsOverview() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Teaching Skills
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667eea).withOpacity(0.1),
                  const Color(0xFF764ba2).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: const Color(0xFF667eea).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.school,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'I Can Teach',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF667eea),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (userTeachSkills.isEmpty)
                  Text(
                    'No teaching skills added yet',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: userTeachSkills.map((skill) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF667eea),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          skill,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Learning Skills
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF764ba2).withOpacity(0.1),
                  const Color(0xFF667eea).withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: const Color(0xFF764ba2).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF764ba2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.auto_stories,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'I Want to Learn',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF764ba2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (userLearnSkills.isEmpty)
                  Text(
                    'No learning skills added yet',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: userLearnSkills.map((skill) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF764ba2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          skill,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivities() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: _recentActivities.map((activity) {
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
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: activity['color'].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    activity['icon'],
                    color: activity['color'],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RichText(
                        text: TextSpan(
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                          children: [
                            TextSpan(
                              text: activity['user'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: activity['type'] == 'new_match'
                                  ? ' wants to learn '
                                  : ' gave you a 5-star review for ',
                            ),
                            TextSpan(
                              text: activity['skill'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF667eea),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        activity['time'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            children: [
              _buildActionButton(
                icon: Icons.explore,
                label: 'Browse',
                color: const Color(0xFF667eea),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const BrowseScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.search,
                label: 'Search',
                color: const Color(0xFF764ba2),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SearchScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActionButton(
                icon: Icons.chat_bubble_outline,
                label: context.l10n.messages,
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ChatListScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.favorite,
                label: 'Favorites',
                color: Colors.red,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const FavoritesScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.star,
                label: 'Reviews',
                color: Colors.amber,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReviewsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActionButton(
                icon: Icons.people,
                label: 'Connections',
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ConnectionsScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.history,
                label: 'Activity',
                color: Colors.indigo,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ActivityScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.trending_up,
                label: 'Progress',
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LearningProgressScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActionButton(
                icon: Icons.school,
                label: 'Teaching',
                color: Colors.deepPurple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TeachingDashboardScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActionButton(
                icon: Icons.calendar_today,
                label: 'Calendar',
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CalendarScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.library_books,
                label: 'Resources',
                color: Colors.indigo,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ResourcesScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.groups,
                label: 'Community',
                color: Colors.cyan,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CommunityScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildActionButton(
                icon: Icons.emoji_events,
                label: 'Leaderboard',
                color: Colors.amber,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LeaderboardScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.account_balance_wallet,
                label: 'Wallet',
                color: Colors.green,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const WalletScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(width: 12),
              _buildActionButton(
                icon: Icons.card_giftcard,
                label: 'Referral',
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ReferralScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
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
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
          // Handle navigation
          if (index == 1) {
            // Navigate to Browse Screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const BrowseScreen()),
            ).then((_) {
              // Update selected index when returning
              if (mounted) {
                setState(() {
                  _selectedIndex = 0;
                });
              }
            });
          } else if (index == 3) {
            // Navigate to Chat List Screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ChatListScreen()),
            ).then((_) {
              // Update selected index when returning
              if (mounted) {
                setState(() {
                  _selectedIndex = 0;
                });
                // Reload unread messages count
                _loadUnreadMessagesCount();
              }
            });
          } else if (index == 4) {
            // Navigate to My Profile Screen
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyProfileScreen()),
            ).then((_) {
              // Update selected index when returning
              if (mounted) {
                setState(() {
                  _selectedIndex = 0;
                });
                // Reload user data when returning from profile
                _loadUserData();
              }
            });
          }
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF667eea),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        elevation: 0,
        backgroundColor: Colors.transparent,
        items: [
          BottomNavigationBarItem(
            icon: const Icon(Icons.home_outlined),
            activeIcon: const Icon(Icons.home),
            label: context.l10n.home,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.explore_outlined),
            activeIcon: const Icon(Icons.explore),
            label: context.l10n.explore,
          ),
          const BottomNavigationBarItem(
            icon: SizedBox(width: 40), // Space for FAB
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              children: [
                const Icon(Icons.chat_bubble_outline),
                if (_unreadMessagesCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            ),
            activeIcon: Stack(
              children: [
                const Icon(Icons.chat_bubble),
                if (_unreadMessagesCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            ),
            label: context.l10n.messages,
          ),
          BottomNavigationBarItem(
            icon: const Icon(Icons.person_outline),
            activeIcon: const Icon(Icons.person),
            label: context.l10n.profile,
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Container(
      width: 65,
      height: 65,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF667eea).withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () {
          // Navigate to Browse Screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const BrowseScreen()),
          );
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: const Icon(Icons.add, size: 32, color: Colors.white),
      ),
    );
  }

  Widget _buildParticle(int index) {
    if (_particleControllers == null) return const SizedBox.shrink();

    final random = math.Random(index);
    final size = random.nextDouble() * 20 + 5;
    final left = random.nextDouble() * MediaQuery.of(context).size.width;
    final top = random.nextDouble() * 300; // Only in header area

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
