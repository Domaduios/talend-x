import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';
import 'services/supabase_db.dart';
import 'dart:math' as math;
import 'utils/app_localizations.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with TickerProviderStateMixin {
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  late TabController _tabController;

  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Unread',
    'Connections',
    'Sessions',
    'Messages',
  ];

  List<Map<String, dynamic>> _allNotifications = [];
  List<Map<String, dynamic>> _filteredNotifications = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    // Initialize particle animations
    _particleControllers = List.generate(
      8,
      (index) => AnimationController(
        vsync: this,
        duration: Duration(
          milliseconds: 5000 + math.Random(index).nextInt(3000),
        ),
      )..repeat(),
    );

    // Initialize fade animation
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));

    _fadeController.forward();

    // Initialize tab controller
    _tabController = TabController(length: 2, vsync: this);

    // Load notifications from Firestore
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final user = SupabaseService.currentUser;
    if (user == null) {
      setState(() {
        _isLoading = false;
        _filteredNotifications = [];
      });
      return;
    }

    try {
      final notificationsQuery = await SupabaseDb.instance
          .collection('notifications')
          .where('userId', isEqualTo: user.id)
          .orderBy('timestamp', descending: true)
          .limit(100)
          .get();

      final List<Map<String, dynamic>> notifications = [];

      for (var doc in notificationsQuery.docs) {
        final data = doc.data();
        final type = data['type'] ?? 'system';
        final title = data['title'] ?? '';
        final message = data['message'] ?? '';
        final isRead = data['isRead'] ?? false;
        final timestamp =
            parseDbDate(data['createdAt']) ?? DateTime.now();

        // Get icon and color based on type
        IconData icon;
        Color color;
        String? userName;
        String? userAvatar;

        switch (type) {
          case 'connection':
            icon = Icons.person_add;
            color = Colors.blue;
            if (data['fromUserId'] != null) {
              final fromUserDoc = await SupabaseDb.instance
                  .collection('users')
                  .doc(data['fromUserId'] as String)
                  .get();
              if (fromUserDoc.exists) {
                final fromUserData = fromUserDoc.data();
                userName = fromUserData?['name'] as String? ?? 'Unknown';
                userAvatar = userName.isNotEmpty ? userName[0] : '?';
              }
            }
            break;
          case 'session':
            icon = Icons.calendar_today;
            color = Colors.orange;
            if (data['sessionId'] != null) {
              final sessionDoc = await SupabaseDb.instance
                  .collection('sessions')
                  .doc(data['sessionId'])
                  .get();
              if (sessionDoc.exists) {
                final sessionData = sessionDoc.data();
                if (sessionData != null) {
                  final teacherId = sessionData['teacherId'] as String?;
                  final learnerId = sessionData['learnerId'] as String?;
                  final partnerId = teacherId == user.id ? learnerId : teacherId;
                  if (partnerId != null && partnerId.isNotEmpty) {
                    final partnerDoc = await SupabaseDb.instance
                        .collection('users')
                        .doc(partnerId)
                        .get();
                    if (partnerDoc.exists) {
                      final partnerData = partnerDoc.data();
                      userName = partnerData?['name'] as String? ?? 'Unknown';
                      userAvatar = userName.isNotEmpty ? userName[0] : '?';
                    }
                  }
                }
              }
            }
            break;
          case 'message':
            icon = Icons.message;
            color = Colors.green;
            if (data['fromUserId'] != null) {
              final fromUserDoc = await SupabaseDb.instance
                  .collection('users')
                  .doc(data['fromUserId'] as String)
                  .get();
              if (fromUserDoc.exists) {
                final fromUserData = fromUserDoc.data();
                userName = fromUserData?['name'] as String? ?? 'Unknown';
                userAvatar = userName.isNotEmpty ? userName[0] : '?';
              }
            }
            break;
          case 'review':
            icon = Icons.star;
            color = Colors.amber;
            if (data['fromUserId'] != null) {
              final fromUserDoc = await SupabaseDb.instance
                  .collection('users')
                  .doc(data['fromUserId'] as String)
                  .get();
              if (fromUserDoc.exists) {
                final fromUserData = fromUserDoc.data();
                userName = fromUserData?['name'] as String? ?? 'Unknown';
                userAvatar = userName.isNotEmpty ? userName[0] : '?';
              }
            }
            break;
          case 'match':
            icon = Icons.favorite;
            color = Colors.red;
            break;
          default:
            icon = Icons.notifications;
            color = Colors.purple;
        }

        notifications.add({
          'id': doc.id,
          'type': type,
          'title': title,
          'message': message,
          'userName': userName,
          'userAvatar': userAvatar,
          'timestamp': timestamp,
          'isRead': isRead,
          'icon': icon,
          'color': color,
        });
      }

      if (mounted) {
        setState(() {
          _allNotifications = notifications;
          _filteredNotifications = List.from(notifications);
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading notifications: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _filteredNotifications = [];
        });
      }
    }
  }

  @override
  void dispose() {
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _applyFilter(String filter) {
    setState(() {
      _selectedFilter = filter;

      if (filter == 'All') {
        _filteredNotifications = List.from(_allNotifications);
      } else if (filter == 'Unread') {
        _filteredNotifications = _allNotifications
            .where((notif) => !notif['isRead'])
            .toList();
      } else {
        final filterType = filter.toLowerCase().replaceAll('s', '');
        _filteredNotifications = _allNotifications
            .where((notif) => (notif['type'] as String).contains(filterType))
            .toList();
      }
    });
  }

  void _markAsRead(String notificationId) {
    setState(() {
      final index = _allNotifications.indexWhere(
        (n) => n['id'] == notificationId,
      );
      if (index != -1) {
        _allNotifications[index]['isRead'] = true;
      }
      _applyFilter(_selectedFilter);
    });
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in _allNotifications) {
        notification['isRead'] = true;
      }
      _applyFilter(_selectedFilter);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Text('All notifications marked as read'),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  Future<void> _acceptConnection(Map<String, dynamic> notification) async {
    try {
      final currentUser = SupabaseService.currentUser;
      if (currentUser == null) return;

      final fromUserId = notification['fromUserId'] as String?;
      if (fromUserId == null) return;

      // Find and update the connection request
      final requestQuery = await SupabaseDb.instance
          .collection('connections')
          .where('userId', isEqualTo: fromUserId)
          .where('connectedUserId', isEqualTo: currentUser.uid)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (requestQuery.docs.isNotEmpty) {
        await SupabaseDb.instance
            .collection('connections')
            .doc(requestQuery.docs.first.id)
            .update({
              'status': 'accepted',
              'acceptedAt': DbFieldValue.serverTimestamp(),
            });

        // Reload notifications to reflect the change
        await _loadNotifications();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 10),
                  Text('Connection request accepted'),
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
        }
      }
    } catch (e) {
      print('Error accepting connection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting connection: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteNotification(String notificationId) {
    setState(() {
      _allNotifications.removeWhere((n) => n['id'] == notificationId);
      _applyFilter(_selectedFilter);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(width: 10),
            Text('Notification deleted'),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(10),
      ),
    );
  }

  void _clearAll() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear All Notifications',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete all notifications?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _allNotifications.clear();
                _filteredNotifications.clear();
              });

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Row(
                    children: const [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 10),
                      Text('All notifications cleared'),
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
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _allNotifications.where((n) => !n['isRead']).length;

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
            ...List.generate(8, (index) => _buildParticle(index)),
            // Main content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    // Header
                    _buildHeader(unreadCount),
                    // Filter Chips
                    _buildFilterChips(),
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
                        child: Column(
                          children: [
                            // Actions Bar
                            _buildActionsBar(),
                            // Notifications List
                            Expanded(
                              child: _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF667eea),
                                      ),
                                    )
                                  : _filteredNotifications.isEmpty
                                  ? _buildEmptyState()
                                  : _buildNotificationsList(),
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
    );
  }

  Widget _buildHeader(int unreadCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 15),
      child: Row(
        children: [
          // Back button
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.notifications,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stay updated with your activity',
                  style: const TextStyle(fontSize: 13, color: Colors.white70),
                ),
              ],
            ),
          ),
          // Unread badge
          if (unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.5),
                    blurRadius: 8,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Text(
                '$unreadCount new',
                style: const TextStyle(
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

  Widget _buildFilterChips() {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _filters.length,
        itemBuilder: (context, index) {
          final filter = _filters[index];
          final isSelected = _selectedFilter == filter;

          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (selected) => _applyFilter(filter),
              backgroundColor: Colors.white.withOpacity(0.2),
              selectedColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF667eea) : Colors.white,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              checkmarkColor: const Color(0xFF667eea),
              side: BorderSide(
                color: isSelected
                    ? Colors.white
                    : Colors.white.withOpacity(0.3),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionsBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 16, color: Colors.black87),
              children: [
                const TextSpan(text: 'Showing '),
                TextSpan(
                  text: '${_filteredNotifications.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF667eea),
                    fontSize: 18,
                  ),
                ),
                const TextSpan(text: ' notifications'),
              ],
            ),
          ),
          Row(
            children: [
              if (_allNotifications.any((n) => !n['isRead']))
                TextButton.icon(
                  onPressed: _markAllAsRead,
                  icon: const Icon(Icons.done_all, size: 18),
                  label: const Text('Mark all read'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF667eea),
                  ),
                ),
              if (_allNotifications.isNotEmpty)
                IconButton(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.delete_sweep),
                  color: Colors.red,
                  tooltip: 'Clear all',
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _filteredNotifications.length,
      itemBuilder: (context, index) {
        final notification = _filteredNotifications[index];
        return _buildNotificationCard(notification);
      },
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] as bool;

    return Dismissible(
      key: Key(notification['id'] as String),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        _deleteNotification(notification['id'] as String);
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(15),
        ),
        alignment: Alignment.centerRight,
        child: const Icon(Icons.delete, color: Colors.white, size: 28),
      ),
      child: InkWell(
        onTap: () {
          if (!isRead) {
            _markAsRead(notification['id'] as String);
          }
          // Navigate to relevant screen based on type
        },
        borderRadius: BorderRadius.circular(15),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: isRead
                ? Colors.white
                : const Color(0xFF667eea).withOpacity(0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: isRead
                  ? Colors.grey.shade200
                  : const Color(0xFF667eea).withOpacity(0.3),
              width: isRead ? 1 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon/Avatar
              Stack(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: (notification['color'] as Color).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: notification.containsKey('userAvatar')
                        ? Center(
                            child: Text(
                              notification['userAvatar'] as String,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: notification['color'] as Color,
                              ),
                            ),
                          )
                        : Icon(
                            notification['icon'] as IconData,
                            color: notification['color'] as Color,
                            size: 24,
                          ),
                  ),
                  if (!isRead)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 15),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification['title'] as String,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: isRead
                                  ? FontWeight.w600
                                  : FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Text(
                          _formatTimestamp(
                            notification['timestamp'] as DateTime,
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: isRead
                                ? Colors.grey.shade600
                                : const Color(0xFF667eea),
                            fontWeight: isRead
                                ? FontWeight.normal
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification['message'] as String,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // Action buttons for connection requests
                    if (notification['type'] == 'connection' && !isRead) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () async {
                                await _acceptConnection(notification);
                                _markAsRead(notification['id'] as String);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF667eea),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              child: const Text(
                                'Accept',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                _deleteNotification(
                                  notification['id'] as String,
                                );
                                // Decline connection logic
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: Colors.grey.shade400),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                              ),
                              child: Text(
                                'Decline',
                                style: TextStyle(
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No notifications',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _selectedFilter == 'All'
                ? 'You\'re all caught up!'
                : 'No $_selectedFilter notifications',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
