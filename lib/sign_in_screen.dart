import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'sign_up_screen.dart';
import 'forgot_password_screen.dart';
import 'profile_setup_screen.dart';
import 'home_screen.dart';
import 'utils/app_localizations.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  List<AnimationController>? _particleControllers;

  @override
  void initState() {
    super.initState();
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
    _emailController.dispose();
    _passwordController.dispose();
    _particleControllers?.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final userCredential = await SupabaseService.auth
            .signInWithPassword(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );

        if (mounted) {
          setState(() => _isLoading = false);

          // Check if user has completed profile setup
          if (userCredential.user != null) {
            try {
              final userDoc = await SupabaseDb.instance
                  .collection('users')
                  .doc(userCredential.user!.id)
                  .get();

              final userData = userDoc.data();
              final profileCompleted = userData?['profileCompleted'] == true;

              if (!profileCompleted) {
                // Navigate to Profile Setup
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileSetupScreen(
                      userName:
                          userData?['name'] ?? userCredential.user?.userMetadata?['name'] as String?,
                      userEmail:
                          userData?['email'] ?? userCredential.user!.email,
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
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('خطأ في قاعدة البيانات: ${e.toString()}'),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            }
          }
        }
      } on AuthException catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          String errorMessage = 'حدث خطأ أثناء تسجيل الدخول';
          if (e.code == 'user-not-found') {
            errorMessage = 'البريد الإلكتروني غير مسجل';
          } else if (e.code == 'wrong-password') {
            errorMessage = 'كلمة المرور غير صحيحة';
          } else if (e.code == 'invalid-email') {
            errorMessage = 'البريد الإلكتروني غير صحيح';
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

  Future<void> _signInWithGoogle() async {
    try {
      setState(() => _isLoading = true);
      final ok = await SupabaseService.signInWithGoogle();
      if (!ok) {
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (mounted) {
        setState(() => _isLoading = false);
        final signedInUser = SupabaseService.currentUser;
        if (signedInUser != null) {
          // Wait a moment to ensure authentication is fully processed
          await Future.delayed(const Duration(milliseconds: 500));

          // Verify user is still authenticated
          final currentUser = SupabaseService.currentUser;
          if (currentUser == null ||
              currentUser.id != signedInUser.id) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'فشل التحقق من تسجيل الدخول. يرجى المحاولة مرة أخرى.',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }

          try {
            // Try to read user document
            final userDoc = await SupabaseDb.instance
                .collection('users')
                .doc(currentUser.uid)
                .get();

            // If document doesn't exist, create it
            if (!userDoc.exists) {
              try {
                // Check if this is an admin email
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

                // Navigate to Profile Setup for new user
                if (mounted) {
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
                return;
              } catch (createError) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'خطأ في إنشاء الملف الشخصي: ${createError.toString()}',
                      ),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 5),
                    ),
                  );
                }
                return;
              }
            }

            // Document exists, check profile completion
            final userData = userDoc.data();
            final profileCompleted = userData?['profileCompleted'] == true;

            if (!profileCompleted) {
              // Navigate to Profile Setup
              if (mounted) {
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
              }
            } else {
              // Profile completed - Navigate to Home
              if (mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              }
            }
          } on PostgrestException catch (e) {
            if (mounted) {
              String errorMessage = 'خطأ في قاعدة البيانات: ';
              if (e.code == 'permission-denied') {
                errorMessage +=
                    'لا توجد صلاحية للوصول. يرجى التحقق من نشر Firestore Rules في Firebase Console.';
              } else {
                errorMessage += e.message ?? e.toString();
              }
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(errorMessage),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 6),
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('خطأ غير متوقع: ${e.toString()}'),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMessage = 'حدث خطأ أثناء تسجيل الدخول';

        // Provide more specific error messages
        if (e.toString().contains('network_error') ||
            e.toString().contains('NETWORK_ERROR')) {
          errorMessage = 'خطأ في الاتصال بالإنترنت. يرجى التحقق من اتصالك';
        } else if (e.toString().contains('sign_in_canceled') ||
            e.toString().contains('SIGN_IN_CANCELED')) {
          errorMessage = 'تم إلغاء تسجيل الدخول';
          return; // Don't show error for user cancellation
        } else if (e.toString().contains('id_token') ||
            e.toString().contains('ID_TOKEN')) {
          errorMessage =
              'خطأ في بيانات المصادقة. يرجى التأكد من إعدادات Google Sign-In في Firebase';
        } else {
          errorMessage = 'حدث خطأ: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _signInWithFacebook() {
    // Facebook Sign In - سيتم إضافتها لاحقاً
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تسجيل الدخول بحساب Facebook قريباً'),
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
                  padding: const EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo
                      Container(
                        width: 100,
                        height: 100,
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
                            size: 55,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // App Name
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'Talent',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w300,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                          Text(
                            'X',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Welcome Back!',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      const SizedBox(height: 50),

                      // Sign In Form Card
                      Container(
                        padding: const EdgeInsets.all(30),
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
                                context.l10n.signIn,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF667eea),
                                ),
                                textAlign: TextAlign.center,
                              ),

                              const SizedBox(height: 30),

                              // Email Field
                              TextFormField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                enableInteractiveSelection: true,
                                enableSuggestions: true,
                                autocorrect: true,
                                // Allow all characters for multi-language support
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
                                    return context.l10n.enterEmail;
                                  }
                                  if (!value.contains('@')) {
                                    return context.l10n.enterEmail;
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 20),

                              // Password Field
                              TextFormField(
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                enableInteractiveSelection: true,
                                enableSuggestions:
                                    false, // Disable for password
                                autocorrect: false, // Disable for password
                                // Allow all characters for multi-language support
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
                                    return context.l10n.enterPassword;
                                  }
                                  if (value.length < 6) {
                                    return context.l10n.passwordMinLength;
                                  }
                                  return null;
                                },
                              ),

                              const SizedBox(height: 10),

                              // Forgot Password
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: Text(
                                    context.l10n.forgotPassword,
                                    style: const TextStyle(
                                      color: Color(0xFF667eea),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Sign In Button
                              SizedBox(
                                height: 55,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _signIn,
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
                                          context.l10n.signIn,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 25),

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

                              const SizedBox(height: 25),

                              // Social Sign In Buttons
                              Row(
                                children: [
                                  // Google Button
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _signInWithGoogle,
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
                                          vertical: 15,
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

                                  const SizedBox(width: 15),

                                  // Facebook Button
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _signInWithFacebook,
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
                                          vertical: 15,
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

                      const SizedBox(height: 25),

                      // Sign Up Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account?",
                            style: TextStyle(color: Colors.white, fontSize: 15),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                PageRouteBuilder(
                                  pageBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                      ) => const SignUpScreen(),
                                  transitionDuration: const Duration(
                                    milliseconds: 300,
                                  ),
                                  transitionsBuilder:
                                      (
                                        context,
                                        animation,
                                        secondaryAnimation,
                                        child,
                                      ) {
                                        return SlideTransition(
                                          position:
                                              Tween<Offset>(
                                                begin: const Offset(1.0, 0.0),
                                                end: Offset.zero,
                                              ).animate(
                                                CurvedAnimation(
                                                  parent: animation,
                                                  curve: Curves.easeInOut,
                                                ),
                                              ),
                                          child: child,
                                        );
                                      },
                                ),
                              );
                            },
                            child: const Text(
                              'Sign Up',
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
