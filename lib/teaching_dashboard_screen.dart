import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'dart:math' as math;
import 'user_profile_screen.dart';

class TeachingDashboardScreen extends StatefulWidget {
  const TeachingDashboardScreen({Key? key}) : super(key: key);

  @override
  State<TeachingDashboardScreen> createState() =>
      _TeachingDashboardScreenState();
}

class _TeachingDashboardScreenState extends State<TeachingDashboardScreen>
    with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  Map<String, dynamic> _stats = {
    'totalSessions': 0,
    'totalStudents': 0,
    'averageRating': 0.0,
    'totalHours': 0,
    'completionRate': 0.0,
    'thisMonthSessions': 0,
    'totalEarnings': 0.0,
  };

  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _upcomingSessions = [];
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
    _loadTeachingData();
  }

  @override
  void dispose() {
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadTeachingData() async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) return;

      // Load all sessions where current user is a teacher
      final sessionsSnapshot = await SupabaseDb.instance
          .collection('sessions')
          .where('participants', arrayContains: currentUser.uid)
          .get();

      final now = DateTime.now();
      final thisMonthStart = DateTime(now.year, now.month, 1);

      int totalSessions = 0;
      int completedSessions = 0;
      int thisMonthSessions = 0;
      double totalRating = 0.0;
      int ratingCount = 0;
      int totalHours = 0;
      final Set<String> studentIds = {};

      for (var doc in sessionsSnapshot.docs) {
        final data = doc.data();
        final status = data['status'] as String? ?? '';

        if (status == 'completed') {
          completedSessions++;
          totalHours += (data['duration'] as num? ?? 60).toInt() ~/ 60;

          if (data['rating'] != null) {
            totalRating += (data['rating'] as num).toDouble();
            ratingCount++;
          }
        }

        totalSessions++;

        final scheduledDate = parseDbDate(data['scheduledDate']);
        if (scheduledDate != null) {
          final date = scheduledDate.toDate();
          if (date.isAfter(thisMonthStart)) {
            thisMonthSessions++;
          }
        }

        // Collect student IDs
        final participants = List<String>.from(data['participants'] ?? []);
        for (var participantId in participants) {
          if (participantId != currentUser.uid) {
            studentIds.add(participantId);
          }
        }
      }

      // Load students data
      final List<Map<String, dynamic>> students = [];
      for (var studentId in studentIds.take(10)) {
        final userDoc = await SupabaseDb.instance
            .collection('users')
            .doc(studentId)
            .get();

        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null) {
            // Get student's sessions with current user
            final studentSessions = sessionsSnapshot.docs.where((doc) {
              final docData = doc.data() as Map<String, dynamic>?;
              if (docData == null) return false;
              final participants = List<String>.from(
                docData['participants'] as List<dynamic>? ?? [],
              );
              return participants.contains(studentId);
            }).toList();

            final completedStudentSessions = studentSessions.where((doc) {
              final docData = doc.data() as Map<String, dynamic>?;
              return docData?['status'] == 'completed';
            }).length;

            final progress = studentSessions.isNotEmpty
                ? completedStudentSessions / studentSessions.length
                : 0.0;

            // Get last session
            DateTime? lastSession;
            String? skillLearning;
            for (var doc in studentSessions) {
              final data = doc.data();
              final scheduledDate = parseDbDate(data['scheduledDate']);
              if (scheduledDate != null) {
                final date = scheduledDate.toDate();
                if (lastSession == null || date.isAfter(lastSession)) {
                  lastSession = date;
                  skillLearning = (data['skills'] as List? ?? []).isNotEmpty
                      ? (data['skills'] as List).first
                      : null;
                }
              }
            }

            // Get average rating
            double studentRating = 0.0;
            for (var doc in studentSessions) {
              final data = doc.data();
              if (data['rating'] != null) {
                studentRating += (data['rating'] as num).toDouble();
              }
            }
            studentRating = studentSessions.isNotEmpty
                ? studentRating / studentSessions.length
                : 0.0;

            students.add({
              'id': studentId,
              'name': userData['name'] as String? ?? 'Unknown',
              'avatar': ((userData['name'] as String?) ?? 'U')[0].toUpperCase(),
              'sessionsCompleted': completedStudentSessions,
              'skillLearning': skillLearning ?? 'General',
              'progress': progress,
              'lastSession':
                  lastSession ??
                  DateTime.now().subtract(const Duration(days: 30)),
              'rating': studentRating,
            });
          }
        }
      }

      // Load upcoming sessions
      final upcomingSessionsSnapshot = await SupabaseDb.instance
          .collection('sessions')
          .where('participants', arrayContains: currentUser.uid)
          .where('status', isEqualTo: 'scheduled')
          .orderBy('scheduledDate', descending: false)
          .limit(5)
          .get();

      final List<Map<String, dynamic>> upcomingSessions = [];
      for (var doc in upcomingSessionsSnapshot.docs) {
        final data = doc.data();
        final scheduledDate = parseDbDate(data['scheduledDate']);
        final participants = List<String>.from(data['participants'] ?? []);
        final studentId = participants.firstWhere(
          (id) => id != currentUser.uid,
          orElse: () => '',
        );

        if (studentId.isNotEmpty) {
          final userDoc = await SupabaseDb.instance
              .collection('users')
              .doc(studentId)
              .get();

          final userName = userDoc.data()?['name'] ?? 'Unknown';
          final userNameFirstChar = userName.isNotEmpty ? userName[0] : 'U';
          final skills = List<String>.from(data['skills'] ?? []);

          upcomingSessions.add({
            'id': doc.id,
            'studentName': userName,
            'studentAvatar': userNameFirstChar.toUpperCase(),
            'skill': skills.isNotEmpty ? skills.first : 'General',
            'date': scheduledDate?.toDate() ?? DateTime.now(),
            'duration': (data['duration'] as num? ?? 60).toInt(),
          });
        }
      }

      final averageRating = ratingCount > 0 ? totalRating / ratingCount : 0.0;
      final completionRate = totalSessions > 0
          ? (completedSessions / totalSessions * 100)
          : 0.0;

      if (mounted) {
        setState(() {
          _stats = {
            'totalSessions': totalSessions,
            'totalStudents': studentIds.length,
            'averageRating': averageRating,
            'totalHours': totalHours,
            'completionRate': completionRate,
            'thisMonthSessions': thisMonthSessions,
            'totalEarnings': 0.0, // TODO: Calculate earnings if applicable
          };
          _students = students;
          _upcomingSessions = upcomingSessions;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading teaching data: $e');
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
                            : SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildStatsGrid(),
                                    const SizedBox(height: 30),
                                    _buildSectionTitle(
                                      'Upcoming Sessions',
                                      Icons.calendar_today,
                                    ),
                                    const SizedBox(height: 15),
                                    if (_upcomingSessions.isEmpty)
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Text(
                                            'No upcoming sessions',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      ..._upcomingSessions.map(
                                        (session) =>
                                            _buildUpcomingSessionCard(session),
                                      ),
                                    const SizedBox(height: 30),
                                    _buildSectionTitle(
                                      'My Students',
                                      Icons.people,
                                    ),
                                    const SizedBox(height: 15),
                                    if (_students.isEmpty)
                                      Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(20),
                                          child: Text(
                                            'No students yet',
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ),
                                      )
                                    else
                                      ..._students.map(
                                        (student) => _buildStudentCard(student),
                                      ),
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
                  'Teaching Dashboard',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Manage your teaching activities',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard(
          'Total Sessions',
          '${_stats['totalSessions']}',
          Icons.video_library,
          Colors.blue,
        ),
        _buildStatCard(
          'Students',
          '${_stats['totalStudents']}',
          Icons.people,
          Colors.green,
        ),
        _buildStatCard(
          'Rating',
          (_stats['averageRating'] as double).toStringAsFixed(1),
          Icons.star,
          Colors.amber,
        ),
        _buildStatCard(
          'Hours',
          '${_stats['totalHours']}h',
          Icons.access_time,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 32),
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
            textAlign: TextAlign.center,
          ),
        ],
      ),
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

  Widget _buildUpcomingSessionCard(Map<String, dynamic> session) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
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
                session['studentAvatar'],
                style: const TextStyle(
                  fontSize: 20,
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
                  session['studentName'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  session['skill'],
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 12,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_formatDateTime(session['date'])} • ${session['duration']} min',
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
        ],
      ),
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> student) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(userId: student['id']),
          ),
        );
      },
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
                  student['avatar'],
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
                    student['name'],
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    student['skillLearning'],
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progress',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: LinearProgressIndicator(
                                value: student['progress'] as double,
                                backgroundColor: Colors.grey.shade200,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Color(0xFF667eea),
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            (student['rating'] as double).toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
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
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (date == today) {
      return 'Today ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (date == today.add(const Duration(days: 1))) {
      return 'Tomorrow ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
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
