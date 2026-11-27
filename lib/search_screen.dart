import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'dart:async';
import 'dart:math' as math;
import 'user_profile_screen.dart';
import 'utils/app_localizations.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final _searchController = TextEditingController();

  String _searchQuery = '';
  List<String> _selectedSkills = [];
  List<String> _selectedFaculties = [];

  // Users Data from Firestore
  final List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _filteredUsers = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  List<String> _recentSearches = [];
  final List<String> _popularSearches = [
    'Programming',
    'Web Development',
    'AI/ML',
    'Graphic Design',
    'Marketing',
  ];

  final List<String> _allSkills = [
    'Programming',
    'Web Development',
    'Mobile Apps',
    'AI/ML',
    'Data Science',
    'UI/UX Design',
    'Graphic Design',
    'Marketing',
  ];

  final List<String> _allFaculties = [
    'Computer Science',
    'Engineering',
    'Fine Arts',
    'Commerce',
    'Nursing',
    'Physical Therapy',
  ];

  @override
  void initState() {
    super.initState();
    _filteredUsers = List.from(_allUsers);
    _loadRecentSearches();

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

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) return;

    try {
      final userDoc = await SupabaseDb.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final userData = userDoc.data();
        final recent = List<String>.from(userData?['recentSearches'] ?? []);
        if (mounted) {
          setState(() {
            _recentSearches = recent;
          });
        }
      }
    } catch (e) {
      print('Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearch(String query) async {
    if (query.trim().isEmpty) return;

    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) return;

    try {
      final updatedSearches = List<String>.from(_recentSearches);
      if (!updatedSearches.contains(query)) {
        updatedSearches.insert(0, query);
        if (updatedSearches.length > 5) {
          updatedSearches.removeLast();
        }

        await SupabaseDb.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({'recentSearches': updatedSearches});

        if (mounted) {
          setState(() {
            _recentSearches = updatedSearches;
          });
        }
      }
    } catch (e) {
      print('Error saving recent search: $e');
    }
  }

  void _performSearch(String query) {
    print('🔎 _performSearch called with query: "$query"');
    _searchDebounce?.cancel();

    setState(() {
      _searchQuery = query;
      _isSearching = true;
    });

    // If query is empty, clear results immediately
    if (query.trim().isEmpty) {
      print('📝 Query is empty, clearing results');
      _searchDebounce = Timer(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _filteredUsers = [];
            _isSearching = false;
          });
        }
      });
      return;
    }

    // Debounce search
    print('⏳ Starting debounce timer for search...');
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      print('🚀 Executing search after debounce');
      _searchInFirestore(query);
    });
  }

  Future<void> _searchInFirestore(String query) async {
    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() {
          _filteredUsers = [];
          _isSearching = false;
        });
      }
      return;
    }

    try {
      // Get current user's skills for match calculation
      final currentUserDoc = await SupabaseDb.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      final currentUserData = currentUserDoc.data();
      final currentTeachSkills = List<String>.from(
        currentUserData?['teachSkills'] ?? [],
      );
      final currentLearnSkills = List<String>.from(
        currentUserData?['learnSkills'] ?? [],
      );

      // Get all users (not just completed profiles)
      final allUsersSnapshot = await SupabaseDb.instance
          .collection('users')
          .get();

      print('🔍 Search query: "$query"');
      print('📊 Total users in Firestore: ${allUsersSnapshot.docs.length}');
      print('🔧 Selected skills: $_selectedSkills');
      print('🔧 Selected faculties: $_selectedFaculties');

      final List<Map<String, dynamic>> users = [];
      final queryLower = query.trim().toLowerCase();

      for (var doc in allUsersSnapshot.docs) {
        if (doc.id == currentUser.uid) {
          print('⏭️ Skipping current user: ${doc.id}');
          continue;
        }

        final userData = doc.data();

        // Skip suspended users
        if (userData['suspended'] == true) {
          print('⏭️ Skipping suspended user: ${userData['name']}');
          continue;
        }

        final name = (userData['name'] ?? '').toString().trim();
        final nameLower = name.toLowerCase().trim();
        final faculty = (userData['faculty'] ?? '').toString().trim();
        final facultyLower = faculty.toLowerCase().trim();
        final email = (userData['email'] ?? '').toString().trim();
        final emailLower = email.toLowerCase().trim();
        final otherTeachSkills = List<String>.from(
          userData['teachSkills'] ?? [],
        );
        final otherLearnSkills = List<String>.from(
          userData['learnSkills'] ?? [],
        );

        // Text search filter - search in name, email, faculty, and skills
        bool matchesText = false;
        if (queryLower.isEmpty) {
          matchesText = true; // If no query, show all users
        } else {
          final nameMatch = nameLower.contains(queryLower);
          final emailMatch = emailLower.contains(queryLower);
          final facultyMatch = facultyLower.contains(queryLower);
          final skillsMatch =
              otherTeachSkills.any(
                (skill) => skill.toLowerCase().contains(queryLower),
              ) ||
              otherLearnSkills.any(
                (skill) => skill.toLowerCase().contains(queryLower),
              );

          matchesText = nameMatch || emailMatch || facultyMatch || skillsMatch;

          print('🔍 Search: Checking user "$name"');
          print('   Query: "$queryLower"');
          print('   Name: "$nameLower" -> Name match: $nameMatch');
          print('   Email: "$emailLower" -> Email match: $emailMatch');
          print('   Faculty: "$facultyLower" -> Faculty match: $facultyMatch');
          print('   Skills match: $skillsMatch');
          print('   Final text match: $matchesText');
        }

        // Skills filter
        bool matchesSkills = true;
        if (_selectedSkills.isNotEmpty) {
          matchesSkills = _selectedSkills.any(
            (skill) => otherTeachSkills.contains(skill),
          );
        }

        // Faculty filter
        bool matchesFaculty = true;
        if (_selectedFaculties.isNotEmpty) {
          matchesFaculty = _selectedFaculties.contains(userData['faculty']);
        }

        print(
          '👤 Search: User: $name | Text: $matchesText | Skills: $matchesSkills | Faculty: $matchesFaculty',
        );

        if (matchesText && matchesSkills && matchesFaculty) {
          // Calculate match percentage
          int matchCount = 0;
          for (var skill in currentLearnSkills) {
            if (otherTeachSkills.contains(skill)) matchCount++;
          }
          for (var skill in currentTeachSkills) {
            if (otherLearnSkills.contains(skill)) matchCount++;
          }

          final totalSkills =
              (currentLearnSkills.length + currentTeachSkills.length);
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
                .where(
                  Filter.or(
                    Filter('learnerId', isEqualTo: doc.id),
                    Filter('teacherId', isEqualTo: doc.id),
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

          users.add({
            'id': doc.id,
            'name': userData['name'] ?? 'Unknown',
            'avatar': (userData['name'] ?? 'U')[0].toUpperCase(),
            'faculty': userData['faculty'] ?? '',
            'skills': otherTeachSkills,
            'rating': averageRating > 0 ? averageRating : 4.5,
            'sessionsCompleted': sessionsCompleted,
            'availability': userData['availability'] ?? 'Available',
            'matchPercentage': matchPercentage.clamp(0, 100),
          });
        }
      }

      // Save to recent searches if query is not empty
      if (query.trim().isNotEmpty) {
        _saveRecentSearch(query);
      }

      print('✅ Found ${users.length} matching users');

      if (mounted) {
        setState(() {
          _filteredUsers = users;
          _isSearching = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ Error searching: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _filteredUsers = [];
          _isSearching = false;
        });
      }
    }
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FiltersSheet(
        selectedSkills: _selectedSkills,
        selectedFaculties: _selectedFaculties,
        allSkills: _allSkills,
        allFaculties: _allFaculties,
        onApply: (skills, faculties) {
          setState(() {
            _selectedSkills = skills;
            _selectedFaculties = faculties;
          });
          _performSearch(_searchQuery);
        },
      ),
    );
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedSkills.clear();
      _selectedFaculties.clear();
      _filteredUsers = [];
    });
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
                        child: Column(
                          children: [
                            // Search Bar
                            _buildSearchBar(),
                            // Filters Badge
                            if (_selectedSkills.isNotEmpty ||
                                _selectedFaculties.isNotEmpty)
                              _buildActiveFilters(),
                            // Content
                            Expanded(
                              child: _isSearching
                                  ? const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(20.0),
                                        child: CircularProgressIndicator(),
                                      ),
                                    )
                                  : _searchQuery.isEmpty &&
                                        _selectedSkills.isEmpty &&
                                        _selectedFaculties.isEmpty
                                  ? _buildInitialState()
                                  : _buildSearchResults(),
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
                  'Search',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Find the perfect learning partner',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
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
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _performSearch,
                decoration: InputDecoration(
                  hintText: context.l10n.searchByNameSkillFaculty,
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Color(0xFF667eea),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          onPressed: _clearSearch,
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
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              borderRadius: BorderRadius.circular(15),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Stack(
              children: [
                IconButton(
                  onPressed: _showFilters,
                  icon: const Icon(Icons.tune, color: Colors.white),
                  tooltip: 'Filters',
                ),
                if (_selectedSkills.isNotEmpty || _selectedFaculties.isNotEmpty)
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

  Widget _buildActiveFilters() {
    final totalFilters = _selectedSkills.length + _selectedFaculties.length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF667eea).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_alt, color: Color(0xFF667eea), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$totalFilters filter${totalFilters > 1 ? 's' : ''} active',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF667eea),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedSkills.clear();
                _selectedFaculties.clear();
              });
              _performSearch(_searchQuery);
            },
            child: const Text(
              'Clear',
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

  Widget _buildInitialState() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Recent Searches
        if (_recentSearches.isNotEmpty) ...[
          _buildSectionTitle('Recent Searches', Icons.history),
          const SizedBox(height: 15),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _recentSearches.map((search) {
              return InkWell(
                onTap: () {
                  _searchController.text = search;
                  _performSearch(search);
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.history, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(
                        search,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 30),
        ],
        // Popular Searches
        _buildSectionTitle('Popular Searches', Icons.trending_up),
        const SizedBox(height: 15),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: _popularSearches.map((search) {
            return InkWell(
              onTap: () {
                _searchController.text = search;
                _performSearch(search);
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF667eea).withOpacity(0.1),
                      const Color(0xFF764ba2).withOpacity(0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF667eea).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.whatshot,
                      size: 16,
                      color: Color(0xFF667eea),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      search,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF667eea),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    if (_filteredUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            const Text(
              'No results found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Try adjusting your search or filters',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Results Count
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Text(
                'Found ${_filteredUsers.length} result${_filteredUsers.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
        // Results List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            itemCount: _filteredUsers.length,
            itemBuilder: (context, index) {
              final user = _filteredUsers[index];
              return _buildUserCard(user);
            },
          ),
        ),
      ],
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
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(userId: user['id']),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
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
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
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
                            user['name'],
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
                            color: user['availability'] == 'Available'
                                ? Colors.green.withOpacity(0.1)
                                : Colors.orange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            user['availability'],
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: user['availability'] == 'Available'
                                  ? Colors.green
                                  : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.school,
                          size: 14,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          user['faculty'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildStatChip(
                          Icons.star,
                          '${user['rating'].toStringAsFixed(1)}',
                          Colors.amber,
                        ),
                        const SizedBox(width: 8),
                        _buildStatChip(
                          Icons.favorite,
                          '${user['matchPercentage']}%',
                          Colors.red,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: (user['skills'] as List<String>).take(2).map((
                        skill,
                      ) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF667eea).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            skill,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF667eea),
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
        ),
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF667eea), size: 20),
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

// Filters Sheet
class _FiltersSheet extends StatefulWidget {
  final List<String> selectedSkills;
  final List<String> selectedFaculties;
  final List<String> allSkills;
  final List<String> allFaculties;
  final Function(List<String>, List<String>) onApply;

  const _FiltersSheet({
    Key? key,
    required this.selectedSkills,
    required this.selectedFaculties,
    required this.allSkills,
    required this.allFaculties,
    required this.onApply,
  }) : super(key: key);

  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  late List<String> _tempSkills;
  late List<String> _tempFaculties;

  @override
  void initState() {
    super.initState();
    _tempSkills = List.from(widget.selectedSkills);
    _tempFaculties = List.from(widget.selectedFaculties);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
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
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _tempSkills.clear();
                          _tempFaculties.clear();
                        });
                      },
                      child: const Text(
                        'Clear All',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Skills
                    const Text(
                      'Skills',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.allSkills.map((skill) {
                        final isSelected = _tempSkills.contains(skill);
                        return FilterChip(
                          label: Text(skill),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _tempSkills.add(skill);
                              } else {
                                _tempSkills.remove(skill);
                              }
                            });
                          },
                          selectedColor: const Color(
                            0xFF667eea,
                          ).withOpacity(0.2),
                          checkmarkColor: const Color(0xFF667eea),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? const Color(0xFF667eea)
                                : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF667eea)
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 30),
                    // Faculties
                    const Text(
                      'Faculty',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.allFaculties.map((faculty) {
                        final isSelected = _tempFaculties.contains(faculty);
                        return FilterChip(
                          label: Text(faculty),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _tempFaculties.add(faculty);
                              } else {
                                _tempFaculties.remove(faculty);
                              }
                            });
                          },
                          selectedColor: const Color(
                            0xFF764ba2,
                          ).withOpacity(0.2),
                          checkmarkColor: const Color(0xFF764ba2),
                          labelStyle: TextStyle(
                            color: isSelected
                                ? const Color(0xFF764ba2)
                                : Colors.black87,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          side: BorderSide(
                            color: isSelected
                                ? const Color(0xFF764ba2)
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              // Apply Button
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onApply(_tempSkills, _tempFaculties);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: Text(
                      'Apply Filters (${_tempSkills.length + _tempFaculties.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
