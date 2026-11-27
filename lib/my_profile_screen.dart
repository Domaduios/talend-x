import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'dart:math' as math;
import 'edit_profile_screen.dart';
import 'utils/app_localizations.dart';
import 'favorites_screen.dart';
import 'reviews_screen.dart';
import 'connections_screen.dart';
import 'activity_screen.dart';
import 'learning_progress_screen.dart';
import 'teaching_dashboard_screen.dart';
import 'change_password_screen.dart';
import 'help_screen.dart';
import 'about_screen.dart';
import 'achievements_screen.dart';
import 'blocked_users_screen.dart';
import 'privacy_settings_screen.dart';
import 'language_screen.dart';
import 'theme_screen.dart';
import 'terms_screen.dart';
import 'privacy_policy_screen.dart';

class MyProfileScreen extends StatefulWidget {
  const MyProfileScreen({Key? key}) : super(key: key);

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen>
    with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  Map<String, dynamic>? _myData;
  Map<String, dynamic>? _stats;
  List<Map<String, dynamic>> _achievements = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
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
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _fadeController.forward();

    _tabController = TabController(length: 3, vsync: this);
  }

  Future<void> _loadUserData() async {
    final user = SupabaseService.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await SupabaseDb.instance
          .collection('users')
          .doc(user.id)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData == null) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
          return;
        }
        
        // Calculate real statistics with error handling
        int teachingSessions = 0;
        int learningSessions = 0;
        double hoursTeaching = 0;
        double hoursLearning = 0;
        double averageRating = 0.0;
        int totalConnections = 0;
        int totalScheduled = 0;
        int reviewsCount = 0;
        
        try {
          // Get completed sessions where user is teacher
          final completedTeacherSessions = await SupabaseDb.instance
              .collection('sessions')
              .where('teacherId', isEqualTo: user.id)
              .where('status', isEqualTo: 'completed')
              .limit(100)
              .get();
          
          teachingSessions = completedTeacherSessions.docs.length;
          for (var sessionDoc in completedTeacherSessions.docs) {
            final sessionData = sessionDoc.data();
            final duration = (sessionData['duration'] as num?)?.toDouble() ?? 60.0;
            hoursTeaching += duration / 60.0;
          }
        } catch (e) {
          print('Error loading teacher sessions: $e');
        }
        
        try {
          // Get completed sessions where user is learner
          final completedLearnerSessions = await SupabaseDb.instance
              .collection('sessions')
              .where('learnerId', isEqualTo: user.id)
              .where('status', isEqualTo: 'completed')
              .limit(100)
              .get();
          
          learningSessions = completedLearnerSessions.docs.length;
          for (var sessionDoc in completedLearnerSessions.docs) {
            final sessionData = sessionDoc.data();
            final duration = (sessionData['duration'] as num?)?.toDouble() ?? 60.0;
            hoursLearning += duration / 60.0;
          }
        } catch (e) {
          print('Error loading learner sessions: $e');
        }
        
        final totalSessions = teachingSessions + learningSessions;
        
        try {
          // Get average rating from reviews
          final reviewsQuery = await SupabaseDb.instance
              .collection('reviews')
              .where('reviewedUserId', isEqualTo: user.id)
              .limit(100)
              .get();
          
          reviewsCount = reviewsQuery.docs.length;
          if (reviewsQuery.docs.isNotEmpty) {
            double totalRating = 0;
            for (var reviewDoc in reviewsQuery.docs) {
              totalRating += (reviewDoc.data()['rating'] as num?)?.toDouble() ?? 0.0;
            }
            averageRating = totalRating / reviewsQuery.docs.length;
          }
        } catch (e) {
          print('Error loading reviews: $e');
        }
        
        try {
          // Get total connections
          final connectionsQuery = await SupabaseDb.instance
              .collection('connections')
              .where('userId', isEqualTo: user.id)
              .where('status', isEqualTo: 'accepted')
              .limit(100)
              .get();
          
          totalConnections = connectionsQuery.docs.length;
        } catch (e) {
          print('Error loading connections: $e');
        }
        
        try {
          // Calculate success rate (completed / total scheduled)
          // Get sessions where user is teacher
          final teacherSessionsQuery = await SupabaseDb.instance
              .collection('sessions')
              .where('teacherId', isEqualTo: user.id)
              .limit(100)
              .get();
          
          // Get sessions where user is learner
          final learnerSessionsQuery = await SupabaseDb.instance
              .collection('sessions')
              .where('learnerId', isEqualTo: user.id)
              .limit(100)
              .get();
          
          // Combine and deduplicate
          final Set<String> sessionIds = {};
          sessionIds.addAll(teacherSessionsQuery.docs.map((doc) => doc.id));
          sessionIds.addAll(learnerSessionsQuery.docs.map((doc) => doc.id));
          
          totalScheduled = sessionIds.length;
        } catch (e) {
          print('Error loading all sessions: $e');
        }
          final successRate = totalScheduled > 0 
              ? ((totalSessions / totalScheduled) * 100).round()
              : 0;
          
        // Calculate experience (time since joined)
        final joinedDate = parseDbDate(userData['createdAt']) ??
            DateTime.now().subtract(const Duration(days: 365));
        final experienceYears = DateTime.now().difference(joinedDate).inDays ~/ 365;
        final experienceText = experienceYears > 0 
            ? '$experienceYears ${experienceYears == 1 ? 'year' : 'years'}'
            : 'Less than a year';

        if (mounted) {
          setState(() {
            _myData = {
              'name': userData['name'] ?? user.userMetadata?['name'] as String? ?? 'User',
              'email': userData['email'] ?? user.email ?? '',
              'phone': userData['phone'] ?? 'Not provided',
              'faculty': userData['faculty'] ?? '',
              'bio': userData['bio'] ?? 'No bio available',
              'teachSkills': List<String>.from(userData['teachSkills'] ?? []),
              'learnSkills': List<String>.from(userData['learnSkills'] ?? []),
              'rating': averageRating,
              'sessionsCompleted': totalSessions,
              'totalConnections': totalConnections,
              'responseTime': userData['responseTime'] ?? '< 1 hour',
              'availability': userData['availability'] ?? 'Available',
              'experience': experienceText,
              'joinedDate': joinedDate,
            };

            _stats = {
              'totalSessions': totalSessions,
              'hoursTeaching': hoursTeaching,
              'hoursLearning': hoursLearning,
              'averageRating': averageRating,
              'successRate': successRate,
            };

            // Calculate achievements based on real data
            _achievements = [
              {
                'title': 'Top Teacher',
                'description': 'Completed 10+ sessions',
                'icon': Icons.school,
                'color': Colors.blue,
                'earned': teachingSessions >= 10,
              },
              {
                'title': 'Quick Responder',
                'description': 'Response time < 1 hour',
                'icon': Icons.speed,
                'color': Colors.green,
                'earned': (userData['responseTime'] ?? '').contains('< 1 hour'),
              },
              {
                'title': '5-Star Rating',
                'description': 'Maintain 4.5+ rating',
                'icon': Icons.star,
                'color': Colors.amber,
                'earned': averageRating >= 4.5 && reviewsCount > 0,
              },
              {
                'title': 'Early Adopter',
                'description': 'Joined in first month',
                'icon': Icons.emoji_events,
                'color': Colors.purple,
                'earned': DateTime.now().difference(joinedDate).inDays <= 30,
              },
            ];

            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        // Set default values if error occurs to allow screen to open
        final currentUser = SupabaseService.currentUser;
        setState(() {
          _myData = {
            'name': currentUser?.userMetadata?['name'] as String? ?? 'User',
            'email': currentUser?.email ?? '',
            'phone': 'Not provided',
            'faculty': '',
            'bio': 'No bio available',
            'teachSkills': [],
            'learnSkills': [],
            'rating': 0.0,
            'sessionsCompleted': 0,
            'totalConnections': 0,
            'responseTime': '< 1 hour',
            'availability': 'Available',
            'experience': 'Less than a year',
            'joinedDate': DateTime.now(),
          };
          _stats = {
            'totalSessions': 0,
            'hoursTeaching': 0.0,
            'hoursLearning': 0.0,
            'averageRating': 0.0,
            'successRate': 0,
          };
          _achievements = [
            {
              'title': 'Top Teacher',
              'description': 'Completed 10+ sessions',
              'icon': Icons.school,
              'color': Colors.blue,
              'earned': false,
            },
            {
              'title': 'Quick Responder',
              'description': 'Response time < 1 hour',
              'icon': Icons.speed,
              'color': Colors.green,
              'earned': false,
            },
            {
              'title': '5-Star Rating',
              'description': 'Maintain 4.5+ rating',
              'icon': Icons.star,
              'color': Colors.amber,
              'earned': false,
            },
            {
              'title': 'Early Adopter',
              'description': 'Joined in first month',
              'icon': Icons.emoji_events,
              'color': Colors.purple,
              'earned': false,
            },
          ];
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _editProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const EditProfileScreen()),
    ).then((updated) {
      if (updated == true) {
        // Reload user data after successful update
        _loadUserData();
      }
    });
  }

  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _shareProfile() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.share, color: Colors.white),
            SizedBox(width: 10),
            Text('Profile link copied to clipboard!'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _myData == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
          ),
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

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
            // Main content
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
                        child: Column(
                          children: [
                            // Profile Header
                            _buildProfileHeader(),
                            // Quick Stats
                            _buildQuickStats(),
                            // Tab Bar
                            _buildTabBar(),
                            // Tab Content
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildOverviewTab(),
                                  _buildStatsTab(),
                                  _buildAchievementsTab(),
                                ],
                              ),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'My Profile',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'View and manage your profile',
                style: TextStyle(fontSize: 13, color: Colors.white70),
              ),
            ],
          ),
          Row(
            children: [
              // Share button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: _shareProfile,
                  icon: const Icon(Icons.share, color: Colors.white),
                ),
              ),
              const SizedBox(width: 10),
              // Settings button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final daysSinceJoined = DateTime.now()
        .difference(_myData!['joinedDate'] as DateTime)
        .inDays;
    final userName = _myData!['name'] as String;

    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          // Avatar with edit button
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF667eea).withOpacity(0.4),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () {
                    // Change profile picture
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Name
          Text(
            userName,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          // Faculty & Member since
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 5),
              Text(
                _myData!['faculty'] ?? '',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 10),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
              ),
              Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 5),
              Text(
                'Member for $daysSinceJoined days',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Edit Profile Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _editProfile,
              icon: const Icon(Icons.edit),
              label: Text(context.l10n.editProfile),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                padding: const EdgeInsets.symmetric(vertical: 15),
                elevation: 5,
                shadowColor: const Color(0xFF667eea).withOpacity(0.5),
              ),
            ),
          ),
          const SizedBox(height: 15),
          // Quick Actions Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FavoritesScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.favorite, size: 18),
                  label: Text(context.l10n.favorites),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const ReviewsScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.star, size: 18),
                  label: Text(context.l10n.reviews),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.amber,
                    side: const BorderSide(color: Colors.amber),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    final teachSkills = _myData!['teachSkills'] as List<String>;
    final learnSkills = _myData!['learnSkills'] as List<String>;
    final totalConnections = _myData!['totalConnections'] as int;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildQuickStatCard(
                  Icons.school,
                  '${teachSkills.length}',
                  'Teaching',
                  const Color(0xFF667eea),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const TeachingDashboardScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickStatCard(
                  Icons.auto_stories,
                  '${learnSkills.length}',
                  'Learning',
                  const Color(0xFF764ba2),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const LearningProgressScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickStatCard(
                  Icons.people,
                  '$totalConnections',
                  'Connections',
                  Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ConnectionsScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildQuickStatCard(
                  Icons.history,
                  'Recent',
                  'Activity',
                  Colors.purple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const ActivityScreen()),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatCard(
    IconData icon,
    String value,
    String label,
    Color color, {
    VoidCallback? onTap,
  }) {
    final widget = Container(
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
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: widget,
      );
    }
    return widget;
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(25, 20, 25, 0),
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
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        tabs: const [
          Tab(text: 'Overview'),
          Tab(text: 'Stats'),
          Tab(text: 'Achievements'),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Contact Info
          _buildSectionTitle(Icons.contact_mail, 'Contact Information'),
          const SizedBox(height: 15),
          _buildInfoCard(Icons.email, 'Email', _myData!['email']),
          const SizedBox(height: 10),
          _buildInfoCard(Icons.phone, 'Phone', _myData!['phone']),
          const SizedBox(height: 30),
          // Bio
          _buildSectionTitle(Icons.person_outline, 'About Me'),
          const SizedBox(height: 15),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Text(
              _myData!['bio'],
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade700,
                height: 1.6,
              ),
            ),
          ),
          const SizedBox(height: 30),
          // Teaching Skills
          _buildSectionTitle(Icons.school, 'I Can Teach'),
          const SizedBox(height: 15),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: (_myData!['teachSkills'] as List<String>).map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      skill,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),
          // Learning Skills
          _buildSectionTitle(Icons.auto_stories, 'I Want to Learn'),
          const SizedBox(height: 15),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: (_myData!['learnSkills'] as List<String>).map((skill) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF764ba2), width: 2),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.lightbulb_outline,
                      color: Color(0xFF764ba2),
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      skill,
                      style: const TextStyle(
                        color: Color(0xFF764ba2),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),
          // Availability
          _buildSectionTitle(Icons.schedule, 'Availability'),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _myData!['availability'] ?? 'Available',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Response time: ${_myData!['responseTime']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performance Overview
          _buildSectionTitle(Icons.analytics, 'Performance Overview'),
          const SizedBox(height: 20),
          _buildStatRow(
            'Total Sessions',
            '${_stats!['totalSessions']}',
            Icons.video_library,
            const Color(0xFF667eea),
          ),
          const SizedBox(height: 15),
          _buildStatRow(
            'Hours Teaching',
            '${_stats!['hoursTeaching']}h',
            Icons.school,
            Colors.green,
          ),
          const SizedBox(height: 15),
          _buildStatRow(
            'Hours Learning',
            '${_stats!['hoursLearning']}h',
            Icons.auto_stories,
            Colors.orange,
          ),
          const SizedBox(height: 15),
          _buildStatRow(
            'Average Rating',
            '${_stats!['averageRating']}⭐',
            Icons.star,
            Colors.amber,
          ),
          const SizedBox(height: 15),
          _buildStatRow(
            'Success Rate',
            '${_stats!['successRate']}%',
            Icons.check_circle,
            Colors.purple,
          ),
          const SizedBox(height: 30),
          // Rating Breakdown
          _buildSectionTitle(Icons.star_rate, 'Rating Breakdown'),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                _buildRatingBar(5, 0.7),
                _buildRatingBar(4, 0.2),
                _buildRatingBar(3, 0.08),
                _buildRatingBar(2, 0.02),
                _buildRatingBar(1, 0.0),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Activity Chart (Placeholder)
          _buildSectionTitle(Icons.show_chart, 'Activity This Month'),
          const SizedBox(height: 20),
          Container(
            height: 200,
            padding: const EdgeInsets.all(20),
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bar_chart,
                    size: 60,
                    color: const Color(0xFF667eea).withOpacity(0.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Activity Chart',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Coming soon...',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionTitle(Icons.emoji_events, 'My Achievements'),
              TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AchievementsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Achievements Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.0,
            ),
            itemCount: _achievements.length,
            itemBuilder: (context, index) {
              final achievement = _achievements[index];
              return _buildAchievementCard(achievement);
            },
          ),
          const SizedBox(height: 30),
          // Progress to next achievement
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withOpacity(0.1),
                  Colors.red.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.whatshot, color: Colors.orange, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Next Achievement',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                const Text(
                  'Skill Master',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 5),
                Text(
                  'Complete 25 sessions to unlock',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 15),
                // Progress bar
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '15 / 25 Sessions',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '60%',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: 0.6,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Colors.orange, Colors.red],
                              ),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF667eea), size: 20),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF667eea), size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade800,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingBar(int stars, double percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(
            '$stars',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.star, size: 16, color: Colors.amber),
          const SizedBox(width: 10),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    height: 8,
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${(percentage * 100).toInt()}%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAchievementCard(Map<String, dynamic> achievement) {
    final isEarned = achievement['earned'] as bool;
    final color = achievement['color'] as Color;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isEarned ? color.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isEarned ? color.withOpacity(0.3) : Colors.grey.shade300,
          width: 2,
        ),
        boxShadow: isEarned
            ? [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isEarned ? color : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(
              achievement['icon'] as IconData,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            achievement['title'] as String,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isEarned ? color : Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            achievement['description'] as String,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (isEarned) ...[
            const SizedBox(height: 8),
            const Icon(Icons.check_circle, color: Colors.green, size: 20),
          ],
        ],
      ),
    );
  }

  Widget _buildParticle(int index) {
    if (_particleControllers == null) return const SizedBox.shrink();

    final random = math.Random(index);
    final size = random.nextDouble() * 20 + 5;
    final left = random.nextDouble() * MediaQuery.of(context).size.width;
    final top = random.nextDouble() * 250;

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

// ====================================
// Settings Screen
// ====================================
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Settings states
  bool _pushNotifications = true;
  bool _emailNotifications = true;
  bool _messageNotifications = true;
  bool _sessionReminders = true;
  bool _profileVisibility = true;
  bool _showEmail = false;
  bool _showPhone = false;
  bool _allowMessages = true;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();

    // Check admin status
    _checkAdminStatus();

    // Initialize particle animations
    _particleControllers = List.generate(
      8,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: 5000 + math.Random(index).nextInt(3000),
        ),
      )..repeat(),
    );

    // Initialize fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _fadeController.forward();
  }

  Future<void> _checkAdminStatus() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;

    try {
      final userDoc = await SupabaseDb.instance
          .collection('users')
          .doc(user.id)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData == null) return;
        
        final isAdmin = userData['isAdmin'] == true || 
                       userData['role'] == 'admin' || 
                       userData['role'] == 'Admin';
        
        if (mounted) {
          setState(() {
            _isAdmin = isAdmin;
          });
        }
      }
    } catch (e) {
      print('Error checking admin status: $e');
    }
  }

  @override
  void dispose() {
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    super.dispose();
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.logout, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text('Logout', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Are you sure you want to logout from your account?',
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Logout logic and navigate to sign in
              await SupabaseService.auth.signOut();
              if (context.mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/signin', (route) => false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: const [
                        Icon(Icons.check_circle, color: Colors.white),
                        SizedBox(width: 10),
                        Text('Logged out successfully'),
                      ],
                    ),
                    backgroundColor: Colors.green,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.all(10),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Logout',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.warning, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Text(
              'Delete Account',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'This action cannot be undone!',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red),
            ),
            SizedBox(height: 10),
            Text(
              'All your data including:\n• Profile information\n• Messages\n• Sessions history\n• Connections\n\nWill be permanently deleted.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Delete account logic
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: const [
                      Icon(Icons.info, color: Colors.white),
                      SizedBox(width: 10),
                      Text('Delete account feature coming soon'),
                    ],
                  ),
                  backgroundColor: Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(10),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Delete Account',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
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
            ...List.generate(8, (index) => _buildParticle(index)),
            // Main content
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
                        child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            // Account Settings
                            _buildSettingsSection(
                              'Account',
                              Icons.person_outline,
                              [
                                _buildSettingsTile(
                                  Icons.edit_outlined,
                                  'Edit Profile',
                                  'Update your personal information',
                                  () {
                                    Navigator.pop(context);
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const EditProfileScreen(),
                                      ),
                                    );
                                  },
                                ),
                                _buildSettingsTile(
                                  Icons.lock_outline,
                                  'Change Password',
                                  'Update your password',
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const ChangePasswordScreen(),
                                      ),
                                    );
                                  },
                                ),
                                _buildSettingsTile(
                                  Icons.email_outlined,
                                  'Change Email',
                                  'Update your email address',
                                  () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Change email feature coming soon')),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 25),
                            // Notifications Settings
                            _buildSettingsSection(
                              'Notifications',
                              Icons.notifications_outlined,
                              [
                                _buildSwitchTile(
                                  Icons.notifications_active_outlined,
                                  'Push Notifications',
                                  'Receive push notifications',
                                  _pushNotifications,
                                  (value) {
                                    setState(() => _pushNotifications = value);
                                  },
                                ),
                                _buildSwitchTile(
                                  Icons.email_outlined,
                                  'Email Notifications',
                                  'Receive email updates',
                                  _emailNotifications,
                                  (value) {
                                    setState(() => _emailNotifications = value);
                                  },
                                ),
                                _buildSwitchTile(
                                  Icons.message_outlined,
                                  'Message Notifications',
                                  'Get notified of new messages',
                                  _messageNotifications,
                                  (value) {
                                    setState(
                                      () => _messageNotifications = value,
                                    );
                                  },
                                ),
                                _buildSwitchTile(
                                  Icons.schedule_outlined,
                                  'Session Reminders',
                                  'Reminders for upcoming sessions',
                                  _sessionReminders,
                                  (value) {
                                    setState(() => _sessionReminders = value);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 25),
                            // Privacy Settings
                            _buildSettingsSection(
                              'Privacy',
                              Icons.privacy_tip_outlined,
                              [
                                _buildSwitchTile(
                                  Icons.visibility_outlined,
                                  'Profile Visibility',
                                  'Show your profile to others',
                                  _profileVisibility,
                                  (value) {
                                    setState(() => _profileVisibility = value);
                                  },
                                ),
                                _buildSwitchTile(
                                  Icons.email_outlined,
                                  'Show Email',
                                  'Display email on profile',
                                  _showEmail,
                                  (value) {
                                    setState(() => _showEmail = value);
                                  },
                                ),
                                _buildSwitchTile(
                                  Icons.phone_outlined,
                                  'Show Phone',
                                  'Display phone on profile',
                                  _showPhone,
                                  (value) {
                                    setState(() => _showPhone = value);
                                  },
                                ),
                                _buildSwitchTile(
                                  Icons.chat_bubble_outline,
                                  'Allow Messages',
                                  'Allow others to message you',
                                  _allowMessages,
                                  (value) {
                                    setState(() => _allowMessages = value);
                                  },
                                ),
                                _buildSettingsTile(
                                  Icons.block_outlined,
                                  'Blocked Users',
                                  'Manage blocked users',
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const BlockedUsersScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 25),
                            // Preferences
                            _buildSettingsSection(
                              'Preferences',
                              Icons.tune_outlined,
                              [
                                _buildSettingsTile(
                                  Icons.language_outlined,
                                  'Language',
                                  'Change app language',
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const LanguageScreen(),
                                      ),
                                    );
                                  },
                                ),
                                _buildSettingsTile(
                                  Icons.brightness_6_outlined,
                                  'Theme',
                                  'Change app theme',
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const ThemeScreen(),
                                      ),
                                    );
                                  },
                                ),
                                _buildSettingsTile(
                                  Icons.privacy_tip_outlined,
                                  'Privacy Settings',
                                  'Control your privacy',
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const PrivacySettingsScreen(),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 25),
                            // Support & About
                            _buildSettingsSection(
                              'Support & About',
                              Icons.help_outline,
                              [
                                _buildSettingsTile(
                                  Icons.help_center_outlined,
                                  'Help Center',
                                  'Get help and support',
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const HelpScreen(),
                                      ),
                                    );
                                  },
                                ),
                                _buildSettingsTile(
                                  Icons.info_outline,
                                  'About',
                                  'Learn more about TalentX',
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const AboutScreen(),
                                      ),
                                    );
                                  },
                                ),
                                _buildSettingsTile(
                                  Icons.feedback_outlined,
                                  'Send Feedback',
                                  'Share your thoughts with us',
                                  () {},
                                ),
                                _buildSettingsTile(
                                  Icons.bug_report_outlined,
                                  'Report a Bug',
                                  'Help us improve the app',
                                  () {},
                                ),
                                _buildSettingsTile(
                                  Icons.star_outline,
                                  'Rate App',
                                  'Rate us on the store',
                                  () {},
                                ),
                                _buildSettingsTile(
                                  Icons.share_outlined,
                                  'Share App',
                                  'Share with your friends',
                                  () {},
                                ),
                                _buildSettingsTile(
                                  Icons.description_outlined,
                                  'Terms & Conditions',
                                  'Read our terms',
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const TermsScreen(),
                                      ),
                                    );
                                  },
                                ),
                                _buildSettingsTile(
                                  Icons.policy_outlined,
                                  'Privacy Policy',
                                  'Read our privacy policy',
                                  () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => const PrivacyPolicyScreen(),
                                      ),
                                    );
                                  },
                                ),
                                _buildSettingsTile(
                                  Icons.info_outlined,
                                  'About',
                                  'Version 1.0.0',
                                  () {},
                                ),
                              ],
                            ),
                            const SizedBox(height: 25),
                            // Admin Section (only visible to admins)
                            if (_isAdmin) ...[
                              _buildSettingsSection(
                                'Admin',
                                Icons.admin_panel_settings_outlined,
                                [
                                  _buildSettingsTile(
                                    Icons.dashboard_outlined,
                                    'Admin Dashboard',
                                    'Manage users, reports, and system settings',
                                    () {
                                      Navigator.pushNamed(context, '/admin');
                                    },
                                    color: const Color(0xFF667eea),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 25),
                            ],
                            // Danger Zone
                            _buildSettingsSection(
                              'Danger Zone',
                              Icons.warning_outlined,
                              [
                                _buildSettingsTile(
                                  Icons.delete_forever_outlined,
                                  'Delete Account',
                                  'Permanently delete your account',
                                  _showDeleteAccountDialog,
                                  color: Colors.red,
                                ),
                              ],
                            ),
                            const SizedBox(height: 30),
                            // Logout Button
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.red, Colors.redAccent],
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: _showLogoutDialog,
                                icon: const Icon(Icons.logout, size: 22),
                                label: const Text(
                                  'Logout',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            // App Version
                            Center(
                              child: Text(
                                'Skill Exchange v1.0.0',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
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
          // Back button
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
                  'Settings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Manage your preferences',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5, bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF667eea),
                ),
              ),
            ],
          ),
        ),
        Container(
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
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSettingsTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap, {
    Color? color,
  }) {
    final effectiveColor = color ?? const Color(0xFF667eea);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: effectiveColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: effectiveColor, size: 22),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 15,
          color: color,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: Colors.grey.shade400,
      ),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    Function(bool) onChanged,
  ) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF667eea).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF667eea), size: 22),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      ),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF667eea),
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
