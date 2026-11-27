import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'dart:async';
import 'dart:math' as math;
import 'user_profile_screen.dart';
import 'utils/app_localizations.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({Key? key}) : super(key: key);

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  String _sortBy = 'recent'; // recent, name, rating

  // Favorites Data from Firestore
  List<Map<String, dynamic>> _favorites = [];
  bool _isLoading = true;
  StreamSubscription<DbQuerySnapshot>? _favoritesSubscription;

  @override
  void initState() {
    super.initState();

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
    _loadFavorites();
    _setupFavoritesListener();
  }

  @override
  void dispose() {
    _favoritesSubscription?.cancel();
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    super.dispose();
  }

  void _setupFavoritesListener() {
    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) return;

    _favoritesSubscription = SupabaseDb.instance
        .collection('favorites')
        .where('userId', isEqualTo: currentUser.uid)
        .snapshots()
        .listen((snapshot) {
          // Reload favorites when changes occur
          _loadFavorites();
        });
  }

  Future<void> _loadFavorites() async {
    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() => _isLoading = false);
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

      // Get favorites from Firestore
      final favoritesSnapshot = await SupabaseDb.instance
          .collection('favorites')
          .where('userId', isEqualTo: currentUser.uid)
          .get();

      final List<Map<String, dynamic>> favorites = [];

      for (var favDoc in favoritesSnapshot.docs) {
        try {
          final favData = favDoc.data() as Map<String, dynamic>?;
          if (favData == null) continue;

          final favoriteUserId = favData['favoriteUserId'] as String?;
          if (favoriteUserId == null || favoriteUserId.isEmpty) {
            print(
              '⚠️ Favorites: Skipping favorite with null/empty favoriteUserId',
            );
            continue;
          }

          // Get user data
          final userDoc = await SupabaseDb.instance
              .collection('users')
              .doc(favoriteUserId)
              .get();

          if (!userDoc.exists) {
            print('⚠️ Favorites: User not found: $favoriteUserId');
            continue;
          }

          final userData = userDoc.data();
          if (userData == null) continue;

          final otherTeachSkills = List<String>.from(
            userData['teachSkills'] as List<dynamic>? ?? [],
          );
          final otherLearnSkills = List<String>.from(
            userData['learnSkills'] as List<dynamic>? ?? [],
          );

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
                    Filter('learnerId', isEqualTo: favoriteUserId),
                    Filter('teacherId', isEqualTo: favoriteUserId),
                  ),
                )
                .get();
            sessionsCompleted = sessionsQuery.docs.length;

            double totalRating = 0;
            int ratingCount = 0;
            for (var sessionDoc in sessionsQuery.docs) {
              final sessionData = sessionDoc.data() as Map<String, dynamic>?;
              if (sessionData != null && sessionData['rating'] != null) {
                totalRating += (sessionData['rating'] as num).toDouble();
                ratingCount++;
              }
            }
            averageRating = ratingCount > 0 ? totalRating / ratingCount : 0.0;
          } catch (e) {
            print('Error loading user stats: $e');
          }

          final savedAt = parseDbDate(favData['createdAt']);

          favorites.add({
            'id': favoriteUserId,
            'name': userData['name'] as String? ?? 'Unknown',
            'avatar': ((userData['name'] as String?) ?? 'U')[0].toUpperCase(),
            'faculty': userData['faculty'] as String? ?? '',
            'skills': otherTeachSkills,
            'rating': averageRating > 0 ? averageRating : 4.5,
            'sessionsCompleted': sessionsCompleted,
            'availability': userData['availability'] as String? ?? 'Available',
            'matchPercentage': matchPercentage.clamp(0, 100),
            'savedAt': savedAt?.toDate() ?? DateTime.now(),
          });
        } catch (e) {
          print('Error processing favorite ${favDoc.id}: $e');
          continue;
        }
      }

      if (mounted) {
        setState(() {
          _favorites = favorites;
          _isLoading = false;
        });
        _sortFavorites();
      }
    } catch (e) {
      print('Error loading favorites: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _sortFavorites() {
    setState(() {
      switch (_sortBy) {
        case 'recent':
          _favorites.sort((a, b) {
            final aDate = a['savedAt'] as DateTime? ?? DateTime(0);
            final bDate = b['savedAt'] as DateTime? ?? DateTime(0);
            return bDate.compareTo(aDate);
          });
          break;
        case 'name':
          _favorites.sort((a, b) {
            final aName = a['name'] as String? ?? '';
            final bName = b['name'] as String? ?? '';
            return aName.compareTo(bName);
          });
          break;
        case 'rating':
          _favorites.sort((a, b) {
            final aRating = (a['rating'] as num?)?.toDouble() ?? 0.0;
            final bRating = (b['rating'] as num?)?.toDouble() ?? 0.0;
            return bRating.compareTo(aRating);
          });
          break;
      }
    });
  }

  Future<void> _removeFromFavorites(String userId) async {
    final currentUser = SupabaseService.currentUser;
    if (currentUser == null) return;

    // Save the widget's context before showing dialog
    final scaffoldContext = context;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Remove from Favorites',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to remove this user from your favorites?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);

              try {
                // Find and delete favorite document
                final favoritesQuery = await SupabaseDb.instance
                    .collection('favorites')
                    .where('userId', isEqualTo: currentUser.uid)
                    .where('favoriteUserId', isEqualTo: userId)
                    .get();

                for (var doc in favoritesQuery.docs) {
                  await doc.reference.delete();
                }

                if (mounted) {
                  setState(() {
                    _favorites.removeWhere((fav) => fav['id'] == userId);
                  });

                  // Use the saved scaffold context
                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 10),
                          Text('Removed from favorites'),
                        ],
                      ),
                      backgroundColor: Colors.orange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: const EdgeInsets.all(10),
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                print('Error removing favorite: $e');
                if (mounted) {
                  // Use the saved scaffold context
                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      margin: const EdgeInsets.all(10),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showSortOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Sort By',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildSortOption('recent', 'Recently Added', Icons.access_time),
            _buildSortOption('name', 'Name (A-Z)', Icons.sort_by_alpha),
            _buildSortOption('rating', 'Highest Rating', Icons.star),
          ],
        ),
      ),
    );
  }

  Widget _buildSortOption(String value, String label, IconData icon) {
    final isSelected = _sortBy == value;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF667eea) : Colors.grey.shade600,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? const Color(0xFF667eea) : Colors.black87,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: Color(0xFF667eea))
          : null,
      onTap: () {
        setState(() => _sortBy = value);
        _sortFavorites();
        Navigator.pop(context);
      },
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
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : Column(
                                children: [
                                  // Stats & Sort
                                  _buildStatsBar(),
                                  // Favorites List
                                  Expanded(
                                    child: _favorites.isEmpty
                                        ? _buildEmptyState()
                                        : _buildFavoritesList(),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.favorites,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_favorites.length} saved users',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(15),
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.favorite, color: Colors.red, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    '${_favorites.length} Favorites',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF667eea),
                    ),
                  ),
                ],
              ),
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
              onPressed: _showSortOptions,
              icon: const Icon(Icons.sort, color: Colors.white),
              tooltip: 'Sort',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFavoritesList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _favorites.length,
      itemBuilder: (context, index) {
        final favorite = _favorites[index];
        return _buildFavoriteCard(favorite);
      },
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> favorite) {
    return Dismissible(
      key: Key(favorite['id']),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _removeFromFavorites(favorite['id']);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete, color: Colors.white, size: 32),
      ),
      child: Container(
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
                  topLeft: Radius.circular(18),
                  topRight: Radius.circular(18),
                ),
              ),
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
                        favorite['avatar'],
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
                                favorite['name'],
                                style: const TextStyle(
                                  fontSize: 18,
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
                                color: favorite['availability'] == 'Available'
                                    ? Colors.green.withOpacity(0.1)
                                    : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                favorite['availability'],
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: favorite['availability'] == 'Available'
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
                              favorite['faculty'],
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
                  // Remove button
                  IconButton(
                    onPressed: () => _removeFromFavorites(favorite['id']),
                    icon: const Icon(Icons.favorite, color: Colors.red),
                    tooltip: 'Remove from favorites',
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
                  // Stats
                  Row(
                    children: [
                      _buildStatChip(
                        Icons.favorite,
                        '${favorite['matchPercentage']}%',
                        Colors.red,
                      ),
                      const SizedBox(width: 10),
                      _buildStatChip(
                        Icons.star,
                        '${favorite['rating'].toStringAsFixed(1)}',
                        Colors.amber,
                      ),
                      const SizedBox(width: 10),
                      _buildStatChip(
                        Icons.check_circle,
                        '${favorite['sessionsCompleted']}',
                        Colors.green,
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  // Skills
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ((favorite['skills'] as List<dynamic>?) ?? [])
                        .take(3)
                        .map((skill) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF667eea).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              skill.toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF667eea),
                              ),
                            ),
                          );
                        })
                        .toList(),
                  ),
                  const SizedBox(height: 15),
                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    UserProfileScreen(userId: favorite['id']),
                              ),
                            );
                          },
                          icon: const Icon(Icons.person, size: 18),
                          label: const Text('View Profile'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF667eea),
                            side: const BorderSide(color: Color(0xFF667eea)),
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
                          onPressed: () {
                            // Navigate to schedule session
                            Navigator.pop(context);
                          },
                          icon: const Icon(Icons.calendar_today, size: 18),
                          label: const Text('Schedule'),
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
                ],
              ),
            ),
          ],
        ),
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
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
                Icons.favorite_border,
                size: 60,
                color: Colors.grey.shade400,
              ),
            ),
            const SizedBox(height: 30),
            Text(
              context.l10n.noFavoritesYet,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 15),
            Text(
              context.l10n.startAddingFavorites,
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: const Icon(Icons.search),
              label: Text(context.l10n.browseUsers),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                padding: const EdgeInsets.symmetric(
                  horizontal: 30,
                  vertical: 15,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
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
