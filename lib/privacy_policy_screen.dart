import 'package:flutter/material.dart';
import 'dart:math' as math;

class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen>
    with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _particleControllers = List.generate(
      8,
      (index) => AnimationController(
        vsync: this,
        duration:
            Duration(milliseconds: 5000 + math.Random(index).nextInt(3000)),
      )..repeat(),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    super.dispose();
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
                        child: ListView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(25),
                          children: [
                            _buildLastUpdated(),
                            const SizedBox(height: 20),
                            _buildIntro(),
                            const SizedBox(height: 30),
                            _buildSection(
                              '1. Information We Collect',
                              '**Personal Information:**\n• Name and email address\n• Profile photo\n• University/institution name\n• Skills and interests\n• Date of birth\n\n**Usage Information:**\n• Session history and duration\n• Messages and communications\n• Device information\n• IP address and location\n• App usage patterns',
                            ),
                            _buildSection(
                              '2. How We Use Your Information',
                              'We use collected information to:\n• Provide and improve our services\n• Match you with appropriate learning partners\n• Facilitate video calls and messaging\n• Send notifications about sessions\n• Analyze usage patterns\n• Prevent fraud and ensure safety\n• Communicate updates and changes\n• Comply with legal obligations',
                            ),
                            _buildSection(
                              '3. Information Sharing',
                              '**We DO share:**\n• Your profile with other users (as per your privacy settings)\n• Session details with your learning partners\n• Aggregated, anonymized data for analytics\n\n**We DO NOT share:**\n• Your personal information with third parties for marketing\n• Your password or payment details\n• Private messages without consent\n• Data to third parties without your permission',
                            ),
                            _buildSection(
                              '4. Data Security',
                              'We implement industry-standard security measures:\n• End-to-end encryption for messages\n• Secure HTTPS connections\n• Regular security audits\n• Encrypted data storage\n• Access controls and authentication\n• Automatic logout after inactivity\n\nHowever, no system is 100% secure. Use strong passwords and enable two-factor authentication.',
                            ),
                            _buildSection(
                              '5. Your Privacy Rights',
                              'You have the right to:\n• Access your personal data\n• Correct inaccurate information\n• Delete your account and data\n• Export your data\n• Opt-out of marketing communications\n• Control privacy settings\n• Lodge complaints with authorities\n\nExercise these rights through Settings or contact us directly.',
                            ),
                            _buildSection(
                              '6. Cookies and Tracking',
                              'We use cookies and similar technologies to:\n• Remember your preferences\n• Analyze app performance\n• Provide personalized content\n• Improve user experience\n\nYou can disable cookies in your device settings, but this may affect functionality.',
                            ),
                            _buildSection(
                              '7. Third-Party Services',
                              'We integrate with third-party services:\n• Video calling (Agora/WebRTC)\n• Payment processing (Stripe/PayPal)\n• Analytics (Firebase Analytics)\n• Cloud storage (AWS/Google Cloud)\n\nThese services have their own privacy policies. We recommend reviewing them.',
                            ),
                            _buildSection(
                              '8. Children\'s Privacy',
                              'Users must be at least 13 years old. If you\'re under 18, please get parental consent. We do not knowingly collect data from children under 13. If we discover such data, we will delete it immediately.',
                            ),
                            _buildSection(
                              '9. Data Retention',
                              '• Active accounts: Data retained as long as account is active\n• Deleted accounts: Most data deleted within 30 days\n• Legal requirements: Some data may be retained longer\n• Backups: May persist up to 90 days\n• Anonymized data: May be retained indefinitely',
                            ),
                            _buildSection(
                              '10. International Transfers',
                              'Your data may be transferred to and stored in countries outside your residence. We ensure adequate protection through:\n• Standard contractual clauses\n• Privacy Shield compliance (where applicable)\n• Appropriate safeguards\n\nBy using the App, you consent to these transfers.',
                            ),
                            _buildSection(
                              '11. Changes to Privacy Policy',
                              'We may update this policy periodically. We will notify you of significant changes via:\n• Email notification\n• In-app notification\n• Banner on login screen\n\nContinued use after changes constitutes acceptance.',
                            ),
                            _buildSection(
                              '12. California Privacy Rights (CCPA)',
                              'California residents have additional rights:\n• Right to know what data is collected\n• Right to delete personal information\n• Right to opt-out of data sales (we don\'t sell data)\n• Right to non-discrimination\n\nContact us to exercise these rights.',
                            ),
                            _buildSection(
                              '13. GDPR Compliance (EU Users)',
                              'For EU users, we comply with GDPR:\n• Lawful basis for processing\n• Data minimization\n• Purpose limitation\n• Storage limitation\n• Right to be forgotten\n• Data portability\n• Right to object\n\nContact our Data Protection Officer for inquiries.',
                            ),
                            _buildSection(
                              '14. Contact Us',
                              'For privacy-related questions or to exercise your rights:\n\n**Email:** privacy@skillexchange.com\n**Address:** [Your Address]\n**Phone:** [Your Phone]\n**Data Protection Officer:** dpo@skillexchange.com\n\nWe respond to requests within 30 days.',
                            ),
                            const SizedBox(height: 30),
                            _buildCommitment(),
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
              icon: const Icon(Icons.arrow_back_ios_new,
                  color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Privacy Policy',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(height: 2),
                Text('Your privacy matters to us',
                    style: TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdated() {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF667eea).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF667eea).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.update, color: Color(0xFF667eea), size: 20),
          const SizedBox(width: 10),
          const Text(
            'Last Updated: ',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          Text(
            'November 27, 2024',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.security, color: Colors.green, size: 24),
              SizedBox(width: 10),
              Text(
                'Your Privacy is Protected',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'At Skill Exchange, we are committed to protecting your privacy and personal information. This Privacy Policy explains how we collect, use, and safeguard your data.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade700, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 25),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF667eea),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommitment() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          const Icon(Icons.verified_user, color: Colors.white, size: 48),
          const SizedBox(height: 15),
          const Text(
            'Our Commitment',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'We are committed to transparency, security, and giving you control over your personal information. Your trust is our priority.',
            style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCommitmentBadge(Icons.lock, 'Encrypted'),
              _buildCommitmentBadge(Icons.visibility_off, 'Private'),
              _buildCommitmentBadge(Icons.shield, 'Secure'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommitmentBadge(IconData icon, String label) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
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
            offset: Offset(math.sin(value * 2 * math.pi) * 20,
                -math.cos(value * 2 * math.pi) * 30),
            child: Opacity(
                opacity: (0.1 + (math.sin(value * 2 * math.pi) * 0.3))
                    .clamp(0.0, 1.0),
                child: child),
          );
        },
        child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3), shape: BoxShape.circle)),
      ),
    );
  }
}























