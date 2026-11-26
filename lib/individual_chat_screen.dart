import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
import 'user_profile_screen.dart';
import 'utils/app_localizations.dart';

class IndividualChatScreen extends StatefulWidget {
  // Support both old and new parameter styles for compatibility
  final Map<String, dynamic>? userData;
  final String? userName;
  final String? userAvatar;
  final String? userId;
  final bool? isOnline;
  final String? faculty;

  const IndividualChatScreen({
    Key? key,
    this.userData,
    this.userName,
    this.userAvatar,
    this.userId,
    this.isOnline,
    this.faculty,
  }) : super(key: key);

  @override
  State<IndividualChatScreen> createState() => _IndividualChatScreenState();
}

class _IndividualChatScreenState extends State<IndividualChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  final bool _isTyping = false;
  bool _showScrollButton = false;
  bool _isLoading = true;

  // Messages from Firestore
  List<Map<String, dynamic>> _messages = [];
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  StreamSubscription<QuerySnapshot>? _receivedMessagesSubscription;

  // Get user data from either userData map or individual parameters
  Map<String, dynamic> get _userData {
    if (widget.userData != null) {
      return widget.userData!;
    }
    return {
      'name': widget.userName ?? 'Unknown',
      'avatar': widget.userAvatar ?? 'U',
      'id': widget.userId ?? '',
      'isOnline': widget.isOnline ?? false,
      'faculty': widget.faculty ?? '',
    };
  }

  String get _userId =>
      _userData['id'] as String? ?? _userData['userId'] as String? ?? '';
  String get _userName => _userData['name'] as String? ?? 'Unknown';
  String get _userAvatar {
    final avatar = _userData['avatar'] as String?;
    if (avatar != null && avatar.isNotEmpty) return avatar;
    if (_userName.isNotEmpty) return _userName[0].toUpperCase();
    return 'U';
  }

  bool get _isOnline {
    final online = _userData['isOnline'];
    if (online is bool) return online;
    return false;
  }

  @override
  void initState() {
    super.initState();

    // Debug: Print user data
    print('🔍 Chat: Initializing with:');
    print('   - widget.userId: ${widget.userId}');
    print('   - widget.userData: ${widget.userData}');
    print('   - _userId: $_userId');
    print('   - _userName: $_userName');

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _fadeController, curve: Curves.easeIn));
    _fadeController.forward();

    // Load messages from Firestore
    _loadMessages();

    // Scroll listener
    _scrollController.addListener(() {
      if (_scrollController.offset > 200 && !_showScrollButton) {
        setState(() => _showScrollButton = true);
      } else if (_scrollController.offset <= 200 && _showScrollButton) {
        setState(() => _showScrollButton = false);
      }

      // Mark messages as read when scrolling (user is viewing them)
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final currentScroll = _scrollController.position.pixels;
        // If user scrolled near the bottom (within 100px), mark as read
        if ((maxScroll - currentScroll) < 100) {
          _markMessagesAsRead();
        }
      }
    });

    // Auto scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _fadeController.dispose();
    _messagesSubscription?.cancel();
    _receivedMessagesSubscription?.cancel();
    super.dispose();
  }

  void _loadMessages() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('❌ Chat: No current user for loading messages');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    if (_userId.isEmpty) {
      print('❌ Chat: Empty receiver ID. Cannot load messages.');
      print('   - userData: $_userData');
      print('   - widget.userId: ${widget.userId}');
      print('   - widget.userData: ${widget.userData}');
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    print('📥 Chat: Loading messages between ${currentUser.uid} and $_userId');

    // Function to load and combine all messages
    Future<void> loadAllMessages() async {
      try {
        print('📥 Chat: Loading messages for $_userId...');

        // Get sent messages (without orderBy to avoid index requirement)
        QuerySnapshot sentSnapshot;
        try {
          sentSnapshot = await FirebaseFirestore.instance
              .collection('messages')
              .where('senderId', isEqualTo: currentUser.uid)
              .where('receiverId', isEqualTo: _userId)
              .orderBy('createdAt', descending: false)
              .get();
        } catch (e) {
          print('⚠️ Chat: orderBy failed for sent messages, fetching all: $e');
          sentSnapshot = await FirebaseFirestore.instance
              .collection('messages')
              .where('senderId', isEqualTo: currentUser.uid)
              .where('receiverId', isEqualTo: _userId)
              .get();
        }

        // Get received messages (without orderBy to avoid index requirement)
        QuerySnapshot receivedSnapshot;
        try {
          receivedSnapshot = await FirebaseFirestore.instance
              .collection('messages')
              .where('senderId', isEqualTo: _userId)
              .where('receiverId', isEqualTo: currentUser.uid)
              .orderBy('createdAt', descending: false)
              .get();
        } catch (e) {
          print(
            '⚠️ Chat: orderBy failed for received messages, fetching all: $e',
          );
          receivedSnapshot = await FirebaseFirestore.instance
              .collection('messages')
              .where('senderId', isEqualTo: _userId)
              .where('receiverId', isEqualTo: currentUser.uid)
              .get();
        }

        print(
          '📊 Chat: Found ${sentSnapshot.docs.length} sent and ${receivedSnapshot.docs.length} received messages',
        );

        // Combine both
        final allDocs = <QueryDocumentSnapshot>[];
        allDocs.addAll(sentSnapshot.docs);
        allDocs.addAll(receivedSnapshot.docs);

        // Sort by timestamp locally
        allDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>?;
          final bData = b.data() as Map<String, dynamic>?;
          final aTime = aData?['createdAt'] as Timestamp?;
          final bTime = bData?['createdAt'] as Timestamp?;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return aTime.compareTo(bTime);
        });

        print('📊 Chat: Total messages after combining: ${allDocs.length}');

        if (mounted) {
          setState(() {
            _messages = allDocs.map((doc) {
              final data = doc.data() as Map<String, dynamic>? ?? {};
              return {
                'id': doc.id,
                'text': data['content'] ?? '',
                'isMine': data['senderId'] == currentUser.uid,
                'timestamp':
                    (data['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                'isRead': data['read'] ?? false,
              };
            }).toList();
            _isLoading = false;
          });

          print('✅ Chat: Loaded ${_messages.length} messages into UI');

          // Mark messages as read immediately when opening chat
          _markMessagesAsRead();

          // Scroll to bottom after messages load
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom(smooth: false);
            // Mark as read again after scroll to ensure all visible messages are marked
            Future.delayed(const Duration(milliseconds: 500), () {
              _markMessagesAsRead();
            });
          });
        }
      } catch (e) {
        print('❌ Chat: Error loading messages: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }

    // Load initial messages
    loadAllMessages();

    // Listen for sent messages in real-time (without orderBy to avoid index requirement)
    Query sentMessagesQuery;
    try {
      sentMessagesQuery = FirebaseFirestore.instance
          .collection('messages')
          .where('senderId', isEqualTo: currentUser.uid)
          .where('receiverId', isEqualTo: _userId)
          .orderBy('createdAt', descending: false);
    } catch (e) {
      print('⚠️ Chat: Using query without orderBy for sent messages listener');
      sentMessagesQuery = FirebaseFirestore.instance
          .collection('messages')
          .where('senderId', isEqualTo: currentUser.uid)
          .where('receiverId', isEqualTo: _userId);
    }

    _messagesSubscription = sentMessagesQuery.snapshots().listen(
      (snapshot) {
        print(
          '📨 Chat: Sent messages updated (${snapshot.docs.length} messages)',
        );
        loadAllMessages();
      },
      onError: (error) {
        print('❌ Chat: Error in sent messages listener: $error');
        // Retry loading on error
        Future.delayed(const Duration(seconds: 2), () {
          loadAllMessages();
        });
      },
    );

    // Listen for received messages in real-time (without orderBy to avoid index requirement)
    Query receivedMessagesQuery;
    try {
      receivedMessagesQuery = FirebaseFirestore.instance
          .collection('messages')
          .where('senderId', isEqualTo: _userId)
          .where('receiverId', isEqualTo: currentUser.uid)
          .orderBy('createdAt', descending: false);
    } catch (e) {
      print(
        '⚠️ Chat: Using query without orderBy for received messages listener',
      );
      receivedMessagesQuery = FirebaseFirestore.instance
          .collection('messages')
          .where('senderId', isEqualTo: _userId)
          .where('receiverId', isEqualTo: currentUser.uid);
    }

    _receivedMessagesSubscription = receivedMessagesQuery.snapshots().listen(
      (snapshot) {
        print(
          '📬 Chat: Received messages updated (${snapshot.docs.length} messages)',
        );
        loadAllMessages();
      },
      onError: (error) {
        print('❌ Chat: Error in received messages listener: $error');
        // Retry loading on error
        Future.delayed(const Duration(seconds: 2), () {
          loadAllMessages();
        });
      },
    );
  }

  Future<void> _markMessagesAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _userId.isEmpty) {
      print(
        '⚠️ Chat: Cannot mark as read - currentUser: ${currentUser?.uid}, _userId: $_userId',
      );
      return;
    }

    try {
      print('📖 Chat: Marking messages as read from $_userId...');

      // Get all unread messages from this user
      final unreadMessages = await FirebaseFirestore.instance
          .collection('messages')
          .where('receiverId', isEqualTo: currentUser.uid)
          .where('senderId', isEqualTo: _userId)
          .where('read', isEqualTo: false)
          .get();

      print('📖 Chat: Found ${unreadMessages.docs.length} unread messages');

      if (unreadMessages.docs.isNotEmpty) {
        // Use batch write for efficiency (max 500 operations per batch)
        final batch = FirebaseFirestore.instance.batch();
        int batchCount = 0;

        for (final doc in unreadMessages.docs) {
          batch.update(doc.reference, {'read': true});
          batchCount++;

          // Firestore batch limit is 500, so commit and create new batch if needed
          if (batchCount >= 500) {
            await batch.commit();
            batchCount = 0;
          }
        }

        // Commit remaining updates
        if (batchCount > 0) {
          await batch.commit();
        }

        print('✅ Chat: Marked ${unreadMessages.docs.length} messages as read');

        // Update local state
        if (mounted) {
          setState(() {
            for (var message in _messages) {
              if (!(message['isMine'] as bool) &&
                  !(message['isRead'] as bool)) {
                message['isRead'] = true;
              }
            }
          });
        }
      } else {
        print('ℹ️ Chat: No unread messages to mark');
      }
    } catch (e) {
      print('❌ Chat: Error marking messages as read: $e');
      print('   - Error type: ${e.runtimeType}');
    }
  }

  void _scrollToBottom({bool smooth = true}) {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (smooth) {
        _scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(maxScroll);
      }
    } else {
      // If scroll controller is not ready, try again after a delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients && mounted) {
          _scrollToBottom(smooth: smooth);
        }
      });
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      print('❌ Chat: No current user');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in to send messages'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    if (_userId.isEmpty) {
      print(
        '❌ Chat: Empty receiver ID. _userId: "$_userId", userData: $_userData',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error: Invalid user ID'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;

    // Clear text field immediately for better UX
    _messageController.clear();

    print('📤 Chat: Sending message to $_userId: "$messageText"');

    try {
      // Save message to Firestore
      final messageData = {
        'senderId': currentUser.uid,
        'receiverId': _userId,
        'content': messageText,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      print('📤 Chat: Attempting to save message:');
      print('   - senderId: ${currentUser.uid}');
      print('   - receiverId: $_userId');
      print('   - content: "$messageText"');
      print('   - messageData: $messageData');

      // Add message optimistically to UI immediately (before Firestore)
      final tempMessageId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
      if (mounted) {
        setState(() {
          _messages.add({
            'id': tempMessageId,
            'text': messageText,
            'isMine': true,
            'timestamp': DateTime.now(),
            'isRead': false,
          });
        });

        // Scroll to bottom immediately
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom(smooth: true);
        });
      }

      final messageRef = await FirebaseFirestore.instance
          .collection('messages')
          .add(messageData);

      print('✅ Chat: Message sent successfully. ID: ${messageRef.id}');

      // Verify the message was saved
      final savedMessage = await messageRef.get();
      if (savedMessage.exists) {
        print('✅ Chat: Message verified in Firestore');
        final savedData = savedMessage.data();
        print('   - Saved data: $savedData');

        // Update the temporary message with the real ID and timestamp
        if (mounted) {
          setState(() {
            final tempIndex = _messages.indexWhere(
              (m) => m['id'] == tempMessageId,
            );
            if (tempIndex != -1) {
              final savedTimestamp =
                  (savedData?['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime.now();
              _messages[tempIndex] = {
                'id': messageRef.id,
                'text': messageText,
                'isMine': true,
                'timestamp': savedTimestamp,
                'isRead': false,
              };
            }
          });
        }
      } else {
        print('❌ Chat: Message not found in Firestore after saving!');
        // Remove the optimistic message if it wasn't saved
        if (mounted) {
          setState(() {
            _messages.removeWhere((m) => m['id'] == tempMessageId);
          });
        }
      }

      // The listener will update with the actual server timestamp later
    } catch (e) {
      print('❌ Chat: Error sending message: $e');
      print('   - Error type: ${e.runtimeType}');
      print('   - Current User ID: ${currentUser.uid}');
      print('   - Receiver ID: $_userId');
      print('   - Message: "$messageText"');

      // Check if it's a permission error
      final errorString = e.toString().toLowerCase();
      final isPermissionError =
          errorString.contains('permission-denied') ||
          errorString.contains('permission_denied') ||
          errorString.contains('permission denied');

      // Remove optimistic message on error
      if (mounted) {
        setState(() {
          _messages.removeWhere((m) => m['id'].toString().startsWith('temp_'));
        });
      }

      if (isPermissionError) {
        print(
          '❌ Chat: PERMISSION DENIED - Firestore rules may not be published!',
        );
        // Restore message text on error
        _messageController.text = messageText;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'خطأ في الصلاحيات: يرجى التحقق من نشر Firestore Rules في Firebase Console',
                      maxLines: 3,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
              duration: const Duration(seconds: 6),
            ),
          );
        }
      } else {
        // Restore message text on error
        _messageController.text = messageText;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Error sending message: ${e.toString()}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF667eea)),
                  )
                : _messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Start the conversation!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : FadeTransition(
                    opacity: _fadeAnimation,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(15),
                      itemCount: _messages.length + (_isTyping ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_isTyping && index == _messages.length) {
                          return _buildTypingIndicator();
                        }
                        return _buildMessageBubble(_messages[index]);
                      },
                    ),
                  ),
          ),
          // Message input
          _buildMessageInput(),
        ],
      ),
      floatingActionButton: _showScrollButton
          ? FloatingActionButton.small(
              onPressed: _scrollToBottom,
              backgroundColor: const Color(0xFF667eea),
              child: const Icon(Icons.arrow_downward, size: 20),
            )
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF667eea),
      elevation: 0,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_new, size: 20),
      ),
      title: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => UserProfileScreen(userId: _userId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Center(
                    child: Text(
                      _userAvatar,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Online indicator
                if (_isOnline)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            // Name and status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _isOnline ? 'Online' : 'Last seen recently',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Video call
        IconButton(
          onPressed: () {
            // Start video call
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video call feature coming soon'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          icon: const Icon(Icons.videocam, size: 26),
        ),
        // Voice call
        IconButton(
          onPressed: () {
            // Start voice call
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Voice call feature coming soon'),
                duration: Duration(seconds: 1),
              ),
            );
          },
          icon: const Icon(Icons.call, size: 22),
        ),
        // More options
        PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view_profile',
              child: Row(
                children: [
                  Icon(Icons.person, size: 20),
                  SizedBox(width: 10),
                  Text('View Profile'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'schedule',
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 20),
                  SizedBox(width: 10),
                  Text('Schedule Session'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'clear',
              child: Row(
                children: [
                  Icon(Icons.delete_outline, size: 20),
                  SizedBox(width: 10),
                  Text('Clear Chat'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'block',
              child: Row(
                children: [
                  Icon(Icons.block, size: 20, color: Colors.red),
                  SizedBox(width: 10),
                  Text('Block User', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          onSelected: (value) {
            switch (value) {
              case 'view_profile':
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfileScreen(userId: _userId),
                  ),
                );
                break;
              case 'schedule':
                // Open schedule dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Schedule session feature coming soon'),
                    duration: Duration(seconds: 1),
                  ),
                );
                break;
              case 'clear':
                _confirmClearChat();
                break;
              case 'block':
                _confirmBlockUser();
                break;
            }
          },
        ),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final isMine = message['isMine'] as bool;
    final timestamp = message['timestamp'] as DateTime;
    final isRead = message['isRead'] as bool? ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isMine
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for received messages
          if (!isMine) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _userAvatar,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          // Message bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: isMine
                    ? const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      )
                    : null,
                color: isMine ? null : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isMine ? 20 : 5),
                  bottomRight: Radius.circular(isMine ? 5 : 20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Message text
                  Text(
                    message['text'] as String,
                    style: TextStyle(
                      fontSize: 15,
                      color: isMine ? Colors.white : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Timestamp and read status
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(timestamp),
                        style: TextStyle(
                          fontSize: 11,
                          color: isMine ? Colors.white70 : Colors.grey,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 5),
                        Icon(
                          isRead ? Icons.done_all : Icons.done,
                          size: 16,
                          color: isRead
                              ? Colors.lightBlueAccent
                              : Colors.white70,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Spacing for sent messages
          if (isMine) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                _userAvatar,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTypingDot(0),
                const SizedBox(width: 4),
                _buildTypingDot(1),
                const SizedBox(width: 4),
                _buildTypingDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypingDot(int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      builder: (context, value, child) {
        final delay = index * 0.2;
        final animValue = ((value - delay).clamp(0.0, 1.0));
        final scale = 0.5 + (math.sin(animValue * math.pi) * 0.5);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
      onEnd: () {
        // Repeat animation
        if (mounted && _isTyping) {
          setState(() {});
        }
      },
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attachment button
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  _showAttachmentOptions();
                },
                icon: Icon(Icons.add, color: Colors.grey.shade700),
              ),
            ),
            const SizedBox(width: 10),
            // Text field
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        focusNode: _focusNode,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        enableInteractiveSelection: true,
                        enableSuggestions: true,
                        autocorrect: true,
                        // Enable multi-language input - no restrictions
                        inputFormatters: [],
                        decoration: InputDecoration(
                          hintText: context.l10n.typeMessage,
                          border: InputBorder.none,
                        ),
                        onChanged: (text) {
                          setState(() {});
                        },
                        onSubmitted: (text) {
                          if (text.trim().isNotEmpty) {
                            _sendMessage();
                          }
                        },
                      ),
                    ),
                    // Emoji button
                    IconButton(
                      onPressed: () {
                        // Show emoji picker
                        HapticFeedback.lightImpact();
                      },
                      icon: Icon(
                        Icons.emoji_emotions_outlined,
                        color: Colors.grey.shade600,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Send button
            Container(
              decoration: BoxDecoration(
                gradient: _messageController.text.trim().isEmpty
                    ? null
                    : const LinearGradient(
                        colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                      ),
                color: _messageController.text.trim().isEmpty
                    ? Colors.grey.shade300
                    : null,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: _messageController.text.trim().isEmpty
                    ? null
                    : _sendMessage,
                icon: const Icon(Icons.send, color: Colors.white, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'Send Attachment',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            // Options
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(
                  Icons.image,
                  'Photo',
                  Colors.purple,
                  () {},
                ),
                _buildAttachmentOption(
                  Icons.videocam,
                  'Video',
                  Colors.red,
                  () {},
                ),
                _buildAttachmentOption(
                  Icons.insert_drive_file,
                  'File',
                  Colors.blue,
                  () {},
                ),
                _buildAttachmentOption(
                  Icons.location_on,
                  'Location',
                  Colors.green,
                  () {},
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearChat() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Clear Chat',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete all messages? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Store context before closing dialog
              final dialogContext = context;
              Navigator.pop(dialogContext);

              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser == null) {
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Error: Not authenticated'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              try {
                // Show loading
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10),
                          Text('Deleting messages...'),
                        ],
                      ),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }

                // Get all messages between current user and this user
                final sentMessages = await FirebaseFirestore.instance
                    .collection('messages')
                    .where('senderId', isEqualTo: currentUser.uid)
                    .where('receiverId', isEqualTo: _userId)
                    .get();

                final receivedMessages = await FirebaseFirestore.instance
                    .collection('messages')
                    .where('senderId', isEqualTo: _userId)
                    .where('receiverId', isEqualTo: currentUser.uid)
                    .get();

                print(
                  '🗑️ Chat: Found ${sentMessages.docs.length} sent and ${receivedMessages.docs.length} received messages to delete',
                );

                // Delete all messages using batch
                final batch = FirebaseFirestore.instance.batch();
                int batchCount = 0;

                for (var doc in sentMessages.docs) {
                  batch.delete(doc.reference);
                  batchCount++;
                  if (batchCount >= 500) {
                    await batch.commit();
                    batchCount = 0;
                  }
                }

                for (var doc in receivedMessages.docs) {
                  batch.delete(doc.reference);
                  batchCount++;
                  if (batchCount >= 500) {
                    await batch.commit();
                    batchCount = 0;
                  }
                }

                // Commit remaining deletes
                if (batchCount > 0) {
                  await batch.commit();
                }

                print(
                  '✅ Chat: Cleared ${sentMessages.docs.length + receivedMessages.docs.length} messages',
                );

                // Clear local state
                if (mounted) {
                  setState(() {
                    _messages.clear();
                  });

                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('Chat cleared successfully'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                print('❌ Chat: Error clearing chat: $e');
                print('   - Error type: ${e.runtimeType}');
                if (mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Error clearing chat: ${e.toString()}'),
                      backgroundColor: Colors.red,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmBlockUser() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Block User',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to block $_userName? You won\'t be able to message each other.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);

              final currentUser = FirebaseAuth.instance.currentUser;
              if (currentUser == null) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error: Not authenticated'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              if (_userId.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Error: Invalid user ID'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
                return;
              }

              try {
                print('🚫 Chat: Blocking user $_userId...');

                // Check if already blocked
                final existingBlock = await FirebaseFirestore.instance
                    .collection('blocked_users')
                    .where('userId', isEqualTo: currentUser.uid)
                    .where('blockedUserId', isEqualTo: _userId)
                    .limit(1)
                    .get();

                if (existingBlock.docs.isNotEmpty) {
                  print('ℹ️ Chat: User already blocked');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('$_userName is already blocked'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  }
                  return;
                }

                // Block user in Firestore
                await FirebaseFirestore.instance
                    .collection('blocked_users')
                    .add({
                      'userId': currentUser.uid,
                      'blockedUserId': _userId,
                      'blockedUserName': _userName,
                      'createdAt': FieldValue.serverTimestamp(),
                    });

                print('✅ Chat: User $_userId blocked successfully');

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$_userName has been blocked'),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              } catch (e) {
                print('❌ Chat: Error blocking user: $e');
                print('   - Error type: ${e.runtimeType}');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error blocking user: ${e.toString()}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays == 0) {
      // Today - show time
      final hour = dateTime.hour.toString().padLeft(2, '0');
      final minute = dateTime.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    }
  }
}
