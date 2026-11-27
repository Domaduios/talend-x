import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'dart:async';
import 'dart:math' as math;
import 'user_profile_screen.dart';
import 'filter_screen.dart';
import 'utils/app_localizations.dart';

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({Key? key}) : super(key: key);

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _showFilters = false;
  String _selectedFilter = 'All';
  String _selectedFaculty = 'All Faculties';
  String _selectedAvailability = 'All';
  List<String> _selectedSkills = [];

  // Users from Firestore
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  final List<String> _filterOptions = [
    'All',
    'Highest Match',
    'Top Rated',
    'Most Active',
    'Recently Joined',
  ];

  final List<String> _faculties = [
    'All Faculties',
    'Computer Science',
    'Engineering',
    'Fine Arts',
    'Commerce',
    'Nursing',
    'Physical Therapy',
  ];

  final List<String> _availabilityOptions = [
    'All',
    'Available',
    'Busy',
  ];

  final List<String> _popularSkills = [
    'Programming',
    'Web Development',
    'AI/ML',
    'UI/UX Design',
    'Mobile Apps',
    'Data Science',
    'Marketing',
    'Graphic Design',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUsers();
  }

  void _initializeAnimations() {
    _particleControllers = List.generate(
      10,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 5000 + math.Random(index).nextInt(3000)),
      )..repeat(),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();
  }

  Future<void> _loadUsers() async {
    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) return;

    try {
      // Get current user's skills for matching
      final currentUserDoc = await SupabaseDb.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!currentUserDoc.exists) return;

      final currentUserData = currentUserDoc.data();
      if (currentUserData == null) return;
      
      final currentTeachSkills = List<String>.from(currentUserData['teachSkills'] as List<dynamic>? ?? []);
      final currentLearnSkills = List<String>.from(currentUserData['learnSkills'] as List<dynamic>? ?? []);

      // Get ALL users (not just completed profiles)
      final allUsersSnapshot = await SupabaseDb.instance
          .collection('users')
          .get();
      
      print('📊 Browse: Loading ${allUsersSnapshot.docs.length} total users');

      List<Map<String, dynamic>> users = [];

      for (var doc in allUsersSnapshot.docs) {
        if (doc.id == currentUser.uid) {
          print('⏭️ Browse: Skipping current user in load: ${doc.id}');
          continue; // Skip current user
        }

        final userData = doc.data();
        
        // Skip suspended users
        if (userData['suspended'] == true) {
          print('⏭️ Browse: Skipping suspended user in load: ${userData['name']}');
          continue;
        }
        
        final otherTeachSkills = List<String>.from(userData['teachSkills'] ?? []);
        final otherLearnSkills = List<String>.from(userData['learnSkills'] ?? []);

        // Calculate match percentage
        int matchCount = 0;
        for (var skill in currentLearnSkills) {
          if (otherTeachSkills.contains(skill)) {
            matchCount++;
          }
        }
        for (var skill in currentTeachSkills) {
          if (otherLearnSkills.contains(skill)) {
            matchCount++;
          }
        }

        final totalSkills = (currentLearnSkills.length + currentTeachSkills.length);
        final matchPercentage = totalSkills > 0
            ? ((matchCount / totalSkills) * 100).round()
            : 0;

          // Get real stats from Firestore
          int sessionsCompleted = 0;
          double averageRating = 0.0;
          
          try {
            final sessionsQuery = await SupabaseDb.instance
                .collection('sessions')
                .where('status', isEqualTo: 'completed')
                .where(Filter.or(
                  Filter('learnerId', isEqualTo: doc.id),
                  Filter('teacherId', isEqualTo: doc.id),
                ))
                .get();
            sessionsCompleted = sessionsQuery.docs.length;
            
            // Calculate average rating from completed sessions
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

          users.add({
            'id': doc.id,
            'name': userData['name'] ?? 'Unknown',
            'email': userData['email'] ?? '', // Add email for search
            'faculty': userData['faculty'] ?? '',
            'teachSkills': otherTeachSkills,
            'learnSkills': otherLearnSkills,
            'matchPercentage': matchPercentage.clamp(0, 100),
            'rating': averageRating > 0 ? averageRating : 4.5, // Real rating or default
            'sessionsCompleted': sessionsCompleted,
            'availability': userData['availability'] ?? 'Available',
            'bio': userData['bio'] ?? 'No bio available',
            'responseTime': userData['responseTime'] ?? '< 1 hour',
          });
      }

      print('✅ Browse: Loaded ${users.length} users into _allUsers');

      if (mounted) {
        setState(() {
          _allUsers = users;
          _filteredUsers = List.from(users);
        });
      }
    } catch (e) {
      print('Error loading users: $e');
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final searchQuery = _searchController.text.trim();
    
    print('🔍 Browse: _applyFilters called with query: "$searchQuery"');
    print('📊 Browse: _allUsers contains ${_allUsers.length} users');
    
    // Print first few user names for debugging
    if (_allUsers.isNotEmpty) {
      print('👥 Browse: First 5 users in _allUsers:');
      for (var i = 0; i < _allUsers.length && i < 5; i++) {
        final user = _allUsers[i];
        print('   ${i + 1}. ${user['name']} (id: ${user['id']}, email: ${user['email']})');
      }
    }
    
    // If search is empty, show all loaded users
    if (searchQuery.isEmpty) {
      print('📝 Browse: Query is empty, showing all ${_allUsers.length} loaded users');
      setState(() {
        _filteredUsers = List.from(_allUsers);
        _isSearching = false;
      });
      return;
    }

    // Cancel previous search
    _searchDebounce?.cancel();

    // First, filter existing users locally (instant feedback)
    final searchLower = searchQuery.toLowerCase().trim();
    print('🔍 Browse: Filtering ${_allUsers.length} local users with query: "$searchLower"');
    
    setState(() {
      _isSearching = true;
      _filteredUsers = _allUsers.where((user) {
        final name = (user['name'] ?? '').toString().trim().toLowerCase();
        final email = (user['email'] ?? '').toString().trim().toLowerCase();
        final faculty = (user['faculty'] ?? '').toString().trim().toLowerCase();
        final teachSkills = (user['teachSkills'] as List?) ?? [];
        final learnSkills = (user['learnSkills'] as List?) ?? [];
        
        final nameMatch = name.contains(searchLower);
        final emailMatch = email.contains(searchLower);
        final facultyMatch = faculty.contains(searchLower);
        final skillsMatch = teachSkills.any((skill) => skill.toString().toLowerCase().contains(searchLower)) ||
            learnSkills.any((skill) => skill.toString().toLowerCase().contains(searchLower));
        
        final matches = nameMatch || emailMatch || facultyMatch || skillsMatch;
        
        if (matches) {
          print('✅ Browse: Local match found: ${user['name']} (name: $nameMatch, email: $emailMatch, faculty: $facultyMatch, skills: $skillsMatch)');
        }
        
        return matches;
      }).toList();
    });
    
    print('🔍 Browse: Filtered ${_filteredUsers.length} users locally from ${_allUsers.length} total');

    // Always search in Firestore to find users that might not be in _allUsers
    print('⏳ Browse: Starting Firestore search in 500ms...');
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      print('🚀 Browse: Executing Firestore search now');
      _performFirestoreSearch(searchQuery);
    });
  }

  Future<void> _performFirestoreSearch(String query) async {
    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() => _isSearching = false);
      }
      return;
    }

    try {
      final queryLower = query.trim().toLowerCase();
      print('🔍 Browse: Searching Firestore for: "$queryLower"');

      // Search in Firestore - get ALL users (not just completed profiles)
      final usersSnapshot = await SupabaseDb.instance
          .collection('users')
          .get();

      print('📊 Browse: Found ${usersSnapshot.docs.length} total users in Firestore');

      final List<Map<String, dynamic>> searchResults = [];
      final Set<String> existingUserIds = _allUsers.map((u) => u['id'] as String).toSet();

      for (var doc in usersSnapshot.docs) {
        if (doc.id == currentUser.uid) {
          print('⏭️ Browse: Skipping current user: ${doc.id}');
          continue; // Skip current user
        }

        final userData = doc.data();
        
        // Skip suspended users
        if (userData['suspended'] == true) {
          print('⏭️ Browse: Skipping suspended user: ${userData['name']}');
          continue;
        }
        
        final userName = (userData['name'] ?? '').toString().trim();
        final userNameLower = userName.toLowerCase().trim();
        final faculty = (userData['faculty'] ?? '').toString().trim();
        final facultyLower = faculty.toLowerCase().trim();
        final email = (userData['email'] ?? '').toString().trim();
        final emailLower = email.toLowerCase().trim();
        final teachSkills = List<String>.from(userData['teachSkills'] ?? []);
        final learnSkills = List<String>.from(userData['learnSkills'] ?? []);

        // Check if matches search query - search in name, email, faculty, and skills
        bool matches = false;
        if (queryLower.isEmpty) {
          matches = true; // If no query, show all users
        } else {
          final nameMatch = userNameLower.contains(queryLower);
          final emailMatch = emailLower.contains(queryLower);
          final facultyMatch = facultyLower.contains(queryLower);
          final skillsMatch = teachSkills.any((skill) => skill.toLowerCase().contains(queryLower)) ||
              learnSkills.any((skill) => skill.toLowerCase().contains(queryLower));
          
          matches = nameMatch || emailMatch || facultyMatch || skillsMatch;
          
          print('🔍 Browse: Checking user "$userName"');
          print('   Query: "$queryLower"');
          print('   Name: "$userNameLower" -> Name match: $nameMatch');
          print('   Email: "$emailLower" -> Email match: $emailMatch');
          print('   Faculty: "$facultyLower" -> Faculty match: $facultyMatch');
          print('   Skills match: $skillsMatch');
          print('   Final match: $matches');
        }
        
        print('👤 Browse: User: $userName | Matches: $matches');

        if (matches) {
          // Check if already in _allUsers - if yes, skip adding to searchResults
          // because it will be shown from local filtered results
          if (existingUserIds.contains(doc.id)) {
            print('ℹ️ Browse: User "$userName" already in _allUsers, skipping duplicate');
            continue; // Skip adding to searchResults, but it will be shown from _filteredUsers
          }

          print('✅ Browse: Adding new user from Firestore: "$userName"');

          // Calculate match percentage
          final currentUserDoc = await SupabaseDb.instance
              .collection('users')
              .doc(currentUser.uid)
              .get();
          
          int matchCount = 0;
          if (currentUserDoc.exists) {
            final currentUserData = currentUserDoc.data();
            if (currentUserData != null) {
              final currentTeachSkills = List<String>.from(currentUserData['teachSkills'] as List<dynamic>? ?? []);
              final currentLearnSkills = List<String>.from(currentUserData['learnSkills'] as List<dynamic>? ?? []);

              for (var skill in currentLearnSkills) {
                if (teachSkills.contains(skill)) matchCount++;
              }
              for (var skill in currentTeachSkills) {
                if (learnSkills.contains(skill)) matchCount++;
              }
            }
          }

          final totalSkills = (teachSkills.length + learnSkills.length);
          final matchPercentage = totalSkills > 0
              ? ((matchCount / totalSkills) * 100).round()
              : 0;

          // Get real stats
          int sessionsCompleted = 0;
          double averageRating = 0.0;
          
          try {
            final sessionsQuery = await SupabaseDb.instance
                .collection('sessions')
                .where('status', isEqualTo: 'completed')
                .where(Filter.or(
                  Filter('learnerId', isEqualTo: doc.id),
                  Filter('teacherId', isEqualTo: doc.id),
                ))
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

          searchResults.add({
            'id': doc.id,
            'name': userData['name'] ?? 'Unknown',
            'faculty': userData['faculty'] ?? '',
            'teachSkills': teachSkills,
            'learnSkills': learnSkills,
            'matchPercentage': matchPercentage.clamp(0, 100),
            'rating': averageRating > 0 ? averageRating : 4.5,
            'sessionsCompleted': sessionsCompleted,
            'availability': userData['availability'] ?? 'Available',
            'bio': userData['bio'] ?? 'No bio available',
            'responseTime': userData['responseTime'] ?? '< 1 hour',
          });
        }
      }

      // Combine local and Firestore results, remove duplicates
      final combinedResults = <String, Map<String, dynamic>>{};
      
      // Add existing filtered users
      for (var user in _filteredUsers) {
        combinedResults[user['id'] as String] = user;
      }
      
      // Add new search results
      for (var user in searchResults) {
        combinedResults[user['id'] as String] = user;
      }

      print('✅ Browse: Combined results: ${combinedResults.length} users');
      print('📝 Browse: Search results from Firestore: ${searchResults.length} users');

      if (mounted) {
        setState(() {
          _filteredUsers = combinedResults.values.toList();
          _isSearching = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ Browse: Error searching Firestore: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _applyOtherFilters() {
    setState(() {
      // Faculty filter
      if (_selectedFaculty != 'All Faculties') {
        _filteredUsers = _filteredUsers
            .where((user) => user['faculty'] == _selectedFaculty)
            .toList();
      }

      // Availability filter
      if (_selectedAvailability != 'All') {
        _filteredUsers = _filteredUsers
            .where((user) => user['availability'] == _selectedAvailability)
            .toList();
      }

      // Skills filter
      if (_selectedSkills.isNotEmpty) {
        _filteredUsers = _filteredUsers.where((user) {
          return _selectedSkills.any((skill) =>
              (user['teachSkills'] as List).contains(skill));
        }).toList();
      }

      // Sort filter
      switch (_selectedFilter) {
        case 'Highest Match':
          _filteredUsers.sort((a, b) =>
              b['matchPercentage'].compareTo(a['matchPercentage']));
          break;
        case 'Top Rated':
          _filteredUsers.sort((a, b) => b['rating'].compareTo(a['rating']));
          break;
        case 'Most Active':
          _filteredUsers.sort((a, b) =>
              b['sessionsCompleted'].compareTo(a['sessionsCompleted']));
          break;
      }
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedFilter = 'All';
      _selectedFaculty = 'All Faculties';
      _selectedAvailability = 'All';
      _selectedSkills.clear();
      _searchController.clear();
      _filteredUsers = List.from(_allUsers);
      _isSearching = false;
    });
    _searchDebounce?.cancel();
  }

  Future<void> _openAdvancedFilters() async {
    final Map<String, dynamic>? filters = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FilterScreen(
          initialFilters: {
            'faculty': _selectedFaculty,
            'availability': _selectedAvailability,
            'skills': _selectedSkills,
          },
        ),
      ),
    );

    if (filters != null && mounted) {
      setState(() {
        _selectedFaculty = filters['faculty'] ?? 'All Faculties';
        _selectedAvailability = filters['availability'] ?? 'All';
        _selectedSkills = List<String>.from(filters['skills'] ?? []);
      });
      _applyOtherFilters();
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
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
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
                    // Search Bar
                    _buildSearchBar(),
                    // Filter Chips
                    _buildFilterChips(),
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
                            // Results header
                            _buildResultsHeader(),
                            // Users Grid/List
                            Expanded(
                              child: _isSearching
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(20.0),
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  : _filteredUsers.isEmpty
                                      ? _buildEmptyState()
                                      : _buildUsersList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Filter Panel
            if (_showFilters) _buildFilterPanel(),
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
          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.browseUsers,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.findPerfectMatch,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          // Filter button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Stack(
              children: [
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.tune,
                    color: Colors.white,
                    size: 24,
                  ),
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'quick') {
                      setState(() => _showFilters = !_showFilters);
                    } else if (value == 'advanced') {
                      _openAdvancedFilters();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'quick',
                      child: Row(
                        children: [
                          const Icon(Icons.tune, color: Color(0xFF667eea)),
                          const SizedBox(width: 10),
                          Text(context.l10n.quickFilters),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'advanced',
                      child: Row(
                        children: [
                          const Icon(Icons.filter_alt, color: Color(0xFF667eea)),
                          const SizedBox(width: 10),
                          Text(context.l10n.advancedFilters),
                        ],
                      ),
                    ),
                  ],
                ),
                if (_selectedFaculty != 'All Faculties' ||
                    _selectedAvailability != 'All' ||
                    _selectedSkills.isNotEmpty)
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
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => _applyFilters(),
          decoration: InputDecoration(
            hintText: context.l10n.searchByNameSkillFaculty,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFF667eea),
              size: 24,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                      _applyFilters();
                    },
                    icon: const Icon(Icons.clear, color: Colors.grey),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filterOptions.length,
        itemBuilder: (context, index) {
          final filter = _filterOptions[index];
          final isSelected = _selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilter = filter;
                  _applyFilters();
                });
              },
              backgroundColor: Colors.white.withOpacity(0.2),
              selectedColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF667eea) : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              checkmarkColor: const Color(0xFF667eea),
              side: BorderSide(
                color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildResultsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              children: [
                const TextSpan(text: 'Found '),
                TextSpan(
                  text: '${_filteredUsers.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF667eea),
                    fontSize: 18,
                  ),
                ),
                const TextSpan(text: ' users'),
              ],
            ),
          ),
          if (_selectedFaculty != 'All Faculties' ||
              _selectedAvailability != 'All' ||
              _selectedSkills.isNotEmpty ||
              _searchController.text.isNotEmpty)
            TextButton.icon(
              onPressed: _clearFilters,
              icon: const Icon(Icons.clear_all, size: 18),
              label: Text(context.l10n.clearFilters),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF667eea),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _filteredUsers.length,
      itemBuilder: (context, index) {
        final user = _filteredUsers[index];
        return _buildUserCard(user);
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667eea).withOpacity(0.1),
                  const Color(0xFF764ba2).withOpacity(0.1),
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
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF667eea),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF667eea).withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      (user['name'] as String).isNotEmpty
                          ? (user['name'] as String)[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF667eea),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                // User Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Availability badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: user['availability'] == 'Available'
                                  ? Colors.green
                                  : Colors.orange,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              user['availability'] ?? 'Unknown',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
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
                          Expanded(
                            child: Text(
                              user['faculty'] ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Stats row
                      Row(
                        children: [
                          _buildStatBadge(
                            Icons.favorite,
                            '${user['matchPercentage']}%',
                            Colors.red,
                          ),
                          const SizedBox(width: 8),
                          _buildStatBadge(
                            Icons.star,
                            user['rating'].toStringAsFixed(1),
                            Colors.amber,
                          ),
                          const SizedBox(width: 8),
                          _buildStatBadge(
                            Icons.check_circle,
                            '${user['sessionsCompleted']}',
                            Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Body
          Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Bio
                Text(
                  user['bio'] ?? 'No bio available',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 15),
                // Can teach
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.school,
                        size: 14,
                        color: Color(0xFF667eea),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Can teach:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: (user['teachSkills'] as List<String>)
                      .take(3)
                      .map((skill) {
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xFF667eea).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        skill,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF667eea),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 15),
                // Action buttons
                Row(
                  children: [
                    // View Profile button
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          // Navigate to user profile
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfileScreen(
                                userData: user,
                              ),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: Color(0xFF667eea),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text(
                          'View Profile',
                          style: TextStyle(
                            color: Color(0xFF667eea),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Connect button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          // Navigate to user profile
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => UserProfileScreen(
                                userData: user,
                              ),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667eea),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.search_off,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No users found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Try adjusting your filters or search terms',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _clearFilters,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 30,
                vertical: 15,
              ),
            ),
            child: const Text(
              'Clear All Filters',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Positioned.fill(
      child: GestureDetector(
        onTap: () => setState(() => _showFilters = false),
        child: Container(
          color: Colors.black.withOpacity(0.5),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping panel
              child: Container(
                width: MediaQuery.of(context).size.width * 0.85,
                height: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    bottomLeft: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                        ),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(30),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Filters',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() => _showFilters = false);
                            },
                            icon: const Icon(
                              Icons.close,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Filters content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Faculty filter
                            _buildFilterSection(
                              'Faculty',
                              Icons.school,
                              DropdownButtonFormField<String>(
                                value: _selectedFaculty,
                                decoration: InputDecoration(
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 12,
                                  ),
                                ),
                                items: _faculties.map((faculty) {
                                  return DropdownMenuItem(
                                    value: faculty,
                                    child: Text(faculty),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedFaculty = value!;
                                  });
                                  _applyOtherFilters();
                                },
                              ),
                            ),
                            const SizedBox(height: 25),
                            // Availability filter
                            _buildFilterSection(
                              'Availability',
                              Icons.schedule,
                              Wrap(
                                spacing: 10,
                                children: _availabilityOptions.map((availability) {
                                  final isSelected =
                                      _selectedAvailability == availability;
                                  return FilterChip(
                                    label: Text(availability),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        _selectedAvailability = availability;
                                      });
                                      _applyOtherFilters();
                                    },
                                    selectedColor:
                                        const Color(0xFF667eea).withOpacity(0.2),
                                    checkmarkColor: const Color(0xFF667eea),
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF667eea)
                                          : Colors.black87,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 25),
                            // Skills filter
                            _buildFilterSection(
                              'Skills',
                              Icons.stars,
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _popularSkills.map((skill) {
                                  final isSelected =
                                      _selectedSkills.contains(skill);
                                  return FilterChip(
                                    label: Text(skill),
                                    selected: isSelected,
                                    onSelected: (selected) {
                                      setState(() {
                                        if (selected) {
                                          _selectedSkills.add(skill);
                                        } else {
                                          _selectedSkills.remove(skill);
                                        }
                                      });
                                      _applyOtherFilters();
                                    },
                                    selectedColor:
                                        const Color(0xFF764ba2).withOpacity(0.2),
                                    checkmarkColor: const Color(0xFF764ba2),
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? const Color(0xFF764ba2)
                                          : Colors.black87,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Apply button
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, -5),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _clearFilters,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFF667eea),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                              ),
                              child: const Text(
                                'Clear',
                                style: TextStyle(
                                  color: Color(0xFF667eea),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: () {
                                _applyOtherFilters();
                                setState(() => _showFilters = false);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF667eea),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 15),
                              ),
                              child: const Text(
                                'Apply Filters',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(String title, IconData icon, Widget content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: const Color(0xFF667eea),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        content,
      ],
    );
  }

  Widget _buildParticle(int index) {
    if (_particleControllers == null) return const SizedBox.shrink();

    final random = math.Random(index);
    final size = random.nextDouble() * 20 + 5;
    final left = random.nextDouble() * MediaQuery.of(context).size.width;
    final top = random.nextDouble() * 300;

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
              opacity:
                  (0.1 + (math.sin(value * 2 * math.pi) * 0.3)).clamp(0.0, 1.0),
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

