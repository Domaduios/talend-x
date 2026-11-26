import 'package:flutter/material.dart';
import 'dart:math' as math;

class TermsScreen extends StatefulWidget {
  const TermsScreen({super.key});

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen>
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
                              '1. Acceptance of Terms',
                              'By accessing and using Skill Exchange ("the App"), you accept and agree to be bound by the terms and conditions of this agreement. If you do not agree to these terms, please do not use the App.',
                            ),
                            _buildSection(
                              '2. Description of Service',
                              'Skill Exchange is a peer-to-peer learning platform that connects students who want to teach skills with those who want to learn. The App facilitates scheduling, video calls, messaging, and skill tracking between users.',
                            ),
                            _buildSection(
                              '3. User Accounts',
                              '• You must be at least 13 years old to use this App\n• You are responsible for maintaining the confidentiality of your account\n• You agree to provide accurate and complete information\n• You are responsible for all activities under your account\n• You must notify us immediately of any unauthorized use',
                            ),
                            _buildSection(
                              '4. User Conduct',
                              'You agree NOT to:\n• Harass, abuse, or harm other users\n• Impersonate any person or entity\n• Upload malicious code or viruses\n• Spam or send unsolicited messages\n• Violate any laws or regulations\n• Share inappropriate content\n• Discriminate based on race, religion, gender, etc.\n• Use the App for commercial purposes without permission',
                            ),
                            _buildSection(
                              '5. Sessions and Bookings',
                              '• Sessions are arranged directly between users\n• Both parties must agree on session details\n• Cancellations should be made 24 hours in advance\n• No-shows may result in account restrictions\n• The App is not responsible for session quality\n• Video calls are subject to internet connectivity',
                            ),
                            _buildSection(
                              '6. Content Ownership',
                              '• You retain ownership of content you create\n• By posting, you grant us a license to use, display, and distribute your content\n• We may remove content that violates these terms\n• You are responsible for your own content\n• We respect intellectual property rights',
                            ),
                            _buildSection(
                              '7. Payments and Subscriptions',
                              '• Basic features are free to use\n• Premium subscriptions are available\n• Payments are processed through secure third parties\n• Subscriptions auto-renew unless cancelled\n• Refunds are subject to our refund policy\n• Prices may change with 30 days notice',
                            ),
                            _buildSection(
                              '8. Privacy',
                              'Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your personal information. By using the App, you consent to our privacy practices.',
                            ),
                            _buildSection(
                              '9. Termination',
                              'We reserve the right to:\n• Suspend or terminate your account for violations\n• Modify or discontinue the App at any time\n• Remove content that violates terms\n\nYou may delete your account at any time through Settings.',
                            ),
                            _buildSection(
                              '10. Disclaimers',
                              '• The App is provided "as is" without warranties\n• We do not guarantee uninterrupted service\n• We are not responsible for user-generated content\n• We do not verify user credentials or qualifications\n• Use at your own risk',
                            ),
                            _buildSection(
                              '11. Limitation of Liability',
                              'Skill Exchange, its founders, employees, and partners shall not be liable for:\n• Any indirect, incidental, or consequential damages\n• Loss of data, profits, or opportunities\n• Issues arising from user interactions\n• Third-party services or links\n\nOur liability is limited to the amount paid (if any) in the past 12 months.',
                            ),
                            _buildSection(
                              '12. Indemnification',
                              'You agree to indemnify and hold harmless Skill Exchange from any claims, damages, or expenses arising from your use of the App, violation of these terms, or violation of any rights of another person.',
                            ),
                            _buildSection(
                              '13. Changes to Terms',
                              'We may update these terms at any time. Continued use of the App after changes constitutes acceptance of the new terms. We will notify users of significant changes via email or in-app notification.',
                            ),
                            _buildSection(
                              '14. Governing Law',
                              'These terms are governed by the laws of [Your Country/State]. Any disputes shall be resolved in the courts of [Your Jurisdiction].',
                            ),
                            _buildSection(
                              '15. Contact Information',
                              'For questions about these Terms of Service, please contact us at:\n\nEmail: legal@skillexchange.com\nAddress: [Your Address]\nPhone: [Your Phone Number]',
                            ),
                            const SizedBox(height: 30),
                            _buildAcknowledgment(),
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
                Text('Terms of Service',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(height: 2),
                Text('Please read carefully',
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
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.info_outline, color: Colors.amber, size: 24),
              SizedBox(width: 10),
              Text(
                'Important Notice',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'These Terms of Service govern your use of Skill Exchange. By creating an account or using our services, you agree to these terms in their entirety.',
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

  Widget _buildAcknowledgment() {
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
          const Icon(Icons.check_circle_outline, color: Colors.white, size: 48),
          const SizedBox(height: 15),
          const Text(
            'Thank You',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Thank you for taking the time to read our Terms of Service. We\'re committed to providing a safe and productive learning environment for all users.',
            style: TextStyle(fontSize: 14, color: Colors.white70, height: 1.5),
            textAlign: TextAlign.center,
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























