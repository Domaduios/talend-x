import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'utils/app_localizations.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Form Controllers
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();

  // Current User Data
  String? _selectedFaculty;
  String? _selectedAvailability;
  String? _selectedPreference;
  List<String> _selectedTeachSkills = [];
  List<String> _selectedLearnSkills = [];

  bool _isLoading = false;
  bool _hasChanges = false;
  bool _isInitialized = false;

  // Options
  final List<String> _faculties = [
    'Computer Science',
    'Engineering',
    'Fine Arts',
    'Commerce',
    'Nursing',
    'Physical Therapy',
  ];

  final List<String> _availabilityOptions = ['Available', 'Busy', 'Away'];

  final List<String> _learningPreferences = [
    'One-on-One Sessions',
    'Group Learning',
    'Online Sessions',
    'In-Person Meetups',
    'Hybrid (Online + In-Person)',
  ];

  final List<String> _allSkills = [
    'Programming',
    'Web Development',
    'Mobile Apps',
    'AI/ML',
    'Data Science',
    'UI/UX Design',
    'Graphic Design',
    'Photography',
    'Video Editing',
    'Marketing',
    'Business Strategy',
    'Public Speaking',
    'Writing',
    'Languages',
  ];

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _loadUserData();
  }

  void _initializeAnimations() {
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
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isInitialized = true);
      }
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (mounted) {
        if (userDoc.exists) {
          final userData = userDoc.data();
          if (userData != null) {
            setState(() {
              _nameController.text = userData['name'] as String? ?? user.displayName ?? '';
              _emailController.text = userData['email'] as String? ?? user.email ?? '';
              _phoneController.text = userData['phone'] as String? ?? '';
              _bioController.text = userData['bio'] as String? ?? '';
              _selectedFaculty = userData['faculty'] as String? ?? '';
              _selectedAvailability = userData['availability'] as String? ?? 'Available';
              _selectedPreference =
                  userData['preference'] as String? ?? 'Hybrid (Online + In-Person)';
              _selectedTeachSkills = List<String>.from(
                userData['teachSkills'] as List<dynamic>? ?? [],
              );
              _selectedLearnSkills = List<String>.from(
                userData['learnSkills'] as List<dynamic>? ?? [],
              );
              _isInitialized = true;
              _hasChanges = false;
            });
          }

          // Add listeners after data is loaded to avoid triggering _markAsChanged during initialization
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _nameController.addListener(_markAsChanged);
              _emailController.addListener(_markAsChanged);
              _phoneController.addListener(_markAsChanged);
              _bioController.addListener(_markAsChanged);
            }
          });
        } else {
          setState(() => _isInitialized = true);
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    super.dispose();
  }

  void _markAsChanged() {
    if (!_hasChanges && _isInitialized && mounted) {
      setState(() => _hasChanges = true);
    }
  }

  Future<void> _saveChanges() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedFaculty == null || _selectedFaculty!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your faculty'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedTeachSkills.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one skill you can teach'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedLearnSkills.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one skill you want to learn'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      try {
        // Prepare data
        final profileData = {
          'name': _nameController.text.trim(),
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim().isNotEmpty
              ? _phoneController.text.trim()
              : null,
          'bio': _bioController.text.trim(),
          'faculty': _selectedFaculty,
          'availability': _selectedAvailability ?? 'Available',
          'preference': _selectedPreference ?? 'Hybrid (Online + In-Person)',
          'teachSkills': _selectedTeachSkills,
          'learnSkills': _selectedLearnSkills,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Update Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .update(profileData);

        // Update email if changed
        if (_emailController.text.trim() != user.email) {
          await user.updateEmail(_emailController.text.trim());
        }

        if (mounted) {
          setState(() {
            _isLoading = false;
            _hasChanges = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Profile updated successfully! 🎉'),
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

          Navigator.pop(context, true); // Return true to indicate success
        }
      } catch (e) {
        print('Error updating profile: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 10),
                  Text('Error updating profile: ${e.toString()}'),
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

  void _showDiscardDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Discard Changes?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'You have unsaved changes. Are you sure you want to discard them?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close edit screen
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
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

    return WillPopScope(
      onWillPop: () async {
        if (_hasChanges) {
          _showDiscardDialog();
          return false;
        }
        return true;
      },
      child: Scaffold(
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
                          child: Form(
                            key: _formKey,
                            child: ListView(
                              padding: const EdgeInsets.all(25),
                              children: [
                                // Profile Picture Section
                                _buildProfilePictureSection(),
                                const SizedBox(height: 30),
                                // Basic Info
                                _buildSectionTitle(
                                  Icons.person_outline,
                                  context.l10n.basicInformation,
                                ),
                                const SizedBox(height: 15),
                                _buildTextField(
                                  controller: _nameController,
                                  label: context.l10n.name,
                                  icon: Icons.person,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your name';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 15),
                                _buildTextField(
                                  controller: _emailController,
                                  label: context.l10n.email,
                                  icon: Icons.email,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please enter your email';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Please enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 15),
                                _buildTextField(
                                  controller: _phoneController,
                                  label: 'Phone Number',
                                  icon: Icons.phone,
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 15),
                                _buildDropdownField(
                                  label: 'Faculty',
                                  icon: Icons.school,
                                  value: _selectedFaculty ?? '',
                                  items: _faculties,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedFaculty = value;
                                      _markAsChanged();
                                    });
                                  },
                                ),
                                const SizedBox(height: 30),
                                // Bio
                                _buildSectionTitle(Icons.edit_note, 'About Me'),
                                const SizedBox(height: 15),
                                _buildTextField(
                                  controller: _bioController,
                                  label: 'Bio',
                                  icon: Icons.article,
                                  maxLines: 5,
                                  maxLength: 250,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Please write something about yourself';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 30),
                                // Skills I Can Teach
                                _buildSectionTitle(
                                  Icons.school,
                                  'Skills I Can Teach',
                                ),
                                const SizedBox(height: 15),
                                _buildSkillsSelector(
                                  selectedSkills: _selectedTeachSkills,
                                  allSkills: _allSkills,
                                  color: const Color(0xFF667eea),
                                ),
                                const SizedBox(height: 30),
                                // Skills I Want to Learn
                                _buildSectionTitle(
                                  Icons.auto_stories,
                                  'Skills I Want to Learn',
                                ),
                                const SizedBox(height: 15),
                                _buildSkillsSelector(
                                  selectedSkills: _selectedLearnSkills,
                                  allSkills: _allSkills,
                                  color: const Color(0xFF764ba2),
                                ),
                                const SizedBox(height: 30),
                                // Availability & Preferences
                                _buildSectionTitle(
                                  Icons.settings,
                                  'Availability & Preferences',
                                ),
                                const SizedBox(height: 15),
                                _buildDropdownField(
                                  label: 'Availability Status',
                                  icon: Icons.schedule,
                                  value: _selectedAvailability ?? 'Available',
                                  items: _availabilityOptions,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedAvailability = value;
                                      _markAsChanged();
                                    });
                                  },
                                ),
                                const SizedBox(height: 15),
                                _buildDropdownField(
                                  label: 'Learning Preference',
                                  icon: Icons.psychology,
                                  value:
                                      _selectedPreference ??
                                      'Hybrid (Online + In-Person)',
                                  items: _learningPreferences,
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedPreference = value;
                                      _markAsChanged();
                                    });
                                  },
                                ),
                                const SizedBox(height: 40),
                                // Save Button
                                SizedBox(
                                  width: double.infinity,
                                  height: 55,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _saveChanges,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF667eea),
                                      disabledBackgroundColor:
                                          Colors.grey.shade300,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                      elevation: 5,
                                      shadowColor: const Color(
                                        0xFF667eea,
                                      ).withOpacity(0.5),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2.5,
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: const [
                                              Icon(Icons.save, size: 22),
                                              SizedBox(width: 10),
                                              Text(
                                                'Save Changes',
                                                style: TextStyle(
                                                  fontSize: 18,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 20),
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
              onPressed: () {
                if (_hasChanges) {
                  _showDiscardDialog();
                } else {
                  Navigator.pop(context);
                }
              },
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
                  'Edit Profile',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Update your information',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          if (_hasChanges)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Unsaved',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    final user = FirebaseAuth.instance.currentUser;
    final userName = _nameController.text.isNotEmpty
        ? _nameController.text[0].toUpperCase()
        : user?.displayName?.isNotEmpty == true
        ? user!.displayName![0].toUpperCase()
        : 'U';

    return Center(
      child: Stack(
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
                userName,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: () {
                // Open image picker
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: const [
                        Icon(Icons.camera_alt, color: Colors.white),
                        SizedBox(width: 10),
                        Text('Image picker opening...'),
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
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.white,
                  size: 20,
                ),
              ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int? maxLines,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines ?? 1,
      maxLength: maxLength,
      enableInteractiveSelection: true,
      enableSuggestions: keyboardType != TextInputType.emailAddress && keyboardType != TextInputType.phone,
      autocorrect: keyboardType != TextInputType.emailAddress && keyboardType != TextInputType.phone,
      inputFormatters: [],
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      validator: validator,
    );
  }

  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required String value,
    required List<String> items,
    required Function(String?) onChanged,
  }) {
    // Ensure value exists in items, otherwise use null
    final validValue = value.isNotEmpty && items.contains(value) ? value : null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey.shade600),
          const SizedBox(width: 15),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: validValue,
              decoration: InputDecoration(
                labelText: label,
                border: InputBorder.none,
              ),
              items: items.map((item) {
                return DropdownMenuItem(value: item, child: Text(item));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkillsSelector({
    required List<String> selectedSkills,
    required List<String> allSkills,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Selected: ${selectedSkills.length}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              if (selectedSkills.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setState(() {
                      selectedSkills.clear();
                      _markAsChanged();
                    });
                  },
                  child: const Text(
                    'Clear All',
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
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: allSkills.map((skill) {
            final isSelected = selectedSkills.contains(skill);
            return FilterChip(
              label: Text(skill),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    selectedSkills.add(skill);
                  } else {
                    selectedSkills.remove(skill);
                  }
                  _markAsChanged();
                });
              },
              selectedColor: color.withOpacity(0.2),
              checkmarkColor: color,
              labelStyle: TextStyle(
                color: isSelected ? color : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? color : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              elevation: isSelected ? 4 : 0,
              shadowColor: color.withOpacity(0.3),
            );
          }).toList(),
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
