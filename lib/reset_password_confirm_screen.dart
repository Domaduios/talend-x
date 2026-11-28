import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'utils/app_localizations.dart';

class ResetPasswordConfirmScreen extends StatefulWidget {
  const ResetPasswordConfirmScreen({super.key});

  @override
  State<ResetPasswordConfirmScreen> createState() =>
      _ResetPasswordConfirmScreenState();
}

class _ResetPasswordConfirmScreenState
    extends State<ResetPasswordConfirmScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure1 = true;
  bool _obscure2 = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    final isAr = context.l10n.languageCode == 'ar';
    try {
      await SupabaseService.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      SupabaseService.pendingPasswordRecovery = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr
                ? 'تم تعيين كلمة المرور الجديدة بنجاح!'
                : 'Password updated successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
      final user = SupabaseService.currentUser;
      if (user != null) {
        final profile =
            await SupabaseDb.instance.collection('users').doc(user.id).get();
        if (!mounted) return;
        if (profile.exists && profile.data()['profileCompleted'] == true) {
          Navigator.pushReplacementNamed(context, '/home');
          return;
        }
      }
      Navigator.pushReplacementNamed(context, '/signin');
    } on AuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = context.l10n.languageCode == 'ar';
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  elevation: 12,
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.lock_reset,
                            size: 56,
                            color: Color(0xFF667eea),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            isAr ? 'تعيين كلمة مرور جديدة' : 'Set New Password',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure1,
                            decoration: InputDecoration(
                              labelText: isAr ? 'كلمة المرور الجديدة' : 'New Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure1 ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () => setState(() => _obscure1 = !_obscure1),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            validator: (v) {
                              if (v == null || v.length < 6) {
                                return isAr
                                    ? 'كلمة المرور يجب أن تكون 6 أحرف على الأقل'
                                    : 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmController,
                            obscureText: _obscure2,
                            decoration: InputDecoration(
                              labelText: isAr ? 'تأكيد كلمة المرور' : 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure2 ? Icons.visibility : Icons.visibility_off,
                                ),
                                onPressed: () => setState(() => _obscure2 = !_obscure2),
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            validator: (v) {
                              if (v != _passwordController.text) {
                                return isAr
                                    ? 'كلمتا المرور غير متطابقتين'
                                    : 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _updatePassword,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF667eea),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: _isLoading
                                  ? const CircularProgressIndicator(color: Colors.white)
                                  : Text(
                                      isAr ? 'حفظ كلمة المرور' : 'Update Password',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
