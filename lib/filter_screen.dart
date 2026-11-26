import 'package:flutter/material.dart';
import 'dart:math' as math;

class FilterScreen extends StatefulWidget {
  final Map<String, dynamic>? initialFilters;

  const FilterScreen({super.key, this.initialFilters});

  @override
  State<FilterScreen> createState() => _FilterScreenState();
}

class _FilterScreenState extends State<FilterScreen>
    with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Filter states
  String _selectedFaculty = 'All';
  String _selectedAvailability = 'All';
  String _selectedRating = 'All';
  RangeValues _sessionRange = const RangeValues(0, 50);
  RangeValues _matchRange = const RangeValues(0, 100);
  List<String> _selectedSkills = [];
  bool _onlineOnly = false;
  bool _verifiedOnly = false;

  final List<String> _faculties = [
    'All',
    'Computer Science',
    'Engineering',
    'Nursing',
    'Physical Therapy',
    'Fine Arts',
    'Commerce',
  ];

  final List<String> _availabilityOptions = [
    'All',
    'Available Now',
    'Available Today',
    'Available This Week',
  ];

  final List<String> _ratingOptions = [
    'All',
    '4.5+',
    '4.0+',
    '3.5+',
    '3.0+',
  ];

  final List<String> _skills = [
    'Programming',
    'Web Development',
    'Mobile Apps',
    'AI/ML',
    'UI/UX Design',
    'Graphic Design',
    'Data Science',
    'Cloud Computing',
    'Cybersecurity',
    'Digital Marketing',
  ];

  @override
  void initState() {
    super.initState();

    // Load initial filters if provided
    if (widget.initialFilters != null) {
      _selectedFaculty = widget.initialFilters!['faculty'] ?? 'All';
      _selectedAvailability =
          widget.initialFilters!['availability'] ?? 'All';
      _selectedRating = widget.initialFilters!['rating'] ?? 'All';
      _onlineOnly = widget.initialFilters!['onlineOnly'] ?? false;
      _verifiedOnly = widget.initialFilters!['verifiedOnly'] ?? false;
      _selectedSkills =
          List<String>.from(widget.initialFilters!['skills'] ?? []);
    }

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
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _getFilters() {
    return {
      'faculty': _selectedFaculty,
      'availability': _selectedAvailability,
      'rating': _selectedRating,
      'sessionRange': _sessionRange,
      'matchRange': _matchRange,
      'skills': _selectedSkills,
      'onlineOnly': _onlineOnly,
      'verifiedOnly': _verifiedOnly,
    };
  }

  void _resetFilters() {
    setState(() {
      _selectedFaculty = 'All';
      _selectedAvailability = 'All';
      _selectedRating = 'All';
      _sessionRange = const RangeValues(0, 50);
      _matchRange = const RangeValues(0, 100);
      _selectedSkills = [];
      _onlineOnly = false;
      _verifiedOnly = false;
    });
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
                          padding: const EdgeInsets.all(20),
                          children: [
                            _buildSection(
                              'Faculty',
                              Icons.school,
                              _buildFacultyFilter(),
                            ),
                            const SizedBox(height: 20),
                            _buildSection(
                              'Availability',
                              Icons.access_time,
                              _buildAvailabilityFilter(),
                            ),
                            const SizedBox(height: 20),
                            _buildSection(
                              'Rating',
                              Icons.star,
                              _buildRatingFilter(),
                            ),
                            const SizedBox(height: 20),
                            _buildSection(
                              'Sessions Completed',
                              Icons.check_circle,
                              _buildSessionRangeFilter(),
                            ),
                            const SizedBox(height: 20),
                            _buildSection(
                              'Match Percentage',
                              Icons.favorite,
                              _buildMatchRangeFilter(),
                            ),
                            const SizedBox(height: 20),
                            _buildSection(
                              'Skills',
                              Icons.auto_awesome,
                              _buildSkillsFilter(),
                            ),
                            const SizedBox(height: 20),
                            _buildSection(
                              'Options',
                              Icons.tune,
                              _buildOptionsFilter(),
                            ),
                            const SizedBox(height: 30),
                            _buildActionButtons(),
                            const SizedBox(height: 20),
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
                Text('Filters',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                SizedBox(height: 2),
                Text('Refine your search',
                    style: TextStyle(fontSize: 13, color: Colors.white70)),
              ],
            ),
          ),
          TextButton(
            onPressed: _resetFilters,
            child: const Text(
              'Reset',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, Widget content) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF667eea), size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _buildFacultyFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _faculties.map((faculty) {
        final isSelected = _selectedFaculty == faculty;
        return FilterChip(
          label: Text(faculty),
          selected: isSelected,
          onSelected: (selected) {
            setState(() => _selectedFaculty = faculty);
          },
          selectedColor: const Color(0xFF667eea).withOpacity(0.2),
          backgroundColor: Colors.white,
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
        );
      }).toList(),
    );
  }

  Widget _buildAvailabilityFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _availabilityOptions.map((option) {
        final isSelected = _selectedAvailability == option;
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (selected) {
            setState(() => _selectedAvailability = option);
          },
          selectedColor: const Color(0xFF667eea).withOpacity(0.2),
          backgroundColor: Colors.white,
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
        );
      }).toList(),
    );
  }

  Widget _buildRatingFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _ratingOptions.map((option) {
        final isSelected = _selectedRating == option;
        return FilterChip(
          label: Text(option),
          selected: isSelected,
          onSelected: (selected) {
            setState(() => _selectedRating = option);
          },
          selectedColor: const Color(0xFF667eea).withOpacity(0.2),
          backgroundColor: Colors.white,
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
        );
      }).toList(),
    );
  }

  Widget _buildSessionRangeFilter() {
    return Column(
      children: [
        RangeSlider(
          values: _sessionRange,
          min: 0,
          max: 50,
          divisions: 10,
          labels: RangeLabels(
            '${_sessionRange.start.round()}',
            '${_sessionRange.end.round()}',
          ),
          onChanged: (values) {
            setState(() => _sessionRange = values);
          },
          activeColor: const Color(0xFF667eea),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_sessionRange.start.round()} sessions',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text('${_sessionRange.end.round()} sessions',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ],
    );
  }

  Widget _buildMatchRangeFilter() {
    return Column(
      children: [
        RangeSlider(
          values: _matchRange,
          min: 0,
          max: 100,
          divisions: 10,
          labels: RangeLabels(
            '${_matchRange.start.round()}%',
            '${_matchRange.end.round()}%',
          ),
          onChanged: (values) {
            setState(() => _matchRange = values);
          },
          activeColor: const Color(0xFF667eea),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${_matchRange.start.round()}%',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            Text('${_matchRange.end.round()}%',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
      ],
    );
  }

  Widget _buildSkillsFilter() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _skills.map((skill) {
        final isSelected = _selectedSkills.contains(skill);
        return FilterChip(
          label: Text(skill),
          selected: isSelected,
          onSelected: (selected) {
            setState(() {
              if (selected) {
                _selectedSkills.add(skill);
              } else {
                _selectedSkills.remove(skill);
              }
            });
          },
          selectedColor: const Color(0xFF667eea).withOpacity(0.2),
          backgroundColor: Colors.white,
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
        );
      }).toList(),
    );
  }

  Widget _buildOptionsFilter() {
    return Column(
      children: [
        SwitchListTile(
          title: const Text('Online Only'),
          subtitle: const Text('Show only users currently online'),
          value: _onlineOnly,
          onChanged: (value) {
            setState(() => _onlineOnly = value);
          },
          activeColor: const Color(0xFF667eea),
        ),
        SwitchListTile(
          title: const Text('Verified Only'),
          subtitle: const Text('Show only verified users'),
          value: _verifiedOnly,
          onChanged: (value) {
            setState(() => _verifiedOnly = value);
          },
          activeColor: const Color(0xFF667eea),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 15),
              side: const BorderSide(color: Color(0xFF667eea)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF667eea),
              ),
            ),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          flex: 2,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pop(context, _getFilters());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Apply Filters',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
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























