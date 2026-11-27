import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'dart:math' as math;
import 'individual_chat_screen.dart';

class MatchDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> matchData;

  const MatchDetailsScreen({Key? key, required this.matchData})
    : super(key: key);

  @override
  State<MatchDetailsScreen> createState() => _MatchDetailsScreenState();
}

class _MatchDetailsScreenState extends State<MatchDetailsScreen>
    with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic>? _userData;
  List<String> _commonSkills = [];
  List<String> _userLearningSkills = [];
  List<String> _otherTeachingSkills = [];
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
    _loadMatchDetails();
  }

  @override
  void dispose() {
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadMatchDetails() async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) return;

      final userId =
          widget.matchData['id'] as String? ??
          widget.matchData['userId'] as String?;
      if (userId == null) return;

      // Load other user data
      final userDoc = await SupabaseDb.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          _userData = data;
          _otherTeachingSkills = List<String>.from(
            data['teachingSkills'] as List<dynamic>? ?? [],
          );
        }
      }

      // Load current user data
      final currentUserDoc = await SupabaseDb.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (currentUserDoc.exists) {
        final currentData = currentUserDoc.data();
        if (currentData != null) {
          _userLearningSkills = List<String>.from(
            currentData['learningSkills'] as List<dynamic>? ?? [],
          );

          // Calculate common skills
          _commonSkills = _userLearningSkills
              .where((skill) => _otherTeachingSkills.contains(skill))
              .toList();
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading match details: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  int _calculateMatchPercentage() {
    if (_userLearningSkills.isEmpty || _otherTeachingSkills.isEmpty) return 0;

    final commonCount = _commonSkills.length;
    return ((commonCount / _userLearningSkills.length) * 100).round();
  }

  @override
  Widget build(BuildContext context) {
    final matchPercentage =
        widget.matchData['matchPercentage'] ?? _calculateMatchPercentage();
    final userName =
        widget.matchData['name'] ?? _userData?['name'] ?? 'Unknown User';
    final userFaculty =
        widget.matchData['faculty'] ?? _userData?['faculty'] ?? '';

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
                            : ListView(
                                padding: const EdgeInsets.all(25),
                                children: [
                                  _buildMatchScore(matchPercentage),
                                  const SizedBox(height: 30),
                                  _buildSectionTitle(
                                    'Why You Matched',
                                    Icons.favorite,
                                  ),
                                  const SizedBox(height: 15),
                                  _buildMatchReasons(userFaculty),
                                  const SizedBox(height: 30),
                                  _buildSectionTitle(
                                    'Common Skills',
                                    Icons.star,
                                  ),
                                  const SizedBox(height: 15),
                                  _buildCommonSkills(_commonSkills),
                                  const SizedBox(height: 30),
                                  _buildSectionTitle(
                                    'Learning Goals Alignment',
                                    Icons.trending_up,
                                  ),
                                  const SizedBox(height: 15),
                                  _buildGoalsAlignment(),
                                  const SizedBox(height: 30),
                                  _buildActionButtons(
                                    userId:
                                        widget.matchData['id'] ??
                                        widget.matchData['userId'],
                                    userName: userName,
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Match Details',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'See why you matched',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchScore(int percentage) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(25),
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
          const Icon(Icons.favorite, color: Colors.white, size: 50),
          const SizedBox(height: 20),
          Text(
            '$percentage%',
            style: const TextStyle(
              fontSize: 60,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Match Score',
            style: TextStyle(fontSize: 18, color: Colors.white70),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              percentage >= 80
                  ? 'Excellent Match! 🎉'
                  : percentage >= 60
                  ? 'Good Match! 👍'
                  : 'Potential Match',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchReasons(String faculty) {
    final reasons = <Map<String, dynamic>>[];

    // Same faculty
    if (_userData != null) {
      final otherFaculty = _userData!['faculty'] ?? '';
      if (otherFaculty.isNotEmpty && otherFaculty == faculty) {
        reasons.add({
          'icon': Icons.school,
          'title': 'Same Faculty',
          'description': 'You both study $faculty',
        });
      }
    }

    // Complementary skills
    if (_commonSkills.isNotEmpty) {
      reasons.add({
        'icon': Icons.star,
        'title': 'Complementary Skills',
        'description':
            'You can teach each other ${_commonSkills.length} skill${_commonSkills.length > 1 ? 's' : ''}',
      });
    }

    // Learning goals alignment
    if (_userLearningSkills.isNotEmpty && _otherTeachingSkills.isNotEmpty) {
      reasons.add({
        'icon': Icons.trending_up,
        'title': 'Learning Goals Alignment',
        'description': 'Your learning goals match their teaching skills',
      });
    }

    if (reasons.isEmpty) {
      reasons.add({
        'icon': Icons.people,
        'title': 'Potential Connection',
        'description': 'You might have common interests',
      });
    }

    return Column(
      children: reasons.map((reason) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: const Color(0xFF667eea).withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: const Color(0xFF667eea).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  reason['icon'] as IconData,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reason['title'] as String,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      reason['description'] as String,
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
        );
      }).toList(),
    );
  }

  Widget _buildCommonSkills(List<String> skills) {
    if (skills.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No common skills found',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: skills.map((skill) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
              const Icon(Icons.check_circle, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                skill,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildGoalsAlignment() {
    if (_userLearningSkills.isEmpty || _otherTeachingSkills.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Text(
            'No learning goals alignment data',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ),
      );
    }

    final alignedSkills = _userLearningSkills
        .where((skill) => _otherTeachingSkills.contains(skill))
        .take(3)
        .toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 28),
              const SizedBox(width: 15),
              const Expanded(
                child: Text(
                  'You Want to Learn',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              const Icon(Icons.arrow_forward, color: Colors.grey),
              const SizedBox(width: 15),
              const Expanded(
                child: Text(
                  'They Can Teach',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ...alignedSkills.map(
            (skill) => _buildGoalItem(skill, 'Expert Level'),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalItem(String skill, String level) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                skill,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                level,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons({
    required String? userId,
    required String userName,
  }) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 55,
          child: ElevatedButton.icon(
            onPressed: null, // Sessions feature removed
            icon: const Icon(Icons.calendar_today, size: 22),
            label: const Text(
              'Schedule Session',
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
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 55,
          child: OutlinedButton.icon(
            onPressed: userId != null
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IndividualChatScreen(
                          userName: userName,
                          userAvatar: userName.isNotEmpty
                              ? userName[0].toUpperCase()
                              : 'U',
                          userId: userId,
                          isOnline: false,
                          faculty: widget.matchData['faculty'] ?? '',
                        ),
                      ),
                    );
                  }
                : null,
            icon: const Icon(Icons.message, size: 22),
            label: const Text(
              'Send Message',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF667eea),
              side: const BorderSide(color: Color(0xFF667eea), width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
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
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
