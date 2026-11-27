import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'email_verification_pending_screen.dart';
import 'profile_setup_screen.dart';
import 'home_screen.dart';
import 'utils/app_localizations.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _agreeToTerms = false;

  String? _selectedFaculty;

  List<AnimationController>? _particleControllers;

  final List<Map<String, dynamic>> _faculties = [
    {'name': 'Computer Science', 'icon': Icons.computer},
    {'name': 'Nursing', 'icon': Icons.healing},
    {'name': 'Physical Therapy', 'icon': Icons.fitness_center},
    {'name': 'Fine Arts', 'icon': Icons.palette},
    {'name': 'Commerce', 'icon': Icons.business},
    {'name': 'Engineering', 'icon': Icons.engineering},
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
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _particleControllers?.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _signUp() async {
    if (_formKey.currentState!.validate()) {
      if (!_agreeToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please agree to Terms & Conditions'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (_selectedFaculty == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select your faculty'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      setState(() => _isLoading = true);

      try {
        // Create user account
        final res = await SupabaseService.auth.signUp(
          email: _emailController.text.trim(),
          password: _passwordController.text,
          emailRedirectTo: kIsWeb ? Uri.base.origin : 'com.iu.talendx://login-callback',
          data: {
            'name': _nameController.text.trim(),
            if (_selectedFaculty != null) 'faculty': _selectedFaculty,
          },
        );
        if (res.session != null && res.user != null) {
          final email = res.user!.email ?? _emailController.text.trim();
          final isAdminEmail = email.toLowerCase() == 'domaduios@gmail.com';
          await SupabaseDb.instance.collection('users').doc(res.user!.id).set({
            'email': email,
            'name': _nameController.text.trim(),
            'faculty': _selectedFaculty,
            'emailVerified': true,
            'profileCompleted': false,
            'isAdmin': isAdminEmail,
            'role': isAdminEmail ? 'admin' : 'user',
            'createdAt': DbFieldValue.serverTimestamp(),
            'updatedAt': DbFieldValue.serverTimestamp(),
          });
          if (mounted) {
            setState(() => _isLoading = false);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ProfileSetupScreen(
                  userName: _nameController.text.trim(),
                  userEmail: email,
                  userFaculty: _selectedFaculty,
                ),
              ),
            );
          }
          return;
        }

        // Don't save to Firestore yet - wait for email verification
        // Data will be saved after email verification in EmailVerificationPendingScreen

        if (mounted) {
          setState(() => _isLoading = false);
          // Navigate to email verification screen with user data
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => EmailVerificationPendingScreen(
                email: _emailController.text.trim(),
                name: _nameController.text.trim(),
                faculty: _selectedFaculty,
              ),
            ),
          );
        }
      } on AuthException catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          String errorMessage = 'حدث خطأ أثناء إنشاء الحساب';
          final msg = e.message.toLowerCase();
          if (e.code == 'weak_password' || e.code == 'weak-password') {
            errorMessage = 'كلمة المرور ضعيفة جداً';
          } else if (e.code == 'user_already_exists' || e.code == 'email-already-in-use' || msg.contains('already registered')) {
            errorMessage = 'البريد الإلكتروني مستخدم بالفعل';
          } else if (e.code == 'over_email_send_rate_limit') {
            errorMessage = 'تم إرسال رسائل كثيرة جداً. يرجى المحاولة لاحقاً.';
          } else if (e.code == 'validation_failed' || e.code == 'invalid-email') {
            errorMessage = 'البريد الإلكتروني غير صحيح';
          } else if (e.message.isNotEmpty) {
            errorMessage = 'خطأ: ${e.message}';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('حدث خطأ: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _signUpWithGoogle() async {
    try {
      setState(() => _isLoading = true);
      final ok = await SupabaseService.signInWithGoogle();
      if (!ok) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final signedInUser = SupabaseService.currentUser;
      if (signedInUser != null) {
        final existing = await SupabaseDb.instance.collection('users').doc(signedInUser.id).get();
        if (!existing.exists) {
          final email = signedInUser.email ?? '';
        final isAdminEmail = email.toLowerCase() == 'domaduios@gmail.com';

        await SupabaseDb.instance
            .collection('users')
            .doc(signedInUser.id)
            .set({
              'email': email,
              'name': signedInUser.userMetadata?['name'] as String? ?? '',
              'faculty': null, // User can update later
              'profileCompleted': false,
              'isAdmin': isAdminEmail,
              'role': isAdminEmail ? 'admin' : 'user',
              'createdAt': DbFieldValue.serverTimestamp(),
              'updatedAt': DbFieldValue.serverTimestamp(),
            });
        }
      }

      if (mounted) {
        setState(() => _isLoading = false);

        // Navigate to Profile Setup if new user
        if (signedInUser != null && !(await SupabaseDb.instance.collection('users').doc(signedInUser.id).get()).exists) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ProfileSetupScreen(
                userName: signedInUser.userMetadata?['name'] as String?,
                userEmail: signedInUser.email,
                userFaculty: null,
              ),
            ),
          );
        } else {
          final currentUser = signedInUser;
          if (currentUser != null) {
            try {
              final userDoc = await SupabaseDb.instance
                  .collection('users')
                  .doc(currentUser.uid)
                  .get();

              if (userDoc.exists) {
                final userData = userDoc.data();
                final profileCompleted = userData?['profileCompleted'] == true;

                if (!profileCompleted) {
                  // Navigate to Profile Setup
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProfileSetupScreen(
                        userName: userData?['name'] ?? currentUser.userMetadata?['name'] as String?,
                        userEmail: userData?['email'] ?? currentUser.email,
                        userFaculty: userData?['faculty'],
                      ),
                    ),
                  );
                } else {
                  // Profile completed - Navigate to Home
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                }
              } else {
                // Document doesn't exist - create it and go to Profile Setup
                final email = currentUser.email ?? '';
                final isAdminEmail =
                    email.toLowerCase() == 'domaduios@gmail.com';

                await SupabaseDb.instance
                    .collection('users')
                    .doc(currentUser.uid)
                    .set({
                      'email': email,
                      'name': currentUser.userMetadata?['name'] as String? ?? '',
                      'profileCompleted': false,
                      'isAdmin': isAdminEmail,
                      'role': isAdminEmail ? 'admin' : 'user',
                      'createdAt': DbFieldValue.serverTimestamp(),
                      'updatedAt': DbFieldValue.serverTimestamp(),
                    });

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileSetupScreen(
                      userName: currentUser.userMetadata?['name'] as String?,
                      userEmail: currentUser.email,
                      userFaculty: null,
                    ),
                  ),
                );
              }
            } catch (e) {
              // If error, navigate to Home anyway
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const HomeScreen()),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إنشاء الحساب: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _signUpWithFacebook() {
    // Facebook Sign Up - سيتم إضافتها لاحقاً
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('إنشاء حساب بحساب Facebook قريباً'),
        backgroundColor: Colors.orange,
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
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 20,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: ShaderMask(
                          shaderCallback: (bounds) => const LinearGradient(
                            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                          ).createShader(bounds),
                          child: const Icon(
                            Icons.swap_horiz_rounded,
                            size: 45,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      // App Name
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Talent',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            'X',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      Text(
                        context.l10n.createAccount,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Sign Up Form Card
                      Container(
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
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                context.l10n.signUp,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF667eea),
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 25),

                              // Name Field
                              TextFormField(
                                controller: _nameController,
                                enableInteractiveSelection: true,
                                enableSuggestions: true,
                                autocorrect: true,
                                inputFormatters: [],
                                decoration: InputDecoration(
                                  labelText: context.l10n.name,
                                  prefixIcon: const Icon(Icons.person_outline),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF667eea),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your name';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 15),

                              // Email Field
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                enableInteractiveSelection: true,
                                enableSuggestions: true,
                                autocorrect: true,
                                inputFormatters: [],
                                decoration: InputDecoration(
                                  labelText: context.l10n.email,
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF667eea),
                                      width: 2,
                                    ),
                                  ),
                                ),
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

                              // Faculty Dropdown
                              DropdownButtonFormField<String>(
                                initialValue: _selectedFaculty,
                                decoration: InputDecoration(
                                  labelText: 'Select Faculty',
                                  prefixIcon: const Icon(Icons.school_outlined),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF667eea),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                items: _faculties.map((faculty) {
                                  return DropdownMenuItem<String>(
                                    value: faculty['name'],
                                    child: Row(
                                      children: [
                                        Icon(
                                          faculty['icon'],
                                          size: 20,
                                          color: const Color(0xFF667eea),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(faculty['name']),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedFaculty = value;
                                  });
                                },
                              ),

                              const SizedBox(height: 15),

                              // Password Field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                enableInteractiveSelection: true,
                                enableSuggestions: false,
                                autocorrect: false,
                                inputFormatters: [],
                                decoration: InputDecoration(
                                  labelText: context.l10n.password,
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF667eea),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your password';
                                  }
                                  if (value.length < 6) {
                                    return 'Password must be at least 6 characters';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 15),

                              // Confirm Password Field
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _obscureConfirmPassword =
                                            !_obscureConfirmPassword;
                                      });
                                    },
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF667eea),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please confirm your password';
                                  }
                                  if (value != _passwordController.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 15),

                              // Terms & Conditions Checkbox
                              Row(
                                children: [
                                  Checkbox(
                                    value: _agreeToTerms,
                                    onChanged: (value) {
                                      setState(() {
                                        _agreeToTerms = value ?? false;
                                      });
                                    },
                                    activeColor: const Color(0xFF667eea),
                                  ),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _agreeToTerms = !_agreeToTerms;
                                        });
                                      },
                                      child: const Text(
                                        'I agree to Terms & Conditions',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Sign Up Button
                              SizedBox(
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _signUp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF667eea),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    elevation: 5,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          context.l10n.signUp,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Divider
                              Row(
                                children: [
                                  Expanded(
                                    child: Divider(color: Colors.grey.shade300),
                                  ),
                                  const Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 15,
                                    ),
                                    child: Text(
                                      'OR',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Divider(color: Colors.grey.shade300),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Social Sign Up Buttons
                              Row(
                                children: [
                                  // Google Button
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _signUpWithGoogle,
                                      icon: const Icon(
                                        Icons.g_mobiledata,
                                        color: Colors.red,
                                        size: 28,
                                      ),
                                      label: const Text(
                                        'Google',
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        side: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 12),

                                  // Facebook Button
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _signUpWithFacebook,
                                      icon: const Icon(
                                        Icons.facebook,
                                        color: Color(0xFF1877F2),
                                        size: 28,
                                      ),
                                      label: const Text(
                                        'Facebook',
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        side: BorderSide(
                                          color: Colors.grey.shade300,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            15,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Sign In Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Already have an account?",
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Sign In',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
