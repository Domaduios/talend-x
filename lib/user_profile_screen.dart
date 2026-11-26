import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'match_details_screen.dart';
import 'report_user_screen.dart';
import 'individual_chat_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  final String? userId;

  const UserProfileScreen({Key? key, this.userData, this.userId})
    : assert(
        userData != null || userId != null,
        'Either userData or userId must be provided',
      ),
      super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen>
    with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  bool _isFavorite = false;
  bool _isConnected = false;
  bool _isLoading = false;

  // Session scheduling state
  bool _isVideoCall = true; // true for video call, false for chat only
  String _selectedDuration = '60 min'; // Default duration

  // User data (loaded from Firestore if userId provided)
  Map<String, dynamic>? _userData;

  // Reviews Data (can be loaded from Firestore later)
  List<Map<String, dynamic>> _reviews = [];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    if (widget.userData != null) {
      _userData = widget.userData;
      _loadReviews();
      _checkFavoriteStatus();
      _checkConnectionStatus();
    } else if (widget.userId != null) {
      _loadUserDataFromFirestore();
    }
  }

  Future<void> _loadUserDataFromFirestore() async {
    if (widget.userId == null) return;

    setState(() => _isLoading = true);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get user data
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (!userDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('User not found'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      final userData = userDoc.data();
      if (userData == null) return;

      final otherTeachSkills = List<String>.from(
        userData['teachSkills'] as List<dynamic>? ?? [],
      );
      final otherLearnSkills = List<String>.from(
        userData['learnSkills'] as List<dynamic>? ?? [],
      );

      // Get current user's skills for match calculation
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      int matchPercentage = 0;
      if (currentUserDoc.exists) {
        final currentUserData = currentUserDoc.data();
        if (currentUserData != null) {
          final currentTeachSkills = List<String>.from(
            currentUserData['teachSkills'] as List<dynamic>? ?? [],
          );
          final currentLearnSkills = List<String>.from(
            currentUserData['learnSkills'] as List<dynamic>? ?? [],
          );

          int matchCount = 0;
          for (var skill in currentLearnSkills) {
            if (otherTeachSkills.contains(skill)) matchCount++;
          }
          for (var skill in currentTeachSkills) {
            if (otherLearnSkills.contains(skill)) matchCount++;
          }

          final totalSkills =
              (currentLearnSkills.length + currentTeachSkills.length);
          matchPercentage = totalSkills > 0
              ? ((matchCount / totalSkills) * 100).round()
              : 0;
        }
      }

      // Get real stats
      int sessionsCompleted = 0;
      double averageRating = 0.0;

      try {
        final sessionsQuery = await FirebaseFirestore.instance
            .collection('sessions')
            .where('status', isEqualTo: 'completed')
            .where(
              Filter.or(
                Filter('learnerId', isEqualTo: widget.userId),
                Filter('teacherId', isEqualTo: widget.userId),
              ),
            )
            .get();
        sessionsCompleted = sessionsQuery.docs.length;

        double totalRating = 0;
        int ratingCount = 0;
        for (var sessionDoc in sessionsQuery.docs) {
          final sessionData = sessionDoc.data();
          if (sessionData['rating'] != null) {
            totalRating += (sessionData['rating'] as num).toDouble();
            ratingCount++;
          }
        }
        averageRating = ratingCount > 0 ? totalRating / ratingCount : 0.0;
      } catch (e) {
        print('Error loading user stats: $e');
      }

      if (mounted) {
        setState(() {
          _userData = {
            'id': widget.userId,
            'name': userData['name'] ?? 'Unknown',
            'faculty': userData['faculty'] ?? '',
            'teachSkills': otherTeachSkills,
            'learnSkills': otherLearnSkills,
            'matchPercentage': matchPercentage.clamp(0, 100),
            'rating': averageRating > 0 ? averageRating : 4.5,
            'sessionsCompleted': sessionsCompleted,
            'availability': userData['availability'] ?? 'Available',
            'bio': userData['bio'] ?? 'No bio available',
            'responseTime': userData['responseTime'] ?? '< 1 hour',
          };
          _isLoading = false;
        });
        _loadReviews();
        _checkFavoriteStatus();
        _checkConnectionStatus();
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _checkFavoriteStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _userData == null) return;

    try {
      final favoriteId = _userData!['id'] ?? widget.userId;
      if (favoriteId == null) return;

      final favoriteQuery = await FirebaseFirestore.instance
          .collection('favorites')
          .where('userId', isEqualTo: currentUser.uid)
          .where('favoriteUserId', isEqualTo: favoriteId)
          .get();

      if (mounted) {
        setState(() {
          _isFavorite = favoriteQuery.docs.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error checking favorite status: $e');
    }
  }

  Future<void> _checkConnectionStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    try {
      final userId = widget.userData?['id'] ?? widget.userId;
      if (userId == null) return;

      // Check if there's a pending or accepted connection
      final connectionQuery = await FirebaseFirestore.instance
          .collection('connections')
          .where(
            Filter.or(
              Filter.and(
                Filter('userId', isEqualTo: currentUser.uid),
                Filter('connectedUserId', isEqualTo: userId),
              ),
              Filter.and(
                Filter('userId', isEqualTo: userId),
                Filter('connectedUserId', isEqualTo: currentUser.uid),
              ),
            ),
          )
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _isConnected = connectionQuery.docs.isNotEmpty;
        });
      }
    } catch (e) {
      print('Error checking connection status: $e');
    }
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

    // Initialize tab controller
    _tabController = TabController(length: 3, vsync: this);
  }

  Future<void> _loadReviews() async {
    final userId = widget.userData?['id'] ?? widget.userId;
    if (userId == null) return;

    try {
      final reviewsQuery = await FirebaseFirestore.instance
          .collection('reviews')
          .where('reviewedUserId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final List<Map<String, dynamic>> reviews = [];

      for (var doc in reviewsQuery.docs) {
        final data = doc.data();
        final reviewerId = data['reviewerId'] as String?;

        if (reviewerId != null) {
          final reviewerDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(reviewerId)
              .get();

          if (reviewerDoc.exists) {
            final reviewerData = reviewerDoc.data();
            if (reviewerData != null) {
              final reviewerName = reviewerData['name'] as String? ?? 'Unknown';
              final reviewerAvatar = reviewerName.isNotEmpty
                  ? reviewerName[0]
                  : '?';
              final timestamp =
                  (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

              reviews.add({
                'reviewerName': reviewerName,
                'reviewerAvatar': reviewerAvatar,
                'rating': (data['rating'] as num?)?.toDouble() ?? 0.0,
                'date': _formatReviewDate(timestamp),
                'comment': data['comment'] as String? ?? '',
                'skill': data['skill'] as String? ?? 'Teaching',
              });
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _reviews = reviews;
        });
      }
    } catch (e) {
      print('Error loading reviews: $e');
    }
  }

  String _formatReviewDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else if (difference.inDays < 30) {
      final weeks = difference.inDays ~/ 7;
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  void dispose() {
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _userData == null) return;

    final targetUserId = _userData!['id'] ?? widget.userId;
    if (targetUserId == null) return;

    try {
      if (!_isFavorite) {
        // Add to favorites
        // Check if already exists
        final existingFavorite = await FirebaseFirestore.instance
            .collection('favorites')
            .where('userId', isEqualTo: currentUser.uid)
            .where('favoriteUserId', isEqualTo: targetUserId)
            .limit(1)
            .get();

        if (existingFavorite.docs.isEmpty) {
          await FirebaseFirestore.instance.collection('favorites').add({
            'userId': currentUser.uid,
            'favoriteUserId': targetUserId,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }

        if (mounted) {
          setState(() => _isFavorite = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.favorite, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Added to favorites'),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Remove from favorites
        final favoriteQuery = await FirebaseFirestore.instance
            .collection('favorites')
            .where('userId', isEqualTo: currentUser.uid)
            .where('favoriteUserId', isEqualTo: targetUserId)
            .limit(1)
            .get();

        for (var doc in favoriteQuery.docs) {
          await doc.reference.delete();
        }

        if (mounted) {
          setState(() => _isFavorite = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.favorite_border, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Removed from favorites'),
                ],
              ),
              backgroundColor: Colors.grey.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error toggling favorite: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _sendMessage() {
    if (_userData == null) return;

    final userId = _userData!['id'] ?? widget.userId;
    if (userId == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => IndividualChatScreen(
          userData: {
            'id': userId,
            'userId': userId,
            'name': _userData!['name'] ?? 'User',
            'avatar': (_userData!['name'] ?? 'U')[0].toUpperCase(),
            'isOnline': _userData!['isOnline'] ?? false,
            'faculty': _userData!['faculty'] ?? '',
          },
        ),
      ),
    );
  }

  // Keep this method for future use (connection requests)
  // ignore: unused_element
  Future<void> _connectWithUser() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userId = widget.userData?['id'] ?? widget.userId;
    if (userId == null) return;

    try {
      if (!_isConnected) {
        // Send connection request
        // Check if request already exists
        final existingRequest = await FirebaseFirestore.instance
            .collection('connections')
            .where('userId', isEqualTo: currentUser.uid)
            .where('connectedUserId', isEqualTo: userId)
            .limit(1)
            .get();

        if (existingRequest.docs.isEmpty) {
          await FirebaseFirestore.instance.collection('connections').add({
            'userId': currentUser.uid,
            'connectedUserId': userId,
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          });

          // Create notification for the other user
          await FirebaseFirestore.instance.collection('notifications').add({
            'userId': userId,
            'type': 'connection',
            'title': 'New Connection Request',
            'message':
                '${currentUser.displayName ?? 'Someone'} wants to connect with you',
            'fromUserId': currentUser.uid,
            'isRead': false,
            'timestamp': FieldValue.serverTimestamp(),
          });
        }

        if (mounted) {
          setState(() => _isConnected = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Connection request sent!'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        // Remove connection (only if pending)
        final connectionQuery = await FirebaseFirestore.instance
            .collection('connections')
            .where(
              Filter.or(
                Filter.and(
                  Filter('userId', isEqualTo: currentUser.uid),
                  Filter('connectedUserId', isEqualTo: userId),
                ),
                Filter.and(
                  Filter('userId', isEqualTo: userId),
                  Filter('connectedUserId', isEqualTo: currentUser.uid),
                ),
              ),
            )
            .where('status', isEqualTo: 'pending')
            .limit(1)
            .get();

        if (connectionQuery.docs.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('connections')
              .doc(connectionQuery.docs.first.id)
              .delete();
        }

        if (mounted) {
          setState(() => _isConnected = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.person_remove, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Connection request removed'),
                ],
              ),
              backgroundColor: Colors.grey.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      print('Error managing connection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _reportUser() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportUserScreen(
          userData: {
            'id': widget.userId ?? _userData?['id'],
            'userId': widget.userId,
            'name': _userData?['name'] ?? 'Unknown',
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_userData == null) {
      return Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
          ),
          child: const Center(child: Text('User not found')),
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
                    // Custom Header
                    _buildHeader(),
                    // Scrollable Content
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
                            // Stats Row
                            _buildStatsRow(),
                            // Tab Bar
                            _buildTabBar(),
                            // Tab Content
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildAboutTab(),
                                  _buildSkillsTab(),
                                  _buildReviewsTab(),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Bottom Action Buttons
                    _buildBottomActions(),
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
          // Actions
          Row(
            children: [
              // Favorite button
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: _toggleFavorite,
                  icon: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // More options
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: PopupMenuButton(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.share, color: Color(0xFF667eea)),
                          SizedBox(width: 10),
                          Text('Share Profile'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(Icons.block, color: Colors.orange),
                          SizedBox(width: 10),
                          Text('Block User'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'report',
                      child: Row(
                        children: [
                          Icon(Icons.report, color: Colors.red),
                          SizedBox(width: 10),
                          Text('Report User'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) {
                    if (value == 'report') {
                      _reportUser();
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    if (_userData == null) return const SizedBox.shrink();
    final userName = _userData!['name'] ?? 'Unknown';
    final userFaculty = _userData!['faculty'] ?? '';
    final availability = _userData!['availability'] ?? 'Available';
    final matchPercentage = _userData!['matchPercentage'] ?? 0;

    return Padding(
      padding: const EdgeInsets.all(25),
      child: Column(
        children: [
          // Avatar
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
              // Online indicator
              Positioned(
                bottom: 5,
                right: 5,
                child: Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: availability == 'Available'
                        ? Colors.green
                        : Colors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
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
          // Faculty & Experience
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.school, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 5),
              Text(
                userFaculty,
                style: TextStyle(
                  fontSize: 15,
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
              Icon(Icons.work_outline, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 5),
              Text(
                '2 years',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // Match percentage badge
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MatchDetailsScreen(
                    matchData: {
                      'id': _userData!['id'] ?? widget.userId,
                      'name': userName,
                      'faculty': _userData!['faculty'] ?? '',
                      'matchPercentage': matchPercentage,
                    },
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667eea).withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '$matchPercentage% Match',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    if (_userData == null) return const SizedBox.shrink();
    final rating = _userData!['rating'] ?? 4.5;
    final sessionsCompleted = _userData!['sessionsCompleted'] ?? 0;
    final responseTime = _userData!['responseTime'] ?? '< 1h';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem(
              Icons.star,
              rating.toStringAsFixed(1),
              'Rating',
              Colors.amber,
            ),
            _buildDivider(),
            _buildStatItem(
              Icons.check_circle,
              '$sessionsCompleted',
              'Sessions',
              Colors.green,
            ),
            _buildDivider(),
            _buildStatItem(
              Icons.schedule,
              responseTime,
              'Response',
              Colors.blue,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
    IconData icon,
    String value,
    String label,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
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
    );
  }

  Widget _buildDivider() {
    return Container(width: 1, height: 50, color: Colors.grey.shade300);
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
          Tab(text: 'About'),
          Tab(text: 'Skills'),
          Tab(text: 'Reviews'),
        ],
      ),
    );
  }

  Widget _buildAboutTab() {
    if (_userData == null) return const SizedBox.shrink();
    final bio = _userData!['bio'] ?? 'No bio available';
    final availability = _userData!['availability'] ?? 'Available';
    final responseTime = _userData!['responseTime'] ?? '< 1 hour';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Bio Section
          _buildSectionTitle(Icons.person_outline, 'Bio'),
          const SizedBox(height: 12),
          Text(
            bio,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade700,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 30),
          // Availability Section
          _buildSectionTitle(Icons.calendar_today_outlined, 'Availability'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: availability == 'Available'
                  ? Colors.green.withOpacity(0.1)
                  : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: availability == 'Available'
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  availability == 'Available'
                      ? Icons.check_circle
                      : Icons.schedule,
                  color: availability == 'Available'
                      ? Colors.green
                      : Colors.orange,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        availability,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: availability == 'Available'
                              ? Colors.green
                              : Colors.orange,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        availability == 'Available'
                            ? 'Ready to connect and start a session'
                            : 'Currently in a session, will be back soon',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Response Time
          _buildSectionTitle(Icons.access_time, 'Response Time'),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.speed, color: Colors.blue),
                const SizedBox(width: 12),
                Text(
                  'Usually responds in $responseTime',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Teaching Style (Optional)
          _buildSectionTitle(Icons.psychology_outlined, 'Teaching Approach'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTagChip('Patient', Icons.favorite_outline, Colors.pink),
              _buildTagChip(
                'Interactive',
                Icons.chat_bubble_outline,
                Colors.purple,
              ),
              _buildTagChip('Practical', Icons.build_outlined, Colors.orange),
              _buildTagChip('Flexible', Icons.schedule, Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsTab() {
    if (_userData == null) return const SizedBox.shrink();
    final teachSkills = List<String>.from(_userData!['teachSkills'] ?? []);
    final learnSkills = List<String>.from(_userData!['learnSkills'] ?? []);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Can Teach Section
          _buildSectionTitle(Icons.school, 'Can Teach'),
          const SizedBox(height: 15),
          if (teachSkills.isEmpty)
            Text(
              'No teaching skills added yet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: teachSkills.map((skill) {
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
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
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
          const SizedBox(height: 35),
          // Wants to Learn Section
          _buildSectionTitle(Icons.auto_stories, 'Wants to Learn'),
          const SizedBox(height: 15),
          if (learnSkills.isEmpty)
            Text(
              'No learning skills added yet',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            )
          else
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: learnSkills.map((skill) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF764ba2),
                      width: 2,
                    ),
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
          const SizedBox(height: 35),
          // Skill Exchange Opportunity
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withOpacity(0.1),
                  Colors.orange.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.amber),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.swap_horiz, color: Colors.amber, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Skill Exchange Opportunity',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'You can teach what they want to learn, and they can teach what you want to learn!',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade700,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    if (_userData == null) return const SizedBox.shrink();
    final rating = _userData!['rating'] ?? 4.5;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating Summary
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.amber.withOpacity(0.1),
                  Colors.orange.withOpacity(0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Column(
                  children: [
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                    Row(
                      children: List.generate(5, (index) {
                        return Icon(
                          index < rating.floor()
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                          size: 20,
                        );
                      }),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${_reviews.length} Reviews',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 30),
                Expanded(
                  child: Column(
                    children: [
                      _buildRatingBar(5, 0.8),
                      _buildRatingBar(4, 0.15),
                      _buildRatingBar(3, 0.03),
                      _buildRatingBar(2, 0.01),
                      _buildRatingBar(1, 0.01),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          // Reviews List
          _buildSectionTitle(Icons.rate_review, 'User Reviews'),
          const SizedBox(height: 15),
          if (_reviews.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      Icons.rate_review_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No reviews yet',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Be the first to review this user',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ..._reviews.map((review) => _buildReviewCard(review)),
        ],
      ),
    );
  }

  Widget _buildRatingBar(int stars, double percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            '$stars',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.star, size: 12, color: Colors.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Stack(
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: percentage,
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${(percentage * 100).toInt()}%',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Reviewer Header
          Row(
            children: [
              // Avatar
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    review['reviewerAvatar'] ?? 'U',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF667eea),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['reviewerName'] ?? 'Anonymous',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      review['date'] ?? '',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              // Rating
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.amber, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      '${review['rating']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Skill Tag
          if (review['skill'] != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                review['skill'],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF667eea),
                ),
              ),
            ),
          if (review['skill'] != null) const SizedBox(height: 12),
          // Comment
          Text(
            review['comment'] ?? '',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
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

  Widget _buildTagChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Message Button
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _sendMessage,
                icon: const Icon(Icons.chat_bubble_outline, size: 22),
                label: const Text(
                  'Message',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF667eea),
                  side: const BorderSide(color: Color(0xFF667eea), width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
            const SizedBox(width: 15),
            // Connect Button (Schedule Session)
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Open schedule session dialog
                  _showScheduleSessionDialog();
                },
                icon: const Icon(Icons.video_call, size: 22),
                label: const Text(
                  'Connect',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Add this method for schedule session
  void _showScheduleSessionDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            const Text(
              'Schedule a Session',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Book a learning session with ${_userData?['name'] ?? 'User'}',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 30),
            // Session type
            const Text(
              'Session Type',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildSessionTypeButton(
                    Icons.video_call,
                    'Video Call',
                    true,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSessionTypeButton(
                    Icons.chat,
                    'Chat Only',
                    false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 25),
            // Duration
            const Text(
              'Duration',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildDurationChip('30 min', false),
                const SizedBox(width: 10),
                _buildDurationChip('60 min', true),
                const SizedBox(width: 10),
                _buildDurationChip('90 min', false),
              ],
            ),
            const Spacer(),
            // Schedule button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: null, // Sessions feature removed
                icon: const Icon(Icons.calendar_today, size: 22),
                label: const Text(
                  'Choose Date & Time',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTypeButton(IconData icon, String label, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isVideoCall = isSelected;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          color: _isVideoCall == isSelected
              ? const Color(0xFF667eea).withOpacity(0.1)
              : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isVideoCall == isSelected
                ? const Color(0xFF667eea)
                : Colors.grey.shade300,
            width: _isVideoCall == isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: _isVideoCall == isSelected
                  ? const Color(0xFF667eea)
                  : Colors.grey,
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: _isVideoCall == isSelected
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: _isVideoCall == isSelected
                    ? const Color(0xFF667eea)
                    : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDurationChip(String duration, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedDuration = duration;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: _selectedDuration == duration
                ? const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  )
                : null,
            color: _selectedDuration == duration ? null : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedDuration == duration
                  ? Colors.transparent
                  : Colors.grey.shade300,
            ),
          ),
          child: Text(
            duration,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _selectedDuration == duration
                  ? Colors.white
                  : Colors.grey.shade700,
            ),
          ),
        ),
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
