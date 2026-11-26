import 'package:flutter/material.dart';
import 'dart:math' as math;

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Getting Started',
    'Sessions',
    'Payments',
    'Safety',
    'Technical',
  ];

  final List<Map<String, dynamic>> _faqs = [
    {
      'question': 'How do I create an account?',
      'answer':
          'To create an account, tap on "Sign Up" on the welcome screen. Fill in your details including name, email, and password. Verify your email address, then complete your profile setup by adding your skills and interests.',
      'category': 'Getting Started',
      'icon': Icons.account_circle,
    },
    {
      'question': 'How does skill exchange work?',
      'answer':
          'Skill exchange is a peer-to-peer learning system where you teach what you know and learn what you need - without money! You can offer sessions in your areas of expertise and book sessions with others to learn new skills. It\'s a win-win collaboration!',
      'category': 'Getting Started',
      'icon': Icons.swap_horiz,
    },
    {
      'question': 'How do I schedule a session?',
      'answer':
          'Browse or search for users with the skill you want to learn. Visit their profile, tap "Schedule Session", select a date and time that works for both of you, add session details, and send the request. Once they accept, you\'ll receive a confirmation.',
      'category': 'Sessions',
      'icon': Icons.calendar_today,
    },
    {
      'question': 'Can I cancel a scheduled session?',
      'answer':
          'Yes, you can cancel a session from the Sessions tab. Select the session and tap "Cancel". Please try to cancel at least 24 hours in advance as a courtesy. Frequent last-minute cancellations may affect your reputation.',
      'category': 'Sessions',
      'icon': Icons.cancel,
    },
    {
      'question': 'What if someone doesn\'t show up?',
      'answer':
          'If your session partner doesn\'t show up, wait 15 minutes, then you can mark them as a no-show in the session details. This will be recorded in their profile. You can also report the incident to our support team.',
      'category': 'Sessions',
      'icon': Icons.event_busy,
    },
    {
      'question': 'How long can sessions be?',
      'answer':
          'Sessions can be anywhere from 30 minutes to 3 hours. The most common duration is 60 minutes. You and your session partner can agree on the length when scheduling.',
      'category': 'Sessions',
      'icon': Icons.access_time,
    },
    {
      'question': 'Is there a limit on sessions per month?',
      'answer':
          'Free accounts can book up to 5 sessions per month. Premium members get unlimited sessions, priority matching, and exclusive features. Upgrade anytime from Settings.',
      'category': 'Sessions',
      'icon': Icons.trending_up,
    },
    {
      'question': 'Do I need to pay for sessions?',
      'answer':
          'No! The core concept of Skill Exchange is free peer-to-peer learning. However, some advanced users offer premium paid sessions for specialized skills. These are clearly marked and optional.',
      'category': 'Payments',
      'icon': Icons.attach_money,
    },
    {
      'question': 'What is Premium membership?',
      'answer':
          'Premium membership (\$9.99/month) includes: unlimited sessions, priority matching, advanced analytics, exclusive badges, ad-free experience, and early access to new features.',
      'category': 'Payments',
      'icon': Icons.star,
    },
    {
      'question': 'How do I report inappropriate behavior?',
      'answer':
          'Tap the three dots on any user\'s profile or message, select "Report User", choose the reason, and provide details. Our team reviews all reports within 24 hours. You can also block users immediately.',
      'category': 'Safety',
      'icon': Icons.report,
    },
    {
      'question': 'Is my personal information safe?',
      'answer':
          'Yes! We take privacy seriously. Your data is encrypted, we never share your information with third parties, and you control what others can see in Privacy Settings. Read our Privacy Policy for details.',
      'category': 'Safety',
      'icon': Icons.security,
    },
    {
      'question': 'Can I choose who sees my profile?',
      'answer':
          'Yes, go to Settings > Privacy Settings to control profile visibility, who can message you, and what information is displayed. You can make your profile visible to everyone, connections only, or no one.',
      'category': 'Safety',
      'icon': Icons.visibility,
    },
    {
      'question': 'How do video calls work?',
      'answer':
          'When your session time arrives, tap "Join Session" to enter the video call. You\'ll have access to camera, microphone, screen sharing, chat, and whiteboard features. Ensure you have a stable internet connection.',
      'category': 'Technical',
      'icon': Icons.video_call,
    },
    {
      'question': 'What if I have connection issues?',
      'answer':
          'For video call issues: check your internet connection, restart the app, ensure camera/mic permissions are enabled, and try switching between WiFi and mobile data. Contact support if problems persist.',
      'category': 'Technical',
      'icon': Icons.wifi,
    },
    {
      'question': 'Can I use the app on multiple devices?',
      'answer':
          'Yes! Your account syncs across all devices. Simply sign in with your email and password on any device. Messages, sessions, and profile updates sync automatically.',
      'category': 'Technical',
      'icon': Icons.devices,
    },
    {
      'question': 'How do reviews work?',
      'answer':
          'After each completed session, both participants can leave a review and rating (1-5 stars). Reviews are public and help others make informed decisions. Be honest but respectful in your feedback.',
      'category': 'Getting Started',
      'icon': Icons.rate_review,
    },
    {
      'question': 'What are achievements and badges?',
      'answer':
          'Complete sessions, help others, and reach milestones to unlock achievements and badges! These appear on your profile and showcase your experience. Check the Achievements page to see what you can earn.',
      'category': 'Getting Started',
      'icon': Icons.emoji_events,
    },
    {
      'question': 'How do I delete my account?',
      'answer':
          'Go to Settings > Privacy Settings > Delete Account. Note: This permanently deletes all your data including messages, sessions, and connections. This action cannot be undone.',
      'category': 'Technical',
      'icon': Icons.delete_forever,
    },
  ];

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
    _searchController.dispose();
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _getFilteredFAQs() {
    return _faqs.where((faq) {
      final matchesCategory =
          _selectedCategory == 'All' || faq['category'] == _selectedCategory;

      final matchesSearch = _searchQuery.isEmpty ||
          faq['question'].toLowerCase().contains(_searchQuery.toLowerCase()) ||
          faq['answer'].toLowerCase().contains(_searchQuery.toLowerCase());

      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredFAQs = _getFilteredFAQs();

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
                        child: Column(
                          children: [
                            _buildSearchBar(),
                            _buildCategoryTabs(),
                            Expanded(
                              child: filteredFAQs.isEmpty
                                  ? _buildNoResults()
                                  : _buildFAQList(filteredFAQs),
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Contact support
        },
        icon: const Icon(Icons.support_agent),
        label: const Text('Contact Support'),
        backgroundColor: const Color(0xFF667eea),
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
                Text('FAQ',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(height: 2),
                Text('Frequently Asked Questions',
                    style: TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        decoration: InputDecoration(
          hintText: 'Search questions...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  icon: const Icon(Icons.clear),
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFF667eea), width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedCategory = category);
              },
              selectedColor: const Color(0xFF667eea).withOpacity(0.2),
              backgroundColor: Colors.grey.shade200,
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF667eea) : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected
                    ? const Color(0xFF667eea)
                    : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              checkmarkColor: const Color(0xFF667eea),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFAQList(List<Map<String, dynamic>> faqs) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: faqs.length,
      itemBuilder: (context, index) {
        return _buildFAQCard(faqs[index]);
      },
    );
  }

  Widget _buildFAQCard(Map<String, dynamic> faq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
          childrenPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(faq['icon'], color: const Color(0xFF667eea), size: 24),
          ),
          title: Text(
            faq['question'],
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                faq['category'],
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF667eea),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          children: [
            Text(
              faq['answer'],
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 20),
          const Text('No results found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text('Try a different search or category',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
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























