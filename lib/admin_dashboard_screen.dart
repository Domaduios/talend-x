import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
import 'home_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  // Admin Info
  String _adminName = 'Admin';
  String _adminRole = 'Super Admin';
  bool _isLoading = true;
  bool _isAuthorized = false;

  // Dashboard Stats (loaded from Firestore)
  Map<String, dynamic> _stats = {
    'totalUsers': 0,
    'activeUsers': 0,
    'totalSessions': 0,
    'completedSessions': 0,
    'pendingReports': 0,
    'newUsersToday': 0,
    'sessionsToday': 0,
  };

  // All Users (loaded from Firestore)
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  final _searchController = TextEditingController();
  bool _isSearching = false;
  Timer? _searchDebounce;

  // Pending Reports (loaded from Firestore)
  List<Map<String, dynamic>> _pendingReports = [];

  // Stream subscriptions
  StreamSubscription<QuerySnapshot>? _usersSubscription;
  StreamSubscription<QuerySnapshot>? _reportsSubscription;

  @override
  void initState() {
    super.initState();

    // Initialize particle animations
    _particleControllers = List.generate(
      10,
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

    // Initialize tab controller
    _tabController = TabController(length: 4, vsync: this);

    // Check admin authorization
    _checkAdminAuthorization();
  }

  Future<void> _checkAdminAuthorization() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      // Not logged in, redirect to home
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        if (userData == null) {
          if (mounted) {
            setState(() => _isLoading = false);
          }
          return;
        }
        
        final isAdmin =
            userData['isAdmin'] == true ||
            userData['role'] == 'admin' ||
            userData['role'] == 'Admin';

        if (isAdmin) {
          setState(() {
            _adminName = userData['name'] ?? currentUser.displayName ?? 'Admin';
            _adminRole = userData['role'] ?? 'Super Admin';
            _isAuthorized = true;
            _isLoading = false;
          });
          _fadeController.forward();
          // Load real data from Firestore
          _loadDashboardData();
          _loadAllUsers(); // Load all users first
          _listenToUsers();
          _listenToReports();
        } else {
          // Not authorized, redirect to home
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Access denied. Admin privileges required.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
            );
          }
        }
      } else {
        // User document doesn't exist, redirect to home
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const HomeScreen()),
          );
        }
      }
    } catch (e) {
      print('Error checking admin authorization: $e');
      // On error, redirect to home
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error checking authorization. Access denied.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    }
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    _reportsSubscription?.cancel();
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    try {
      // Load stats
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final sessionsSnapshot = await FirebaseFirestore.instance
          .collection('sessions')
          .get();

      final reportsSnapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .get();

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);

      int totalUsers = usersSnapshot.docs.length;
      int activeUsers = 0;
      int newUsersToday = 0;
      int totalSessions = sessionsSnapshot.docs.length;
      int completedSessions = 0;
      int sessionsToday = 0;

      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        // Consider user active if they have completed profile
        if (data['profileCompleted'] == true) {
          activeUsers++;
        }
        // Check if user joined today
        final createdAt = data['createdAt'] as Timestamp?;
        if (createdAt != null) {
          final dateTime = createdAt.toDate();
          if (dateTime.isAfter(todayStart) &&
              dateTime.isBefore(DateTime.now())) {
            newUsersToday++;
          }
        }
      }

      for (var doc in sessionsSnapshot.docs) {
        final data = doc.data();
        if (data['status'] == 'completed') {
          completedSessions++;
        }
        // Check if session is today - check both 'date' and 'createdAt'
        final sessionDate = data['date'] as Timestamp?;
        final createdAt = data['createdAt'] as Timestamp?;
        final checkDate = sessionDate ?? createdAt;
        if (checkDate != null) {
          final dateTime = checkDate.toDate();
          if (dateTime.isAfter(todayStart) &&
              dateTime.isBefore(DateTime.now())) {
            sessionsToday++;
          }
        }
      }

      print('Dashboard Stats Loaded:');
      print('  Total Users: $totalUsers');
      print('  Active Users: $activeUsers');
      print('  Total Sessions: $totalSessions');
      print('  Pending Reports: ${reportsSnapshot.docs.length}');
      print('  New Users Today: $newUsersToday');
      print('  Sessions Today: $sessionsToday');

      if (mounted) {
        setState(() {
          _stats = {
            'totalUsers': totalUsers,
            'activeUsers': activeUsers,
            'totalSessions': totalSessions,
            'completedSessions': completedSessions,
            'pendingReports': reportsSnapshot.docs.length,
            'newUsersToday': newUsersToday,
            'sessionsToday': sessionsToday,
          };
        });
      }
    } catch (e) {
      print('Error loading dashboard data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _listenToUsers() {
    _usersSubscription?.cancel();
    // Load all users, not just recent 10
    _loadAllUsers();
    _usersSubscription = FirebaseFirestore.instance
        .collection('users')
        .orderBy('createdAt', descending: true)
        .limit(10)
        .snapshots()
        .listen(
          (snapshot) {
            if (mounted) {
              final List<Map<String, dynamic>> users = [];
              for (var doc in snapshot.docs) {
                final data = doc.data();
                final createdAt = data['createdAt'] as Timestamp?;
                users.add({
                  'id': doc.id,
                  'name': data['name'] ?? 'Unknown',
                  'email': data['email'] ?? '',
                  'avatar': (data['name'] ?? 'U')[0].toUpperCase(),
                  'faculty': data['faculty'] ?? '',
                  'joinDate': createdAt?.toDate() ?? DateTime.now(),
                  'status': data['suspended'] == true ? 'suspended' : 'active',
                  'verified': data['emailVerified'] == true,
                });
              }
              // Reload all users and dashboard stats when users change
              _loadAllUsers();
              _loadDashboardData();
            }
          },
          onError: (e) {
            print('Error listening to users: $e');
          },
        );
  }

  Future<void> _loadAllUsers() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final List<Map<String, dynamic>> users = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final createdAt = data['createdAt'] as Timestamp?;
        users.add({
          'id': doc.id,
          'name': data['name'] ?? 'Unknown',
          'email': data['email'] ?? '',
          'avatar': (data['name'] ?? 'U')[0].toUpperCase(),
          'faculty': data['faculty'] ?? '',
          'joinDate': createdAt?.toDate() ?? DateTime.now(),
          'status': data['suspended'] == true ? 'suspended' : 'active',
          'verified': data['emailVerified'] == true,
        });
      }

      if (mounted) {
        setState(() {
          _allUsers = users;
          _filteredUsers = List.from(users);
        });
        // Apply search filter if there's a search query
        if (_searchController.text.isNotEmpty) {
          _searchUsers(_searchController.text);
        }
      }
    } catch (e) {
      print('Error loading all users: $e');
    }
  }

  void _searchUsers(String query) {
    _searchDebounce?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _filteredUsers = List.from(_allUsers);
        _isSearching = false;
      });
      return;
    }

    // Filter locally first
    setState(() {
      _isSearching = true;
      _filteredUsers = _allUsers.where((user) {
        final name = (user['name'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final faculty = (user['faculty'] ?? '').toString().toLowerCase();
        final queryLower = query.toLowerCase();
        return name.contains(queryLower) ||
            email.contains(queryLower) ||
            faculty.contains(queryLower);
      }).toList();
      _isSearching = false;
    });

    // Also search in Firestore for more comprehensive results
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      _performFirestoreUserSearch(query);
    });
  }

  Future<void> _performFirestoreUserSearch(String query) async {
    if (query.trim().isEmpty || query.length < 2) {
      return;
    }

    try {
      final queryLower = query.toLowerCase();
      print('Admin: Searching Firestore for users: $queryLower');

      // Get all users from Firestore
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      final List<Map<String, dynamic>> searchResults = [];
      final Set<String> existingUserIds = _allUsers
          .map((u) => u['id'] as String)
          .toSet();

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final name = (data['name'] ?? '').toString().toLowerCase();
        final email = (data['email'] ?? '').toString().toLowerCase();
        final faculty = (data['faculty'] ?? '').toString().toLowerCase();

        if (name.contains(queryLower) ||
            email.contains(queryLower) ||
            faculty.contains(queryLower)) {
          // Check if already in _allUsers
          if (existingUserIds.contains(doc.id)) {
            continue;
          }

          final createdAt = data['createdAt'] as Timestamp?;
          searchResults.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'email': data['email'] ?? '',
            'avatar': (data['name'] ?? 'U')[0].toUpperCase(),
            'faculty': data['faculty'] ?? '',
            'joinDate': createdAt?.toDate() ?? DateTime.now(),
            'status': data['suspended'] == true ? 'suspended' : 'active',
            'verified': data['emailVerified'] == true,
          });
        }
      }

      // Combine results
      final combinedResults = <String, Map<String, dynamic>>{};
      for (var user in _filteredUsers) {
        combinedResults[user['id'] as String] = user;
      }
      for (var user in searchResults) {
        combinedResults[user['id'] as String] = user;
      }

      print('Admin: Combined search results: ${combinedResults.length} users');

      if (mounted) {
        setState(() {
          _filteredUsers = combinedResults.values.toList();
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Error searching users in Firestore: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _listenToReports() {
    _reportsSubscription?.cancel();
    _reportsSubscription = FirebaseFirestore.instance
        .collection('reports')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .listen(
          (snapshot) async {
            if (mounted) {
              final List<Map<String, dynamic>> reports = [];
              for (var doc in snapshot.docs) {
                final data = doc.data();
                final createdAt = data['createdAt'] as Timestamp?;

                // Get reporter and reported user names
                String reporterName =
                    data['reporterName'] ?? data['reporterId'] ?? 'Unknown';
                String reportedName =
                    data['reportedName'] ?? data['reportedId'] ?? 'Unknown';

                // If names are user IDs, fetch actual names
                if (reporterName.length > 20 || !reporterName.contains(' ')) {
                  // Likely a user ID, try to get name
                  try {
                    final userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(reporterName)
                        .get();
                    if (userDoc.exists) {
                      reporterName = userDoc.data()?['name'] ?? reporterName;
                    }
                  } catch (e) {
                    print('Error fetching reporter name: $e');
                  }
                }

                if (reportedName.length > 20 || !reportedName.contains(' ')) {
                  try {
                    final userDoc = await FirebaseFirestore.instance
                        .collection('users')
                        .doc(reportedName)
                        .get();
                    if (userDoc.exists) {
                      reportedName = userDoc.data()?['name'] ?? reportedName;
                    }
                  } catch (e) {
                    print('Error fetching reported name: $e');
                  }
                }

                reports.add({
                  'id': doc.id,
                  'reporterName': reporterName,
                  'reportedName': reportedName,
                  'reporterId': data['reporterId'] ?? reporterName,
                  'reportedId': data['reportedId'] ?? reportedName,
                  'reason': data['reason'] ?? 'No reason provided',
                  'description': data['description'] ?? '',
                  'date': createdAt?.toDate() ?? DateTime.now(),
                  'status': data['status'] ?? 'pending',
                  'severity': data['severity'] ?? 'medium',
                });
              }
              // Sort by date manually
              reports.sort(
                (a, b) =>
                    (b['date'] as DateTime).compareTo(a['date'] as DateTime),
              );
              if (mounted) {
                setState(() {
                  _pendingReports = reports;
                });
                // Reload dashboard stats when reports change
                _loadDashboardData();
              }
            }
          },
          onError: (e) {
            print('Error listening to reports: $e');
            // Fallback: load reports without real-time
            _loadReports();
          },
        );
  }

  Future<void> _loadReports() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('reports')
          .where('status', isEqualTo: 'pending')
          .get();

      if (mounted) {
        final List<Map<String, dynamic>> reports = [];
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final createdAt = data['createdAt'] as Timestamp?;

          String reporterName =
              data['reporterName'] ?? data['reporterId'] ?? 'Unknown';
          String reportedName =
              data['reportedName'] ?? data['reportedId'] ?? 'Unknown';

          // Fetch names if they are user IDs
          if (reporterName.length > 20 || !reporterName.contains(' ')) {
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(reporterName)
                  .get();
              if (userDoc.exists) {
                reporterName = userDoc.data()?['name'] ?? reporterName;
              }
            } catch (e) {
              print('Error fetching reporter name: $e');
            }
          }

          if (reportedName.length > 20 || !reportedName.contains(' ')) {
            try {
              final userDoc = await FirebaseFirestore.instance
                  .collection('users')
                  .doc(reportedName)
                  .get();
              if (userDoc.exists) {
                reportedName = userDoc.data()?['name'] ?? reportedName;
              }
            } catch (e) {
              print('Error fetching reported name: $e');
            }
          }

          reports.add({
            'id': doc.id,
            'reporterName': reporterName,
            'reportedName': reportedName,
            'reporterId': data['reporterId'] ?? reporterName,
            'reportedId': data['reportedId'] ?? reportedName,
            'reason': data['reason'] ?? 'No reason provided',
            'description': data['description'] ?? '',
            'date': createdAt?.toDate() ?? DateTime.now(),
            'status': data['status'] ?? 'pending',
            'severity': data['severity'] ?? 'medium',
          });
        }
        reports.sort(
          (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime),
        );
        setState(() {
          _pendingReports = reports;
        });
      }
    } catch (e) {
      print('Error loading reports: $e');
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'User Details',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Avatar
                    Center(
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            user['avatar'] as String,
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Name
                    Center(
                      child: Text(
                        user['name'] as String,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Email
                    Center(
                      child: Text(
                        user['email'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Info Cards
                    _buildInfoCard(
                      'Faculty',
                      user['faculty'] as String,
                      Icons.school,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      'Status',
                      (user['status'] as String).toUpperCase(),
                      Icons.circle,
                      valueColor: user['status'] == 'active'
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoCard(
                      'Verified',
                      (user['verified'] as bool) ? 'Yes' : 'No',
                      Icons.verified,
                      valueColor: (user['verified'] as bool)
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(height: 30),
                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              // Edit user
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: const [
                                      Icon(Icons.edit, color: Colors.white),
                                      SizedBox(width: 10),
                                      Text('Edit user feature coming soon'),
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
                            },
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667eea),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              _suspendUser(user);
                            },
                            icon: const Icon(Icons.block),
                            label: Text(
                              (user['status'] as String) == 'suspended'
                                  ? 'Activate'
                                  : 'Suspend',
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(
    String label,
    String value,
    IconData icon, {
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF667eea)),
          const SizedBox(width: 15),
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  void _suspendUser(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          (user['status'] as String) == 'suspended'
              ? 'Activate User'
              : 'Suspend User',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          (user['status'] as String) == 'suspended'
              ? 'Are you sure you want to activate ${user['name']}?'
              : 'Are you sure you want to suspend ${user['name']}? They will not be able to access the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        (user['status'] as String) == 'suspended'
                            ? 'User activated successfully'
                            : 'User suspended successfully',
                      ),
                    ],
                  ),
                  backgroundColor: (user['status'] as String) == 'suspended'
                      ? Colors.green
                      : Colors.orange,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(10),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: (user['status'] as String) == 'suspended'
                  ? Colors.green
                  : Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              (user['status'] as String) == 'suspended'
                  ? 'Activate'
                  : 'Suspend',
            ),
          ),
        ],
      ),
    );
  }

  void _handleReport(Map<String, dynamic> report, String action) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          action == 'approve' ? 'Approve Report' : 'Reject Report',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          action == 'approve'
              ? 'This will suspend ${report['reportedName']}. Continue?'
              : 'This will dismiss the report. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final reportId = report['id'] as String;

                if (action == 'approve') {
                  // Update report status
                  await FirebaseFirestore.instance
                      .collection('reports')
                      .doc(reportId)
                      .update({
                        'status': 'approved',
                        'resolvedAt': FieldValue.serverTimestamp(),
                      });

                  // Suspend reported user
                  final reportedId =
                      report['reportedId'] as String? ??
                      report['reportedName'] as String;
                  if (reportedId.length > 20 || !reportedId.contains(' ')) {
                    // Likely a user ID
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(reportedId)
                        .update({'suspended': true});
                  }
                } else {
                  // Reject report
                  await FirebaseFirestore.instance
                      .collection('reports')
                      .doc(reportId)
                      .update({
                        'status': 'rejected',
                        'resolvedAt': FieldValue.serverTimestamp(),
                      });
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 10),
                          Text(
                            action == 'approve'
                                ? 'Report approved, user suspended'
                                : 'Report dismissed',
                          ),
                        ],
                      ),
                      backgroundColor: action == 'approve'
                          ? Colors.green
                          : Colors.orange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: const EdgeInsets.all(10),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: action == 'approve'
                  ? Colors.green
                  : Colors.orange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(action == 'approve' ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while checking authorization
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
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    }

    // If not authorized, don't show anything (will be redirected)
    if (!_isAuthorized) {
      return const SizedBox.shrink();
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
                    // Stats Grid
                    _buildStatsGrid(),
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
                            // Tab Bar
                            _buildTabBar(),
                            // Tab Content
                            Expanded(
                              child: TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildUsersTab(),
                                  _buildReportsTab(),
                                  _buildSessionsTab(),
                                  _buildSettingsTab(),
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
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      child: Row(
        children: [
          // Admin Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10),
              ],
            ),
            child: Center(
              child: Text(
                _adminName[0],
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF667eea),
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
                  _adminName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _adminRole,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Notifications
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () {
                // Show notifications
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        const Icon(Icons.notifications, color: Colors.white),
                        const SizedBox(width: 10),
                        Text('${_pendingReports.length} pending reports'),
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
              },
              icon: Stack(
                children: [
                  const Icon(Icons.notifications, color: Colors.white),
                  if (_pendingReports.isNotEmpty)
                    Positioned(
                      right: 0,
                      top: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${_pendingReports.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
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

  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
        children: [
          _buildStatCard(
            'Total Users',
            '${_stats['totalUsers']}',
            Icons.people,
            Colors.blue,
            '+${_stats['newUsersToday']} today',
          ),
          _buildStatCard(
            'Active Users',
            '${_stats['activeUsers']}',
            Icons.person_outline,
            Colors.green,
            _stats['totalUsers'] > 0
                ? '${((_stats['activeUsers'] / _stats['totalUsers']) * 100).toStringAsFixed(1)}%'
                : '0%',
          ),
          _buildStatCard(
            'Total Sessions',
            '${_stats['totalSessions']}',
            Icons.video_library,
            Colors.orange,
            '+${_stats['sessionsToday']} today',
          ),
          _buildStatCard(
            'Pending Reports',
            '${_stats['pendingReports']}',
            Icons.report,
            Colors.red,
            'Need review',
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white, size: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
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
        isScrollable: true,
        indicator: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
          borderRadius: BorderRadius.circular(15),
        ),
        labelColor: Colors.white,
        unselectedLabelColor: Colors.grey.shade600,
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        tabAlignment: TabAlignment.start,
        tabs: [
          Tab(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.people, size: 16),
                  SizedBox(width: 4),
                  Text('Users'),
                ],
              ),
            ),
          ),
          Tab(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.report, size: 16),
                  const SizedBox(width: 4),
                  const Text('Reports'),
                  if (_pendingReports.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${_pendingReports.length}',
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Tab(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.video_library, size: 16),
                  SizedBox(width: 4),
                  Text('Sessions'),
                ],
              ),
            ),
          ),
          Tab(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.settings, size: 16),
                  SizedBox(width: 4),
                  Text('Settings'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    return Column(
      children: [
        // Search & Filter
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search users...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _searchUsers('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (value) {
                    _searchUsers(value);
                  },
                ),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () {
                    // Refresh users
                    _loadDashboardData();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Users refreshed'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        // Users List
        Expanded(
          child: _isSearching
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                )
              : _filteredUsers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 80,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _searchController.text.isNotEmpty
                            ? 'No users found'
                            : 'No users found',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _searchController.text.isNotEmpty
                            ? 'Try a different search term'
                            : 'Users will appear here once they register',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _filteredUsers.length,
                  itemBuilder: (context, index) {
                    return _buildUserCard(_filteredUsers[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return InkWell(
      onTap: () => _showUserDetails(user),
      borderRadius: BorderRadius.circular(15),
      child: Container(
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
            // Avatar
            Stack(
              children: [
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
                      user['avatar'] as String,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (user['verified'] as bool)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified,
                        color: Colors.blue,
                        size: 16,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 15),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          user['name'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (user['status'] as String) == 'active'
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          (user['status'] as String).toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: (user['status'] as String) == 'active'
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user['email'] as String,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.school, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 5),
                      Text(
                        user['faculty'] as String,
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
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildReportsTab() {
    if (_pendingReports.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const Text(
              'No Pending Reports',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'All reports have been reviewed',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: _pendingReports
          .map((report) => _buildReportCard(report))
          .toList(),
    );
  }

  Widget _buildReportCard(Map<String, dynamic> report) {
    Color severityColor;
    switch (report['severity'] as String) {
      case 'high':
        severityColor = Colors.red;
        break;
      case 'medium':
        severityColor = Colors.orange;
        break;
      case 'low':
        severityColor = Colors.yellow.shade700;
        break;
      default:
        severityColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: severityColor.withOpacity(0.3), width: 2),
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
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${(report['severity'] as String).toUpperCase()} PRIORITY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: severityColor,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                _formatTimeAgo(report['date'] as DateTime),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 15),
          // Reason
          Text(
            report['reason'] as String,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          // Description
          Text(
            report['description'] as String,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 15),
          // Parties
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.person, size: 18, color: Colors.blue),
                    const SizedBox(width: 8),
                    const Text(
                      'Reporter: ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      report['reporterName'] as String,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.flag, size: 18, color: Colors.red),
                    const SizedBox(width: 8),
                    const Text(
                      'Reported: ',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      report['reportedName'] as String,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          // Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _handleReport(report, 'reject'),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('Reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleReport(report, 'approve'),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Approve'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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

  Widget _buildSessionsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          const Text(
            'Sessions Management',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          Text(
            'View and manage all sessions',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 30),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to sessions management
              Navigator.pushNamed(context, '/sessions');
            },
            icon: const Icon(Icons.arrow_forward),
            label: const Text('View All Sessions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildSettingsSection('App Settings', [
          _buildSettingsTile(
            Icons.notifications_outlined,
            'Push Notifications',
            'Manage notification settings',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Push notifications settings coming soon'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          _buildSettingsTile(
            Icons.email_outlined,
            'Email Templates',
            'Customize email templates',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Email templates coming soon'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          _buildSettingsTile(
            Icons.security_outlined,
            'Security Settings',
            'Configure security options',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Security settings coming soon'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ]),
        const SizedBox(height: 20),
        _buildSettingsSection('System', [
          _buildSettingsTile(
            Icons.backup_outlined,
            'Backup & Restore',
            'Manage data backups',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Backup & restore coming soon'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          _buildSettingsTile(
            Icons.analytics_outlined,
            'Analytics',
            'View system analytics',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Analytics coming soon'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
          _buildSettingsTile(
            Icons.bug_report_outlined,
            'System Logs',
            'View error logs',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('System logs coming soon'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ]),
        const SizedBox(height: 20),
        _buildSettingsSection('Admin Management', [
          _buildSettingsTile(
            Icons.person_add_outlined,
            'Grant Admin Access',
            'Give admin privileges to a user',
            () {
              _showGrantAdminDialog();
            },
          ),
          _buildSettingsTile(
            Icons.person_remove_outlined,
            'Revoke Admin Access',
            'Remove admin privileges from a user',
            () {
              _showRevokeAdminDialog();
            },
          ),
          _buildSettingsTile(
            Icons.verified_user_outlined,
            'Permissions',
            'Configure role permissions',
            () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Permissions coming soon'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
          ),
        ]),
        const SizedBox(height: 30),
        // Logout Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              // Logout
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  title: const Text(
                    'Logout',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.white),
                                SizedBox(width: 10),
                                Text('Logged out successfully'),
                              ],
                            ),
                            backgroundColor: Colors.green,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.all(
                                Radius.circular(10),
                              ),
                            ),
                            margin: EdgeInsets.all(10),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF667eea),
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200),
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
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF667eea).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF667eea)),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }

  String _formatTimeAgo(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

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

  void _showGrantAdminDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_add, color: Color(0xFF667eea)),
            SizedBox(width: 10),
            Text('Grant Admin Access'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the email address of the user you want to grant admin access to:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'user@example.com',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              emailController.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter an email address'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              emailController.dispose();
              Navigator.pop(context);
              await _grantAdminAccess(email);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Grant Access'),
          ),
        ],
      ),
    );
  }

  void _showRevokeAdminDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.person_remove, color: Colors.red),
            SizedBox(width: 10),
            Text('Revoke Admin Access'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the email address of the user you want to revoke admin access from:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: 'Email Address',
                hintText: 'user@example.com',
                prefixIcon: const Icon(Icons.email),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              emailController.dispose();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter an email address'),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }

              emailController.dispose();
              Navigator.pop(context);
              await _revokeAdminAccess(email);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Revoke Access'),
          ),
        ],
      ),
    );
  }

  Future<void> _grantAdminAccess(String email) async {
    try {
      // Find user by email
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (usersQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 10),
                  Text('User with email $email not found'),
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
        return;
      }

      final userDoc = usersQuery.docs.first;
      final userId = userDoc.id;
      final userData = userDoc.data();

      // Check if already admin
      if (userData['isAdmin'] == true || userData['role'] == 'admin') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.info, color: Colors.white),
                  SizedBox(width: 10),
                  Text('User already has admin access'),
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
        return;
      }

      // Grant admin access
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isAdmin': true,
        'role': 'admin',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('Admin access granted successfully!'),
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
      print('Error granting admin access: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 10),
                Text('Error: ${e.toString()}'),
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
    }
  }

  Future<void> _revokeAdminAccess(String email) async {
    try {
      // Find user by email
      final usersQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (usersQuery.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 10),
                  Text('User with email $email not found'),
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
        return;
      }

      final userDoc = usersQuery.docs.first;
      final userId = userDoc.id;
      final userData = userDoc.data();

      // Check if not admin
      if (userData['isAdmin'] != true && userData['role'] != 'admin') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.info, color: Colors.white),
                  SizedBox(width: 10),
                  Text('User does not have admin access'),
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
        return;
      }

      // Revoke admin access
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'isAdmin': false,
        'role': 'user',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('Admin access revoked successfully!'),
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
      print('Error revoking admin access: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 10),
                Text('Error: ${e.toString()}'),
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
    }
  }
}
