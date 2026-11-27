import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'dart:math' as math;
import 'home_screen.dart';
import 'utils/app_localizations.dart';

class ProfileSetupScreen extends StatefulWidget {
  final String? userName;
  final String? userEmail;
  final String? userFaculty;

  const ProfileSetupScreen({
    Key? key,
    this.userName,
    this.userEmail,
    this.userFaculty,
  }) : super(key: key);

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen>
    with TickerProviderStateMixin {
  int _currentStep = 0;
  final _bioController = TextEditingController();
  final _phoneController = TextEditingController();
  final List<String> _selectedTeachSkills = [];
  final List<String> _selectedLearnSkills = [];
  String? _selectedAvailability;
  String? _selectedPreference;
  bool _isLoading = false;
  List<AnimationController>? _particleControllers;
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  // Skills database based on faculties
  final Map<String, List<String>> _facultySkills = {
    'Computer Science': [
      'Programming',
      'Web Development',
      'Mobile Apps',
      'AI/ML',
      'Data Science',
      'Cybersecurity',
      'Game Development',
      'UI/UX Design',
      'Cloud Computing',
      'Database Management',
    ],
    'Nursing': [
      'First Aid',
      'Patient Care',
      'Medical Procedures',
      'Health Education',
      'Vital Signs',
      'Medication Administration',
      'Wound Care',
      'CPR',
      'Emergency Response',
      'Patient Assessment',
    ],
    'Physical Therapy': [
      'Exercise Techniques',
      'Massage Therapy',
      'Injury Prevention',
      'Rehabilitation',
      'Sports Therapy',
      'Posture Correction',
      'Pain Management',
      'Stretching',
      'Manual Therapy',
      'Movement Analysis',
    ],
    'Fine Arts': [
      'Drawing',
      'Painting',
      'Sculpture',
      'Photography',
      'Graphic Design',
      'Digital Art',
      'Animation',
      'Art History',
      'Illustration',
      'Video Editing',
    ],
    'Commerce': [
      'Accounting',
      'Marketing',
      'Finance',
      'Business Strategy',
      'Economics',
      'Management',
      'Entrepreneurship',
      'Sales',
      'Investment',
      'Business Analytics',
    ],
    'Engineering': [
      'CAD Design',
      'Electronics',
      'Mechanics',
      '3D Modeling',
      'Circuit Design',
      'Robotics',
      'AutoCAD',
      'Project Management',
      'Programming',
      'Prototyping',
    ],
  };

  // General skills for everyone
  final List<String> _generalSkills = [
    'Public Speaking',
    'Communication',
    'Leadership',
    'Time Management',
    'Writing',
    'Research',
    'Presentation',
    'Problem Solving',
    'Critical Thinking',
    'Teamwork',
    'Language Skills',
    'Social Media',
    'Content Creation',
    'Photography',
    'Video Editing',
  ];

  // Availability options
  final List<String> _availabilityOptions = [
    'Weekdays (Morning)',
    'Weekdays (Evening)',
    'Weekends',
    'Flexible',
    'Online Only',
  ];

  // Learning preferences
  final List<String> _learningPreferences = [
    'One-on-One Sessions',
    'Group Learning',
    'Online Sessions',
    'In-Person Meetups',
    'Hybrid (Online + In-Person)',
    'Flexible', // Add Flexible as an option
  ];

  @override
  void initState() {
    super.initState();
    // Initialize particle animations
    _particleControllers = List.generate(
      15,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: 5000 + math.Random(index).nextInt(3000),
        ),
      )..repeat(),
    );

    // Initialize slide animation
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeInOut),
        );
    _slideController.forward();
  }

  @override
  void dispose() {
    _bioController.dispose();
    _phoneController.dispose();
    _particleControllers?.forEach((controller) => controller.dispose());
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _nextStep() async {
    // Validation
    if (_currentStep == 0) {
      if (_bioController.text.trim().isEmpty) {
        _showErrorSnackBar('يرجى كتابة نبذة قصيرة عن نفسك');
        return;
      }
    } else if (_currentStep == 1) {
      if (_selectedTeachSkills.isEmpty) {
        _showErrorSnackBar('يرجى اختيار مهارة واحدة على الأقل يمكنك تعليمها');
        return;
      }
    } else if (_currentStep == 2) {
      if (_selectedLearnSkills.isEmpty) {
        _showErrorSnackBar('يرجى اختيار مهارة واحدة على الأقل تريد تعلمها');
        return;
      }
    } else if (_currentStep == 3) {
      print('=== Validating step 3 (Preferences) ===');
      print('_selectedAvailability: $_selectedAvailability');
      print('_selectedPreference: $_selectedPreference');

      if (_selectedAvailability == null) {
        print('ERROR: Availability not selected');
        _showErrorSnackBar('يرجى اختيار وقت التوفر');
        return;
      }

      // If preference is not selected, use a default value
      if (_selectedPreference == null || _selectedPreference!.isEmpty) {
        print('WARNING: Preference not selected, using default value');
        setState(() {
          _selectedPreference = 'Flexible'; // Default value
        });
        print('Set default preference to: $_selectedPreference');
      }

      // All validations passed, proceed to complete setup
      print('✅ All validations passed, proceeding to complete setup');
    }

    if (_currentStep < 3) {
      setState(() => _currentStep++);
      _slideController.reset();
      _slideController.forward();
    } else {
      _completeSetup();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _slideController.reset();
      _slideController.forward();
    }
  }

  Future<void> _completeSetup() async {
    setState(() => _isLoading = true);

    try {
      final user = SupabaseService.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorSnackBar('المستخدم غير مسجل دخول');
        }
        return;
      }

      print('Starting profile setup for user: ${user.id}');
      print('Availability: $_selectedAvailability');
      print('Preference: $_selectedPreference');

      // Prepare profile data - use defaults if not selected
      final profileData = {
        'name': widget.userName ?? user.userMetadata?['name'] as String? ?? 'User',
        'email': widget.userEmail ?? user.email ?? '',
        'faculty': widget.userFaculty ?? '',
        'bio': _bioController.text.trim(),
        'phone': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        'teachSkills': _selectedTeachSkills,
        'learnSkills': _selectedLearnSkills,
        'availability': _selectedAvailability ?? 'Flexible',
        'preference': _selectedPreference ?? 'Flexible',
        'profileCompleted': true,
        'updatedAt': DbFieldValue.serverTimestamp(),
      };

      print('Profile data prepared:');
      print('  availability: ${profileData['availability']}');
      print('  preference: ${profileData['preference']}');

      print('Updating Firestore with profile data...');

      // Update user document in Firestore
      await SupabaseDb.instance
          .collection('users')
          .doc(user.id)
          .update(profileData);

      print('Firestore update completed');

      // Verify the update was successful
      final updatedDoc = await SupabaseDb.instance
          .collection('users')
          .doc(user.id)
          .get();

      final isCompleted = updatedDoc.data()?['profileCompleted'] == true;
      print('Profile completed status: $isCompleted');

      if (mounted) {
        setState(() => _isLoading = false);

        if (isCompleted) {
          print('Navigating to HomeScreen...');
          _showSuccessSnackBar('تم إكمال إعداد الملف الشخصي بنجاح! 🎉');

          // Small delay to show success message, then navigate
          await Future.delayed(const Duration(milliseconds: 500));

          if (mounted) {
            // Navigate to Home Screen
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const HomeScreen()),
              (route) => false,
            );
            print('Navigation to HomeScreen completed');
          }
        } else {
          print('ERROR: Profile completed status is false');
          _showErrorSnackBar(
            'حدث خطأ في تحديث حالة الملف الشخصي. يرجى المحاولة مرة أخرى.',
          );
        }
      }
    } on PostgrestException catch (e) {
      print('Firebase error: ${e.code} - ${e.message}');
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMessage = 'حدث خطأ أثناء حفظ البيانات';
        if (e.code == 'permission-denied') {
          errorMessage = 'خطأ في الصلاحيات. يرجى التحقق من Firestore Rules.';
        }
        _showErrorSnackBar('$errorMessage: ${e.message}');
      }
    } catch (e, stackTrace) {
      print('Error in _completeSetup: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('حدث خطأ غير متوقع: ${e.toString()}');
      }
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
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
            ...List.generate(15, (index) => _buildParticle(index)),

            // Main content
            SafeArea(
              child: Column(
                children: [
                  // Header
                  _buildHeader(),

                  // Content
                  Expanded(
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Container(
                        margin: const EdgeInsets.all(20),
                        padding: const EdgeInsets.all(25),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: _buildStepContent(),
                      ),
                    ),
                  ),

                  // Bottom Button
                  _buildBottomButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              if (_currentStep > 0)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: _previousStep,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),
              const Spacer(),
              Column(
                children: [
                  Text(
                    context.l10n.setupProfile,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.createProfileForSkillExchange,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentStep + 1}/4',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress Indicator
          Row(
            children: List.generate(4, (index) {
              return Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 4,
                  decoration: BoxDecoration(
                    color: index <= _currentStep
                        ? Colors.white
                        : Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: index <= _currentStep
                        ? [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.5),
                              blurRadius: 4,
                            ),
                          ]
                        : [],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: double.infinity,
        height: 55,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.3),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Color(0xFF667eea),
                    strokeWidth: 2,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _currentStep == 3 ? 'إكمال الإعداد' : 'التالي',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF667eea),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _currentStep == 3 ? Icons.check : Icons.arrow_forward,
                      color: const Color(0xFF667eea),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildBioStep();
      case 1:
        return _buildTeachSkillsStep();
      case 2:
        return _buildLearnSkillsStep();
      case 3:
        return _buildPreferencesStep();
      default:
        return Container();
    }
  }

  Widget _buildBioStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667eea).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.person_outline,
                size: 50,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'أخبرنا عن نفسك',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF667eea),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'ساعد الآخرين على معرفة من أنت وما شغوف به',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          // Bio Field
          TextField(
            controller: _bioController,
            maxLines: 5,
            maxLength: 250,
            enableInteractiveSelection: true,
            enableSuggestions: true,
            autocorrect: true,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            inputFormatters: [],
            decoration: InputDecoration(
              labelText: context.l10n.bio,
              hintText:
                  'مرحباً! أنا ${widget.userName ?? "طالب"} من ${widget.userFaculty ?? "الجامعة"}. أنا شغوف بـ...',
              alignLabelWithHint: true,
              prefixIcon: const Padding(
                padding: EdgeInsets.only(bottom: 60),
                child: Icon(Icons.edit_note),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: Color(0xFF667eea),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 20),

          // Phone Field (Optional)
          TextField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            enableInteractiveSelection: true,
            enableSuggestions: false,
            autocorrect: false,
            inputFormatters: [],
            decoration: InputDecoration(
              labelText: '${context.l10n.phoneNumber} ${context.l10n.optional}',
              hintText: '+20 1XX XXX XXXX',
              prefixIcon: const Icon(Icons.phone_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  color: Color(0xFF667eea),
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoCard(
            icon: Icons.tips_and_updates,
            title: '💡 نصيحة',
            description:
                'النبذة الجيدة تساعدك على التواصل مع الأشخاص المناسبين. اذكر اهتماماتك وأهدافك وما يميزك!',
            color: Colors.amber,
          ),
        ],
      ),
    );
  }

  Widget _buildTeachSkillsStep() {
    List<String> allSkills = [];
    if (widget.userFaculty != null &&
        _facultySkills.containsKey(widget.userFaculty)) {
      allSkills.addAll(_facultySkills[widget.userFaculty]!);
    }
    allSkills.addAll(_generalSkills);
    allSkills = allSkills.toSet().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.school_outlined,
              size: 50,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'المهارات التي يمكنك تعليمها',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF667eea),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'اختر المهارات التي يمكنك مشاركتها مع الآخرين لمساعدتهم على التعلم',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'المحدد: ${_selectedTeachSkills.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (_selectedTeachSkills.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() => _selectedTeachSkills.clear());
                  },
                  child: const Text(
                    'مسح الكل',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allSkills.map((skill) {
                final isSelected = _selectedTeachSkills.contains(skill);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: FilterChip(
                    label: Text(skill),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedTeachSkills.add(skill);
                        } else {
                          _selectedTeachSkills.remove(skill);
                        }
                      });
                    },
                    selectedColor: const Color(0xFF667eea).withOpacity(0.2),
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
                    elevation: isSelected ? 4 : 0,
                    shadowColor: const Color(0xFF667eea).withOpacity(0.3),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          icon: Icons.lightbulb_outline,
          title: '✨ نصيحة',
          description: 'كلما اخترت مهارات أكثر، كلما زادت فرص التواصل!',
          color: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildLearnSkillsStep() {
    List<String> allSkills = [];
    // Include skills from all faculties for learning
    _facultySkills.forEach((faculty, skills) {
      allSkills.addAll(skills);
    });
    allSkills.addAll(_generalSkills);
    allSkills = allSkills.toSet().toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF764ba2), Color(0xFF667eea)],
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF764ba2).withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_stories_outlined,
              size: 50,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'المهارات التي تريد تعلمها',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF764ba2),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        Text(
          'اختر المهارات التي تهتم بتعلمها من الآخرين',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF764ba2), Color(0xFF667eea)],
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    'المحدد: ${_selectedLearnSkills.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (_selectedLearnSkills.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() => _selectedLearnSkills.clear());
                  },
                  child: const Text(
                    'مسح الكل',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 15),
        Expanded(
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allSkills.map((skill) {
                final isSelected = _selectedLearnSkills.contains(skill);
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  child: FilterChip(
                    label: Text(skill),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _selectedLearnSkills.add(skill);
                        } else {
                          _selectedLearnSkills.remove(skill);
                        }
                      });
                    },
                    selectedColor: const Color(0xFF764ba2).withOpacity(0.2),
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
                    elevation: isSelected ? 4 : 0,
                    shadowColor: const Color(0xFF764ba2).withOpacity(0.3),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        _buildInfoCard(
          icon: Icons.stars,
          title: '🎯 المطابقة',
          description:
              'سنقوم بربطك مع المستخدمين الذين يمكنهم تعليم هذه المهارات!',
          color: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildPreferencesStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF667eea).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: const Icon(
                Icons.settings_suggest_outlined,
                size: 50,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'تفضيلاتك',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF667eea),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'أخبرنا متى وكيف تفضل التعلم والتعليم',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          // Availability Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF667eea).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: Color(0xFF667eea),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'متى تكون متاحاً؟',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF667eea),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ..._availabilityOptions.map((option) {
            final isSelected = _selectedAvailability == option;
            return GestureDetector(
              onTap: () {
                print('Availability selected: $option');
                setState(() {
                  _selectedAvailability = option;
                  print(
                    '_selectedAvailability updated to: $_selectedAvailability',
                  );
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF667eea).withOpacity(0.1)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF667eea)
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF667eea).withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isSelected
                          ? const Color(0xFF667eea)
                          : Colors.grey.shade400,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      option,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected
                            ? const Color(0xFF667eea)
                            : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 30),

          // Learning Preference Section
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF764ba2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.psychology_outlined,
                  color: Color(0xFF764ba2),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'كيف تفضل التعلم؟',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF764ba2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ..._learningPreferences.map((preference) {
            final isSelected = _selectedPreference == preference;
            return GestureDetector(
              onTap: () {
                print('Preference tapped: $preference');
                print(
                  'Current _selectedPreference before update: $_selectedPreference',
                );
                setState(() {
                  _selectedPreference = preference;
                });
                print(
                  '_selectedPreference after setState: $_selectedPreference',
                );
                // Force a rebuild to ensure UI updates
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (mounted) {
                    setState(() {});
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF764ba2).withOpacity(0.1)
                      : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF764ba2)
                        : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF764ba2).withOpacity(0.2),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? const Color(0xFF764ba2)
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF764ba2)
                              : Colors.grey.shade400,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        preference,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? const Color(0xFF764ba2)
                              : Colors.black87,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(
                        Icons.check_circle,
                        color: Color(0xFF764ba2),
                        size: 20,
                      ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 20),
          _buildInfoCard(
            icon: Icons.info_outline,
            title: '🔒 الخصوصية',
            description:
                'تفضيلاتك تساعدنا على مطابقتك بشكل أفضل. يمكنك تغييرها في أي وقت من الإعدادات.',
            color: Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticle(int index) {
    if (_particleControllers == null) return const SizedBox.shrink();

    final random = math.Random(index);
    final size = random.nextDouble() * 30 + 10;
    final left = random.nextDouble() * MediaQuery.of(context).size.width;
    final top = random.nextDouble() * MediaQuery.of(context).size.height;

    return Positioned(
      left: left,
      top: top,
      child: AnimatedBuilder(
        animation: _particleControllers![index],
        builder: (context, child) {
          final value = _particleControllers![index].value;
          return Transform.translate(
            offset: Offset(
              math.sin(value * 2 * math.pi) * 30,
              -math.cos(value * 2 * math.pi) * 50,
            ),
            child: Opacity(
              opacity: (0.2 + (math.sin(value * 2 * math.pi) * 0.4)).clamp(
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
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
