import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'user_profile_screen.dart';
import 'individual_chat_screen.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({Key? key}) : super(key: key);

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen>
    with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  List<Map<String, dynamic>> _connections = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _suggestions = [];
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
    _tabController = TabController(length: 3, vsync: this);

    _loadConnections();
    _loadPendingRequests();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadConnections() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final connectionsSnapshot = await FirebaseFirestore.instance
          .collection('connections')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      final List<Map<String, dynamic>> connections = [];

      for (var doc in connectionsSnapshot.docs) {
        final data = doc.data();
        final connectedUserId = data['connectedUserId'] as String?;

        if (connectedUserId != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(connectedUserId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data();
            if (userData == null) continue;

            final createdAt = data['createdAt'] as Timestamp?;

            // Get sessions count and rating
            final sessionsSnapshot = await FirebaseFirestore.instance
                .collection('sessions')
                .where('participants', arrayContains: connectedUserId)
                .where('status', isEqualTo: 'completed')
                .get();

            double totalRating = 0.0;
            int ratingCount = 0;
            for (var sessionDoc in sessionsSnapshot.docs) {
              final sessionData = sessionDoc.data();
              if (sessionData['rating'] != null) {
                totalRating += (sessionData['rating'] as num).toDouble();
                ratingCount++;
              }
            }
            final averageRating = ratingCount > 0
                ? totalRating / ratingCount
                : 0.0;

            connections.add({
              'id': connectedUserId,
              'name': userData['name'] ?? 'Unknown',
              'avatar': (userData['name'] ?? 'U')[0].toUpperCase(),
              'faculty': userData['faculty'] ?? '',
              'skills': List<String>.from(userData['teachingSkills'] ?? []),
              'rating': averageRating,
              'sessionsCompleted': sessionsSnapshot.docs.length,
              'connectedAt': createdAt?.toDate() ?? DateTime.now(),
              'lastActive': userData['lastActive']?.toDate() ?? DateTime.now(),
              'isOnline': false, // TODO: Implement online status
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _connections = connections;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading connections: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadPendingRequests() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('connections')
          .where('connectedUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .get();

      final List<Map<String, dynamic>> requests = [];

      for (var doc in requestsSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;

        if (userId != null) {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data();
            if (userData == null) continue;

            final requestedAt = data['createdAt'] as Timestamp?;

            // Calculate match percentage
            final currentUserDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();
            final currentUserData = currentUserDoc.data();
            final matchPercentage = _calculateMatchPercentage(
              currentUserData?['learningSkills'] ?? [],
              userData['teachingSkills'] ?? [],
            );

            // Get rating
            final sessionsSnapshot = await FirebaseFirestore.instance
                .collection('sessions')
                .where('participants', arrayContains: userId)
                .where('status', isEqualTo: 'completed')
                .get();

            double totalRating = 0.0;
            int ratingCount = 0;
            for (var sessionDoc in sessionsSnapshot.docs) {
              final sessionData = sessionDoc.data();
              if (sessionData['rating'] != null) {
                totalRating += (sessionData['rating'] as num).toDouble();
                ratingCount++;
              }
            }
            final averageRating = ratingCount > 0
                ? totalRating / ratingCount
                : 0.0;

            requests.add({
              'id': userId,
              'name': userData['name'] ?? 'Unknown',
              'avatar': (userData['name'] ?? 'U')[0].toUpperCase(),
              'faculty': userData['faculty'] ?? '',
              'skills': List<String>.from(userData['teachingSkills'] ?? []),
              'rating': averageRating,
              'matchPercentage': matchPercentage,
              'requestedAt': requestedAt?.toDate() ?? DateTime.now(),
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _pendingRequests = requests;
        });
      }
    } catch (e) {
      print('Error loading pending requests: $e');
    }
  }

  Future<void> _loadSuggestions() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data();
      if (userData == null) return;

      final learningSkills = List<String>.from(
        userData['learningSkills'] as List<dynamic>? ?? [],
      );

      if (learningSkills.isEmpty) {
        if (mounted) {
          setState(() {
            _suggestions = [];
          });
        }
        return;
      }

      // Get users who teach skills the current user wants to learn
      final suggestionsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('profileCompleted', isEqualTo: true)
          .where('teachingSkills', arrayContainsAny: learningSkills)
          .limit(10)
          .get();

      final List<Map<String, dynamic>> suggestions = [];
      final currentUserConnections = _connections
          .map((c) => c['id'] as String)
          .toList();

      for (var doc in suggestionsSnapshot.docs) {
        if (doc.id == currentUser.uid) continue;
        if (currentUserConnections.contains(doc.id)) continue;

        final data = doc.data();
        final matchPercentage = _calculateMatchPercentage(
          learningSkills,
          List<String>.from(data['teachingSkills'] ?? []),
        );

        // Count mutual connections
        final mutualConnections = await _countMutualConnections(doc.id);

        // Get rating
        final sessionsSnapshot = await FirebaseFirestore.instance
            .collection('sessions')
            .where('participants', arrayContains: doc.id)
            .where('status', isEqualTo: 'completed')
            .get();

        double totalRating = 0.0;
        int ratingCount = 0;
        for (var sessionDoc in sessionsSnapshot.docs) {
          final sessionData = sessionDoc.data();
          if (sessionData['rating'] != null) {
            totalRating += (sessionData['rating'] as num).toDouble();
            ratingCount++;
          }
        }
        final averageRating = ratingCount > 0 ? totalRating / ratingCount : 0.0;

        suggestions.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'avatar': (data['name'] ?? 'U')[0].toUpperCase(),
          'faculty': data['faculty'] ?? '',
          'skills': List<String>.from(data['teachingSkills'] ?? []),
          'rating': averageRating,
          'matchPercentage': matchPercentage,
          'mutualConnections': mutualConnections,
        });
      }

      // Sort by match percentage
      suggestions.sort(
        (a, b) => (b['matchPercentage'] as int).compareTo(
          a['matchPercentage'] as int,
        ),
      );

      if (mounted) {
        setState(() {
          _suggestions = suggestions.take(5).toList();
        });
      }
    } catch (e) {
      print('Error loading suggestions: $e');
    }
  }

  int _calculateMatchPercentage(
    List<String> userSkills,
    List<String> otherSkills,
  ) {
    if (userSkills.isEmpty || otherSkills.isEmpty) return 0;

    final commonSkills = userSkills
        .where((skill) => otherSkills.contains(skill))
        .length;
    return ((commonSkills / userSkills.length) * 100).round();
  }

  Future<int> _countMutualConnections(String userId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return 0;

      final currentUserConnections = await FirebaseFirestore.instance
          .collection('connections')
          .where('userId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'accepted')
          .get();

      final otherUserConnections = await FirebaseFirestore.instance
          .collection('connections')
          .where('userId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .get();

      final currentUserIds = currentUserConnections.docs
          .map((doc) => doc.data()['connectedUserId'] as String?)
          .where((id) => id != null)
          .toSet();

      int mutualCount = 0;
      for (var doc in otherUserConnections.docs) {
        final connectedUserId = doc.data()['connectedUserId'] as String?;
        if (connectedUserId != null &&
            currentUserIds.contains(connectedUserId)) {
          mutualCount++;
        }
      }

      return mutualCount;
    } catch (e) {
      return 0;
    }
  }

  Future<void> _acceptRequest(String userId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final requestDoc = await FirebaseFirestore.instance
          .collection('connections')
          .where('userId', isEqualTo: userId)
          .where('connectedUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (requestDoc.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('connections')
            .doc(requestDoc.docs.first.id)
            .update({
              'status': 'accepted',
              'acceptedAt': FieldValue.serverTimestamp(),
            });
      }

      await _loadConnections();
      await _loadPendingRequests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('Connection request accepted'),
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
    } catch (e) {
      print('Error accepting request: $e');
    }
  }

  Future<void> _rejectRequest(String userId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final requestDoc = await FirebaseFirestore.instance
          .collection('connections')
          .where('userId', isEqualTo: userId)
          .where('connectedUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (requestDoc.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('connections')
            .doc(requestDoc.docs.first.id)
            .delete();
      }

      await _loadPendingRequests();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.close, color: Colors.white),
                SizedBox(width: 10),
                Text('Connection request declined'),
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
      }
    } catch (e) {
      print('Error rejecting request: $e');
    }
  }

  Future<void> _removeConnection(String userId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final connectionDoc = await FirebaseFirestore.instance
          .collection('connections')
          .where('userId', isEqualTo: currentUser.uid)
          .where('connectedUserId', isEqualTo: userId)
          .where('status', isEqualTo: 'accepted')
          .limit(1)
          .get();

      if (connectionDoc.docs.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('connections')
            .doc(connectionDoc.docs.first.id)
            .delete();
      }

      await _loadConnections();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.delete, color: Colors.white),
                SizedBox(width: 10),
                Text('Connection removed'),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    } catch (e) {
      print('Error removing connection: $e');
    }
  }

  Future<void> _sendConnectionRequest(String userId) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Check if request already exists
      final existingRequest = await FirebaseFirestore.instance
          .collection('connections')
          .where('userId', isEqualTo: currentUser.uid)
          .where('connectedUserId', isEqualTo: userId)
          .limit(1)
          .get();

      if (existingRequest.docs.isNotEmpty) {
        // Request already exists
        return;
      }

      // Create connection request
      await FirebaseFirestore.instance.collection('connections').add({
        'userId': currentUser.uid,
        'connectedUserId': userId,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Get current user's name for notification
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();
      final currentUserName =
          currentUserDoc.data()?['name'] ??
          currentUser.displayName ??
          'Someone';

      // Create notification for the other user
      await FirebaseFirestore.instance.collection('notifications').add({
        'userId': userId,
        'type': 'connection',
        'title': 'New Connection Request',
        'message': '$currentUserName wants to connect with you',
        'fromUserId': currentUser.uid,
        'isRead': false,
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _loadSuggestions();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.send, color: Colors.white),
                SizedBox(width: 10),
                Text('Connection request sent'),
              ],
            ),
            backgroundColor: const Color(0xFF667eea),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    } catch (e) {
      print('Error sending connection request: $e');
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
                        child: Column(
                          children: [
                            _buildTabBar(),
                            Expanded(
                              child: _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(),
                                    )
                                  : TabBarView(
                                      controller: _tabController,
                                      children: [
                                        _buildConnectionsTab(),
                                        _buildRequestsTab(),
                                        _buildSuggestionsTab(),
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
                  'Connections',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_connections.length} connections',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
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
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
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
        tabs: [
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('All'),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${_connections.length}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Requests'),
                if (_pendingRequests.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${_pendingRequests.length}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Tab(text: 'Suggestions'),
        ],
      ),
    );
  }

  Widget _buildConnectionsTab() {
    if (_connections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const Text(
              'No Connections',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Start connecting with people',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _connections.length,
      itemBuilder: (context, index) =>
          _buildConnectionCard(_connections[index]),
    );
  }

  Widget _buildConnectionCard(Map<String, dynamic> connection) {
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
        children: [
          Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        connection['avatar'],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  if (connection['isOnline'])
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      connection['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.school,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          connection['faculty'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton(
                icon: const Icon(Icons.more_vert),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    child: Row(
                      children: const [
                        Icon(Icons.person, color: Color(0xFF667eea)),
                        SizedBox(width: 10),
                        Text('View Profile'),
                      ],
                    ),
                    onTap: () {
                      Future.delayed(const Duration(milliseconds: 100), () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                UserProfileScreen(userId: connection['id']),
                          ),
                        );
                      });
                    },
                  ),
                  PopupMenuItem(
                    child: Row(
                      children: const [
                        Icon(Icons.message, color: Color(0xFF667eea)),
                        SizedBox(width: 10),
                        Text('Send Message'),
                      ],
                    ),
                    onTap: () {
                      Future.delayed(const Duration(milliseconds: 100), () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => IndividualChatScreen(
                              userName: connection['name'],
                              userAvatar: connection['avatar'],
                              userId: connection['id'],
                              isOnline: connection['isOnline'],
                              faculty: connection['faculty'],
                            ),
                          ),
                        );
                      });
                    },
                  ),
                  PopupMenuItem(
                    child: Row(
                      children: const [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 10),
                        Text('Remove'),
                      ],
                    ),
                    onTap: () => _removeConnection(connection['id']),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatChip(
                Icons.star,
                (connection['rating'] as double).toStringAsFixed(1),
                Colors.amber,
              ),
              const SizedBox(width: 10),
              _buildStatChip(
                Icons.check_circle,
                '${connection['sessionsCompleted']}',
                Colors.green,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: (connection['skills'] as List<String>).take(2).map((
              skill,
            ) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  skill,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF667eea),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab() {
    if (_pendingRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const Text(
              'No Pending Requests',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Connection requests will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _pendingRequests.length,
      itemBuilder: (context, index) =>
          _buildRequestCard(_pendingRequests[index]),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: const Color(0xFF667eea).withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    request['avatar'],
                    style: const TextStyle(
                      fontSize: 24,
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
                      request['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.school,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          request['faculty'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatChip(
                Icons.favorite,
                '${request['matchPercentage']}%',
                Colors.red,
              ),
              const SizedBox(width: 10),
              _buildStatChip(
                Icons.star,
                (request['rating'] as double).toStringAsFixed(1),
                Colors.amber,
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _rejectRequest(request['id']),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Decline'),
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
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _acceptRequest(request['id']),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
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

  Widget _buildSuggestionsTab() {
    if (_suggestions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const Text(
              'No Suggestions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Complete your profile to get suggestions',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _suggestions.length,
      itemBuilder: (context, index) =>
          _buildSuggestionCard(_suggestions[index]),
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> suggestion) {
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
        children: [
          Row(
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    suggestion['avatar'],
                    style: const TextStyle(
                      fontSize: 24,
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
                      suggestion['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.school,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          suggestion['faculty'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatChip(
                Icons.favorite,
                '${suggestion['matchPercentage']}%',
                Colors.red,
              ),
              const SizedBox(width: 10),
              _buildStatChip(
                Icons.people,
                '${suggestion['mutualConnections']}',
                Colors.blue,
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _sendConnectionRequest(suggestion['id']),
              icon: const Icon(Icons.person_add, size: 18),
              label: const Text('Connect'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
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
