import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'dart:math' as math;

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({Key? key}) : super(key: key);

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _profileVisibility = true;
  bool _showEmail = false;
  bool _showPhone = false;
  bool _showLastSeen = true;
  bool _showOnlineStatus = true;
  bool _allowMessages = true;
  bool _allowSessionRequests = true;
  bool _showInSearch = true;
  String _whoCanViewProfile = 'Everyone';
  String _whoCanMessageMe = 'Connections Only';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _particleControllers = List.generate(
      8,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 5000 + math.Random(index).nextInt(3000)),
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
    _loadPrivacySettings();
  }

  @override
  void dispose() {
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadPrivacySettings() async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) return;

      final userDoc = await SupabaseDb.instance
          .collection('users')
          .doc(currentUser.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        if (data != null) {
          final privacy = data['privacy'] as Map<String, dynamic>? ?? {};

          if (mounted) {
            setState(() {
              _profileVisibility = privacy['profileVisibility'] as bool? ?? true;
              _showEmail = privacy['showEmail'] as bool? ?? false;
              _showPhone = privacy['showPhone'] as bool? ?? false;
              _showLastSeen = privacy['showLastSeen'] as bool? ?? true;
              _showOnlineStatus = privacy['showOnlineStatus'] as bool? ?? true;
              _allowMessages = privacy['allowMessages'] as bool? ?? true;
              _allowSessionRequests = privacy['allowSessionRequests'] as bool? ?? true;
              _showInSearch = privacy['showInSearch'] as bool? ?? true;
              _whoCanViewProfile = privacy['whoCanViewProfile'] as String? ?? 'Everyone';
              _whoCanMessageMe = privacy['whoCanMessageMe'] as String? ?? 'Connections Only';
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      print('Error loading privacy settings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveSettings() async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) return;

      await SupabaseDb.instance
          .collection('users')
          .doc(currentUser.uid)
          .update({
        'privacy': {
          'profileVisibility': _profileVisibility,
          'showEmail': _showEmail,
          'showPhone': _showPhone,
          'showLastSeen': _showLastSeen,
          'showOnlineStatus': _showOnlineStatus,
          'allowMessages': _allowMessages,
          'allowSessionRequests': _allowSessionRequests,
          'showInSearch': _showInSearch,
          'whoCanViewProfile': _whoCanViewProfile,
          'whoCanMessageMe': _whoCanMessageMe,
        },
        'updatedAt': DbFieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Text('Privacy settings saved!'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
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
                            : ListView(
                                padding: const EdgeInsets.all(20),
                                children: [
                                  _buildSection('Profile Privacy', [
                                    _buildSwitchTile(Icons.visibility, 'Profile Visibility', 'Make your profile visible to others', _profileVisibility, (val) => setState(() => _profileVisibility = val)),
                                    _buildSwitchTile(Icons.search, 'Show in Search', 'Appear in search results', _showInSearch, (val) => setState(() => _showInSearch = val)),
                                    _buildDropdownTile(Icons.people, 'Who Can View Profile', _whoCanViewProfile, ['Everyone', 'Connections Only', 'No One'], (val) => setState(() => _whoCanViewProfile = val!)),
                                  ]),
                                  const SizedBox(height: 25),
                                  _buildSection('Contact Information', [
                                    _buildSwitchTile(Icons.email, 'Show Email', 'Display email on your profile', _showEmail, (val) => setState(() => _showEmail = val)),
                                    _buildSwitchTile(Icons.phone, 'Show Phone', 'Display phone number on your profile', _showPhone, (val) => setState(() => _showPhone = val)),
                                  ]),
                                  const SizedBox(height: 25),
                                  _buildSection('Activity Status', [
                                    _buildSwitchTile(Icons.circle, 'Show Online Status', 'Let others see when you\'re online', _showOnlineStatus, (val) => setState(() => _showOnlineStatus = val)),
                                    _buildSwitchTile(Icons.access_time, 'Show Last Seen', 'Display your last active time', _showLastSeen, (val) => setState(() => _showLastSeen = val)),
                                  ]),
                                  const SizedBox(height: 25),
                                  _buildSection('Communication', [
                                    _buildSwitchTile(Icons.message, 'Allow Messages', 'Receive messages from others', _allowMessages, (val) => setState(() => _allowMessages = val)),
                                    _buildDropdownTile(Icons.chat, 'Who Can Message Me', _whoCanMessageMe, ['Everyone', 'Connections Only', 'No One'], (val) => setState(() => _whoCanMessageMe = val!)),
                                    _buildSwitchTile(Icons.calendar_today, 'Allow Session Requests', 'Receive session requests', _allowSessionRequests, (val) => setState(() => _allowSessionRequests = val)),
                                  ]),
                                  const SizedBox(height: 25),
                                  _buildDataSection(),
                                  const SizedBox(height: 30),
                                  _buildSaveButton(),
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
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Privacy Settings', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                SizedBox(height: 2),
                Text('Control your privacy', style: TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5, bottom: 12),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [Color(0xFF667eea), Color(0xFF764ba2)]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.lock, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF667eea))),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile(IconData icon, String title, String subtitle, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      secondary: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF667eea).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF667eea), size: 22),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF667eea),
    );
  }

  Widget _buildDropdownTile(IconData icon, String title, String value, List<String> items, Function(String?) onChanged) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF667eea), size: 22),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: value,
              decoration: InputDecoration(labelText: title, border: InputBorder.none),
              items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning, color: Colors.red, size: 24),
              SizedBox(width: 10),
              Text('Data & Privacy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.red)),
            ],
          ),
          const SizedBox(height: 15),
          _buildDataOption(Icons.download, 'Download My Data', 'Get a copy of your data'),
          const SizedBox(height: 10),
          _buildDataOption(Icons.delete_forever, 'Delete Account', 'Permanently delete your account'),
        ],
      ),
    );
  }

  Widget _buildDataOption(IconData icon, String title, String subtitle) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title feature coming soon')),
        );
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.red, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton.icon(
        onPressed: _saveSettings,
        icon: const Icon(Icons.save, size: 22),
        label: const Text('Save Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF667eea),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
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
            offset: Offset(math.sin(value * 2 * math.pi) * 20, -math.cos(value * 2 * math.pi) * 30),
            child: Opacity(
              opacity: (0.1 + (math.sin(value * 2 * math.pi) * 0.3)).clamp(0.0, 1.0),
              child: child,
            ),
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), shape: BoxShape.circle),
        ),
      ),
    );
  }
}







