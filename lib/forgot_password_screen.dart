import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'dart:math' as math;

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;
  List<AnimationController>? _particleControllers;
  late AnimationController _iconController;
  late AnimationController _successController;
  late Animation<double> _iconAnimation;
  late Animation<double> _successAnimation;

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

    // Initialize icon animation
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _iconAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: Curves.elasticOut),
    );
    _iconController.forward();

    // Initialize success animation
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _successAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _iconController.dispose();
    _successController.dispose();
    _particleControllers?.forEach((controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        await SupabaseService.auth.resetPasswordForEmail(_emailController.text.trim(), redirectTo: kIsWeb ? Uri.base.origin : 'com.iu.talendx://login-callback');

        if (mounted) {
          setState(() {
            _isLoading = false;
            _emailSent = true;
          });
          _successController.forward();
          _showSuccessSnackBar('تم إرسال رابط إعادة تعيين كلمة المرور بنجاح!');
        }
      } on AuthException catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          String errorMessage = 'حدث خطأ أثناء إرسال الرابط';
          if (e.code == 'over_email_send_rate_limit' || e.code == 'too-many-requests') {
            errorMessage = 'تم إرسال العديد من الطلبات. يرجى المحاولة لاحقاً';
          } else if (e.code == 'validation_failed' || e.code == 'invalid-email') {
            errorMessage = 'البريد الإلكتروني غير صحيح';
          } else if (e.message.isNotEmpty) {
            errorMessage = e.message;
          }
          _showErrorSnackBar(errorMessage);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          _showErrorSnackBar('حدث خطأ: ${e.toString()}');
        }
      }
    }
  }

  void _backToLogin() {
    Navigator.pop(context);
  }

  Future<void> _resendLink() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await SupabaseService.auth.resetPasswordForEmail(_emailController.text.trim(), redirectTo: kIsWeb ? Uri.base.origin : 'com.iu.talendx://login-callback');

      if (mounted) {
        setState(() => _isLoading = false);
        _showSuccessSnackBar('تم إرسال رابط جديد إلى ${_emailController.text}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showErrorSnackBar('حدث خطأ أثناء إعادة الإرسال: ${e.toString()}');
      }
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
        duration: const Duration(seconds: 3),
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
                  // Header with back button
                  _buildHeader(),

                  // Scrollable content
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Animated Icon
                            _buildLockIcon(),
                            const SizedBox(height: 35),

                            // Title and Description
                            if (!_emailSent) ...[
                              const Text(
                                'نسيت كلمة المرور؟',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 15),
                              Text(
                                'لا تقلق! أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة التعيين',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withOpacity(0.9),
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ] else ...[
                              const Text(
                                'تحقق من بريدك الإلكتروني',
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 15),
                              Text(
                                'لقد أرسلنا رابط إعادة تعيين كلمة المرور إلى',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.white.withOpacity(0.9),
                                  height: 1.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 10),
                              _buildEmailBadge(),
                            ],

                            const SizedBox(height: 40),

                            // Main Card
                            if (!_emailSent)
                              _buildResetCard()
                            else
                              _buildSuccessCard(),

                            const SizedBox(height: 25),

                            // Info Box
                            _buildInfoBox(),

                            const SizedBox(height: 20),
                          ],
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
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(
                    Icons.arrow_back_ios_new,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLockIcon() {
    return ScaleTransition(
      scale: _emailSent ? _successAnimation : _iconAnimation,
      child: Container(
        width: 130,
        height: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 5,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Icon with gradient
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: Icon(
                _emailSent ? Icons.mark_email_read : Icons.lock_reset,
                size: 65,
                color: Colors.white,
              ),
            ),

            // Badge
            if (_emailSent)
              Positioned(
                bottom: 15,
                right: 15,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF11998e).withOpacity(0.5),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 18),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.email, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _emailController.text,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResetCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Card Title
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.vpn_key,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'إعادة تعيين كلمة المرور',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF667eea),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Email Field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'البريد الإلكتروني',
                hintText: 'أدخل بريدك الإلكتروني المسجل',
                prefixIcon: const Icon(Icons.email_outlined),
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'يرجى إدخال بريدك الإلكتروني';
                }
                if (!value.contains('@')) {
                  return 'يرجى إدخال بريد إلكتروني صحيح';
                }
                return null;
              },
            ),
            const SizedBox(height: 30),

            // Send Reset Link Button
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _sendResetLink,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF667eea),
                  disabledBackgroundColor: Colors.grey.shade300,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 5,
                  shadowColor: const Color(0xFF667eea).withOpacity(0.5),
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
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text(
                            'إرسال رابط إعادة التعيين',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.send, color: Colors.white, size: 20),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 25),

            // Divider
            Row(
              children: [
                Expanded(
                  child: Divider(color: Colors.grey.shade300, thickness: 1),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  child: Text(
                    'أو',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                Expanded(
                  child: Divider(color: Colors.grey.shade300, thickness: 1),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Back to Login
            TextButton.icon(
              onPressed: _backToLogin,
              icon: const Icon(
                Icons.arrow_back,
                color: Color(0xFF667eea),
                size: 20,
              ),
              label: const Text(
                'العودة لتسجيل الدخول',
                style: TextStyle(
                  color: Color(0xFF667eea),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Success Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF11998e), Color(0xFF38ef7d)],
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF11998e).withOpacity(0.3),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.mark_email_read,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'تم إرسال البريد بنجاح!',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF667eea),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'يرجى التحقق من بريدك الإلكتروني والضغط على الرابط لإعادة تعيين كلمة المرور',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          // Back to Login Button
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _backToLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
                shadowColor: const Color(0xFF667eea).withOpacity(0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.login, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    'العودة لتسجيل الدخول',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 25),

          // Divider
          Row(
            children: [
              Expanded(
                child: Divider(color: Colors.grey.shade300, thickness: 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Text(
                  'أو',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Divider(color: Colors.grey.shade300, thickness: 1),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Resend Link
          TextButton.icon(
            onPressed: _isLoading ? null : _resendLink,
            icon: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF667eea),
                    ),
                  )
                : const Icon(Icons.refresh, color: Color(0xFF667eea), size: 22),
            label: Text(
              _isLoading ? 'جاري الإرسال...' : 'إعادة إرسال الرابط',
              style: TextStyle(
                color: _isLoading ? Colors.grey : const Color(0xFF667eea),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.info_outline,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'تحتاج مساعدة؟',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _emailSent
                      ? 'إذا لم تستلم البريد، تحقق من مجلد الرسائل غير المرغوب فيها أو حاول إعادة الإرسال.'
                      : 'أدخل البريد الإلكتروني الذي استخدمته للتسجيل. سنرسل لك رابطاً آمناً لإعادة تعيين كلمة المرور.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
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

























