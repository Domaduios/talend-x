import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'dart:math' as math;

class LearningProgressScreen extends StatefulWidget {
  const LearningProgressScreen({Key? key}) : super(key: key);

  @override
  State<LearningProgressScreen> createState() => _LearningProgressScreenState();
}

class _LearningProgressScreenState extends State<LearningProgressScreen>
    with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<Map<String, dynamic>> _skillsInProgress = [];
  List<Map<String, dynamic>> _completedSkills = [];
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
    _loadLearningProgress();
  }

  @override
  void dispose() {
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadLearningProgress() async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) return;

      final userDoc = await SupabaseDb.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (!userDoc.exists) return;

      final userData = userDoc.data();
      if (userData == null) return;

      final learningSkills = List<String>.from(
        userData['learningSkills'] as List<dynamic>? ?? [],
      );

      final List<Map<String, dynamic>> skillsInProgress = [];
      final List<Map<String, dynamic>> completedSkills = [];

      for (var skill in learningSkills) {
        // Get sessions for this skill
        final sessionsSnapshot = await SupabaseDb.instance
            .collection('sessions')
            .where('participants', arrayContains: currentUser.uid)
            .where('skills', arrayContains: skill)
            .get();

        final completedSessions = sessionsSnapshot.docs
            .where((doc) => doc.data()['status'] == 'completed')
            .length;

        final totalSessions = sessionsSnapshot.docs.length;
        final progress = totalSessions > 0
            ? completedSessions / totalSessions
            : 0.0;

        // Calculate hours spent
        int hoursSpent = 0;
        String? teacherName;
        for (var doc in sessionsSnapshot.docs) {
          final data = doc.data();
          if (data['status'] == 'completed') {
            hoursSpent += (data['duration'] as num? ?? 60).toInt() ~/ 60;
            final participants = List<String>.from(data['participants'] ?? []);
            final teacherId = participants.firstWhere(
              (id) => id != currentUser.uid,
              orElse: () => '',
            );
            if (teacherId.isNotEmpty && teacherName == null) {
              final teacherDoc = await SupabaseDb.instance
                  .collection('users')
                  .doc(teacherId)
                  .get();
              teacherName = teacherDoc.data()?['name'] ?? 'Unknown';
            }
          }
        }

        // Determine level
        String currentLevel = 'Beginner';
        if (progress >= 0.8) {
          currentLevel = 'Advanced';
        } else if (progress >= 0.5) {
          currentLevel = 'Intermediate';
        }

        // Determine next milestone
        final remainingSessions =
            (totalSessions * 0.8).ceil() - completedSessions;
        final nextMilestone = remainingSessions > 0
            ? 'Complete $remainingSessions more sessions'
            : 'Skill completed!';

        // Assign color based on skill
        final colors = [
          Colors.blue,
          Colors.purple,
          Colors.cyan,
          Colors.orange,
          Colors.green,
        ];
        final color = colors[learningSkills.indexOf(skill) % colors.length];

        if (progress >= 0.8) {
          completedSkills.add({
            'id': skill,
            'skill': skill,
            'sessionsCompleted': completedSessions,
            'hoursSpent': hoursSpent,
            'completedAt': DateTime.now().subtract(
              Duration(days: 30 - (completedSessions * 2)),
            ),
            'certificate': true,
            'rating': 4.8,
          });
        } else {
          skillsInProgress.add({
            'id': skill,
            'skill': skill,
            'progress': progress,
            'sessionsCompleted': completedSessions,
            'totalSessions': (totalSessions * 0.8).ceil(),
            'hoursSpent': hoursSpent,
            'currentLevel': currentLevel,
            'nextMilestone': nextMilestone,
            'teacher': teacherName ?? 'No teacher yet',
            'color': color,
          });
        }
      }

      if (mounted) {
        setState(() {
          _skillsInProgress = skillsInProgress;
          _completedSkills = completedSkills;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading learning progress: $e');
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
                            : ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                  _buildOverallProgress(),
                                  const SizedBox(height: 30),
                                  _buildSectionTitle(
                                    'Skills In Progress',
                                    Icons.trending_up,
                                  ),
                                  const SizedBox(height: 15),
                                  if (_skillsInProgress.isEmpty)
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Text(
                                          'No skills in progress',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    ..._skillsInProgress.map(
                                      (skill) => _buildSkillProgressCard(skill),
                                    ),
                                  const SizedBox(height: 30),
                                  _buildSectionTitle(
                                    'Completed Skills',
                                    Icons.check_circle,
                                  ),
                                  const SizedBox(height: 15),
                                  if (_completedSkills.isEmpty)
                                    Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Text(
                                          'No completed skills yet',
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    ..._completedSkills.map(
                                      (skill) =>
                                          _buildCompletedSkillCard(skill),
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
                  'Learning Progress',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Track your learning journey',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallProgress() {
    final totalHours = _skillsInProgress.fold(
      0,
      (sum, skill) => sum + (skill['hoursSpent'] as int),
    );
    final totalSessions = _skillsInProgress.fold(
      0,
      (sum, skill) => sum + (skill['sessionsCompleted'] as int),
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF667eea).withOpacity(0.1),
            const Color(0xFF764ba2).withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildOverallStatItem(
                'Skills Learning',
                '${_skillsInProgress.length}',
                Icons.school,
              ),
              Container(width: 1, height: 50, color: Colors.grey.shade300),
              _buildOverallStatItem(
                'Hours Spent',
                '$totalHours h',
                Icons.access_time,
              ),
              Container(width: 1, height: 50, color: Colors.grey.shade300),
              _buildOverallStatItem(
                'Sessions',
                '$totalSessions',
                Icons.video_library,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF667eea), size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF667eea),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
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
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildSkillProgressCard(Map<String, dynamic> skill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: skill['color'].withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: skill['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.school, color: skill['color'], size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skill['skill'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      skill['currentLevel'],
                      style: TextStyle(
                        fontSize: 13,
                        color: skill['color'],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: skill['color'].withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${((skill['progress'] as double) * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: skill['color'],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        Text(
                          '${skill['sessionsCompleted']}/${skill['totalSessions']} sessions',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: skill['progress'] as double,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          skill['color'],
                        ),
                        minHeight: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildInfoChip(
                Icons.access_time,
                '${skill['hoursSpent']}h',
                skill['color'],
              ),
              const SizedBox(width: 10),
              _buildInfoChip(Icons.person, skill['teacher'], skill['color']),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: skill['color'].withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.flag, color: skill['color'], size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Next: ${skill['nextMilestone']}',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w600,
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

  Widget _buildCompletedSkillCard(Map<String, dynamic> skill) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
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
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  skill['skill'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.video_library,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${skill['sessionsCompleted']} sessions',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${skill['hoursSpent']}h',
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
          if (skill['certificate'])
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.workspace_premium,
                color: Colors.amber,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
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
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              overflow: TextOverflow.ellipsis,
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
