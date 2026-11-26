import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'dart:math' as math;
import 'individual_chat_screen.dart';
import 'browse_screen.dart';
import 'utils/app_localizations.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({Key? key}) : super(key: key);

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  List<AnimationController>? _particleControllers;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  List<Map<String, dynamic>> _allChats = [];
  List<Map<String, dynamic>> _filteredChats = [];
  StreamSubscription<QuerySnapshot>? _messagesSubscription;
  bool _isLoading = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    print('🚀 ChatList: Initializing...');
    _loadChats();

    // Initialize particle animations
    _particleControllers = List.generate(
      10,
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounce?.cancel();
    _messagesSubscription?.cancel();
    _connectionsSubscription?.cancel();
    _particleControllers?.forEach((controller) => controller.dispose());
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadChats() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      return;
    }

    print('🔄 ChatList: Loading chats...');

    try {
      // Get all unique chat partners from messages
      print('🔍 ChatList: Fetching sent messages...');
      QuerySnapshot messagesQuery;
      try {
        messagesQuery = await FirebaseFirestore.instance
            .collection('messages')
            .where('senderId', isEqualTo: currentUser.uid)
            .get();
      } catch (e) {
        print('❌ ChatList: Error fetching sent messages: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      print('🔍 ChatList: Fetching received messages...');
      QuerySnapshot receivedMessagesQuery;
      try {
        receivedMessagesQuery = await FirebaseFirestore.instance
            .collection('messages')
            .where('receiverId', isEqualTo: currentUser.uid)
            .get();
      } catch (e) {
        print('❌ ChatList: Error fetching received messages: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      print(
        '📊 ChatList: Found ${messagesQuery.docs.length} sent messages and ${receivedMessagesQuery.docs.length} received messages',
      );

      // Get unique user IDs from messages - normalize to prevent duplicates
      final Set<String> partnerIds = {};
      final Map<String, String> normalizedToOriginal =
          {}; // Track original case

      for (var doc in messagesQuery.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          final receiverId = data['receiverId'] as String?;
          if (receiverId != null && receiverId.isNotEmpty) {
            final normalized = receiverId.trim().toLowerCase();
            if (!partnerIds.contains(normalized)) {
              partnerIds.add(normalized);
              normalizedToOriginal[normalized] = receiverId.trim();
              print('   ✓ Added partner from sent message: $receiverId');
            } else {
              print('   ⊗ Duplicate partner skipped (sent): $receiverId');
            }
          }
        }
      }

      for (var doc in receivedMessagesQuery.docs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data != null) {
          final senderId = data['senderId'] as String?;
          if (senderId != null && senderId.isNotEmpty) {
            final normalized = senderId.trim().toLowerCase();
            if (!partnerIds.contains(normalized)) {
              partnerIds.add(normalized);
              normalizedToOriginal[normalized] = senderId.trim();
              print('   ✓ Added partner from received message: $senderId');
            } else {
              print('   ⊗ Duplicate partner skipped (received): $senderId');
            }
          }
        }
      }

      // Also get accepted connections (even if no messages yet)
      final acceptedConnectionsQuery = await FirebaseFirestore.instance
          .collection('connections')
          .where('status', isEqualTo: 'accepted')
          .where(
            Filter.or(
              Filter('userId', isEqualTo: currentUser.uid),
              Filter('connectedUserId', isEqualTo: currentUser.uid),
            ),
          )
          .get();

      // Add connection partners to the set
      for (var doc in acceptedConnectionsQuery.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;
        final connectedUserId = data['connectedUserId'] as String?;

        if (userId == currentUser.uid && connectedUserId != null) {
          final normalized = connectedUserId.trim().toLowerCase();
          if (!partnerIds.contains(normalized)) {
            partnerIds.add(normalized);
            normalizedToOriginal[normalized] = connectedUserId.trim();
            print('   ✓ Added partner from connection: $connectedUserId');
          } else {
            print(
              '   ⊗ Duplicate partner skipped (connection): $connectedUserId',
            );
          }
        } else if (connectedUserId == currentUser.uid && userId != null) {
          final normalized = userId.trim().toLowerCase();
          if (!partnerIds.contains(normalized)) {
            partnerIds.add(normalized);
            normalizedToOriginal[normalized] = userId.trim();
            print('   ✓ Added partner from connection: $userId');
          } else {
            print('   ⊗ Duplicate partner skipped (connection): $userId');
          }
        }
      }

      print(
        '📊 ChatList: Found ${partnerIds.length} unique chat partners (${messagesQuery.docs.length + receivedMessagesQuery.docs.length} messages, ${acceptedConnectionsQuery.docs.length} connections)',
      );

      // Load chat data for each partner - use original case from normalizedToOriginal
      final List<Map<String, dynamic>> chats = [];
      print('📋 ChatList: Processing ${partnerIds.length} unique partner IDs');

      for (final normalizedPartnerId in partnerIds) {
        // Get original case userId
        final partnerId =
            normalizedToOriginal[normalizedPartnerId] ?? normalizedPartnerId;
        print(
          '   🔍 Processing partner: $partnerId (normalized: $normalizedPartnerId)',
        );

        try {
          // Get user data - try both normalized and original
          DocumentSnapshot? userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(partnerId)
              .get();

          // If not found, try with normalized ID
          if (!userDoc.exists && partnerId != normalizedPartnerId) {
            userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(normalizedPartnerId)
                .get();
          }

          if (!userDoc.exists || userDoc.data() == null) {
            print('   ⚠️ User document not found for: $partnerId');
            continue;
          }

          final userData = userDoc.data() as Map<String, dynamic>?;
          if (userData == null) {
            print('   ⚠️ User data is null for: $partnerId');
            continue;
          }

          // Get last message - use two separate queries to avoid index requirement
          // Try sent messages first (without orderBy to avoid index requirement)
          QuerySnapshot sentLastMessage;
          try {
            sentLastMessage = await FirebaseFirestore.instance
                .collection('messages')
                .where('senderId', isEqualTo: currentUser.uid)
                .where('receiverId', isEqualTo: partnerId)
                .orderBy('createdAt', descending: true)
                .limit(1)
                .get();
          } catch (e) {
            // If orderBy fails (no index), get all and sort locally
            print(
              '⚠️ ChatList: orderBy failed for sent messages, fetching all: $e',
            );
            sentLastMessage = await FirebaseFirestore.instance
                .collection('messages')
                .where('senderId', isEqualTo: currentUser.uid)
                .where('receiverId', isEqualTo: partnerId)
                .get();
            // Sort locally
            sentLastMessage.docs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>?;
              final bData = b.data() as Map<String, dynamic>?;
              final aTime =
                  (aData?['createdAt'] as Timestamp?) ?? Timestamp.now();
              final bTime =
                  (bData?['createdAt'] as Timestamp?) ?? Timestamp.now();
              return bTime.compareTo(aTime);
            });
          }

          // Try received messages (without orderBy to avoid index requirement)
          QuerySnapshot receivedLastMessage;
          try {
            receivedLastMessage = await FirebaseFirestore.instance
                .collection('messages')
                .where('senderId', isEqualTo: partnerId)
                .where('receiverId', isEqualTo: currentUser.uid)
                .orderBy('createdAt', descending: true)
                .limit(1)
                .get();
          } catch (e) {
            // If orderBy fails (no index), get all and sort locally
            print(
              '⚠️ ChatList: orderBy failed for received messages, fetching all: $e',
            );
            receivedLastMessage = await FirebaseFirestore.instance
                .collection('messages')
                .where('senderId', isEqualTo: partnerId)
                .where('receiverId', isEqualTo: currentUser.uid)
                .get();
            // Sort locally
            receivedLastMessage.docs.sort((a, b) {
              final aData = a.data() as Map<String, dynamic>?;
              final bData = b.data() as Map<String, dynamic>?;
              final aTime =
                  (aData?['createdAt'] as Timestamp?) ?? Timestamp.now();
              final bTime =
                  (bData?['createdAt'] as Timestamp?) ?? Timestamp.now();
              return bTime.compareTo(aTime);
            });
          }

          // Get the most recent message
          QueryDocumentSnapshot? lastMessageDoc;
          Timestamp? lastMessageTime;

          if (sentLastMessage.docs.isNotEmpty) {
            final sentData =
                sentLastMessage.docs.first.data() as Map<String, dynamic>?;
            if (sentData != null) {
              final sentTime = sentData['createdAt'] as Timestamp?;
              if (sentTime != null) {
                lastMessageDoc = sentLastMessage.docs.first;
                lastMessageTime = sentTime;
              }
            }
          }

          if (receivedLastMessage.docs.isNotEmpty) {
            final receivedData =
                receivedLastMessage.docs.first.data() as Map<String, dynamic>?;
            if (receivedData != null) {
              final receivedTime = receivedData['createdAt'] as Timestamp?;
              if (receivedTime != null) {
                if (lastMessageTime == null ||
                    receivedTime.compareTo(lastMessageTime) > 0) {
                  lastMessageDoc = receivedLastMessage.docs.first;
                  lastMessageTime = receivedTime;
                }
              }
            }
          }

          // Get unread count
          final unreadQuery = await FirebaseFirestore.instance
              .collection('messages')
              .where('receiverId', isEqualTo: currentUser.uid)
              .where('senderId', isEqualTo: partnerId)
              .where('read', isEqualTo: false)
              .get();

          print(
            '📊 ChatList: Partner $partnerId - ${unreadQuery.docs.length} unread messages',
          );

          // If no messages, use connection accepted date as timestamp
          DateTime chatTimestamp;
          String lastMessageText;

          if (lastMessageDoc != null && lastMessageTime != null) {
            // Use the timestamp we already found - ensure it's converted properly
            final timestampDate = lastMessageTime.toDate();
            chatTimestamp = timestampDate;
            final lastMessageData =
                lastMessageDoc.data() as Map<String, dynamic>?;
            lastMessageText = lastMessageData?['content'] as String? ?? '';

            final now = DateTime.now();
            final diff = now.difference(timestampDate);

            print(
              '📨 ChatList: Last message with $partnerId: "$lastMessageText"',
            );
            print('   - Message Timestamp: $timestampDate');
            print('   - Current Time: $now');
            print('   - Difference: ${diff.inHours}h ${diff.inMinutes % 60}m');
            print('   - Will display as: ${_formatTimestamp(timestampDate)}');
          } else {
            // No messages yet - get connection accepted date
            final connectionQuery = await FirebaseFirestore.instance
                .collection('connections')
                .where('status', isEqualTo: 'accepted')
                .where(
                  Filter.or(
                    Filter.and(
                      Filter('userId', isEqualTo: currentUser.uid),
                      Filter('connectedUserId', isEqualTo: partnerId),
                    ),
                    Filter.and(
                      Filter('userId', isEqualTo: partnerId),
                      Filter('connectedUserId', isEqualTo: currentUser.uid),
                    ),
                  ),
                )
                .limit(1)
                .get();

            if (connectionQuery.docs.isNotEmpty) {
              final connectionData =
                  connectionQuery.docs.first.data() as Map<String, dynamic>?;
              if (connectionData != null) {
                final acceptedAt = connectionData['acceptedAt'] as Timestamp?;
                final createdAt = connectionData['createdAt'] as Timestamp?;

                if (acceptedAt != null) {
                  chatTimestamp = acceptedAt.toDate();
                } else if (createdAt != null) {
                  chatTimestamp = createdAt.toDate();
                } else {
                  // Fallback: use a date far in the past so it doesn't show as "now"
                  chatTimestamp = DateTime.now().subtract(
                    const Duration(days: 365),
                  );
                }
                lastMessageText = 'Connection accepted - Start chatting!';
                print(
                  '📨 ChatList: Connection with $partnerId accepted at $chatTimestamp',
                );
              } else {
                // No connection data - use a date far in the past
                chatTimestamp = DateTime.now().subtract(
                  const Duration(days: 365),
                );
                lastMessageText = '';
              }
            } else {
              // No connection either - use a date far in the past
              chatTimestamp = DateTime.now().subtract(
                const Duration(days: 365),
              );
              lastMessageText = '';
            }
          }

          chats.add({
            'id': partnerId,
            'userId': partnerId,
            'userName': userData['name'] ?? 'Unknown',
            'userAvatar': (userData['name'] ?? 'U')[0].toUpperCase(),
            'faculty': userData['faculty'] ?? '',
            'lastMessage': lastMessageText,
            'timestamp': chatTimestamp,
            'unreadCount': unreadQuery.docs.length,
            'isOnline': false, // TODO: Implement online status
            'isTyping': false,
          });
        } catch (e) {
          print('Error loading chat for $partnerId: $e');
        }
      }

      // Remove duplicates based on userId - use case-insensitive comparison
      final Map<String, Map<String, dynamic>> uniqueChats = {};
      print('🔍 ChatList: Checking for duplicates in ${chats.length} chats...');

      for (var chat in chats) {
        final userId =
            (chat['userId'] as String? ?? chat['id'] as String? ?? '').trim();
        if (userId.isEmpty) {
          print('   ⚠️ Skipping chat with empty userId');
          continue;
        }

        // Normalize userId for comparison (lowercase and trim)
        final normalizedUserId = userId.toLowerCase().trim();

        // If chat already exists, keep the one with the most recent timestamp
        if (!uniqueChats.containsKey(normalizedUserId)) {
          uniqueChats[normalizedUserId] = chat;
          print(
            '   ✓ Added chat for user: $userId (normalized: $normalizedUserId)',
          );
        } else {
          final existingChat = uniqueChats[normalizedUserId]!;
          final existingTimestamp = existingChat['timestamp'] as DateTime;
          final newTimestamp = chat['timestamp'] as DateTime;
          final existingUserName =
              existingChat['userName'] as String? ?? 'Unknown';
          final newUserName = chat['userName'] as String? ?? 'Unknown';

          print('   ⚠️ Duplicate found for user: $userId');
          print('      - Existing: $existingUserName ($existingTimestamp)');
          print('      - New: $newUserName ($newTimestamp)');

          if (newTimestamp.isAfter(existingTimestamp)) {
            print('      ↻ Keeping NEW chat (newer timestamp)');
            uniqueChats[normalizedUserId] = chat;
          } else {
            print('      ⊗ Keeping EXISTING chat (newer timestamp)');
          }
        }
      }

      print(
        '📊 ChatList: Deduplication complete: ${chats.length} → ${uniqueChats.length} unique chats',
      );

      // Final verification - check for any remaining duplicates by userName
      final Map<String, List<Map<String, dynamic>>> userNameToChats = {};
      for (var chat in uniqueChats.values) {
        final chatMap = chat;
        final userName = (chatMap['userName'] as String? ?? '')
            .toLowerCase()
            .trim();
        if (userName.isNotEmpty) {
          if (!userNameToChats.containsKey(userName)) {
            userNameToChats[userName] = [];
          }
          userNameToChats[userName]!.add(chatMap);
        }
      }

      // Remove duplicates by userName - keep only the most recent one
      final Map<String, Map<String, dynamic>> finalUniqueChats = {};
      for (var entry in userNameToChats.entries) {
        if (entry.value.length > 1) {
          print(
            '   ⚠️ WARNING: User "${entry.key}" appears ${entry.value.length} times!',
          );
          // Keep the one with the most recent timestamp
          entry.value.sort((a, b) {
            final aTime = a['timestamp'] as DateTime;
            final bTime = b['timestamp'] as DateTime;
            return bTime.compareTo(aTime);
          });
          final keptChat = entry.value.first;
          final normalizedId =
              (keptChat['userId'] as String? ?? keptChat['id'] as String? ?? '')
                  .toLowerCase()
                  .trim();
          finalUniqueChats[normalizedId] = keptChat;
          print(
            '      ✓ Kept chat with ID: ${keptChat['userId']} (timestamp: ${keptChat['timestamp']})',
          );
          for (int i = 1; i < entry.value.length; i++) {
            print(
              '      ⊗ Removed duplicate with ID: ${entry.value[i]['userId']}',
            );
          }
        } else {
          final chat = entry.value.first;
          final normalizedId =
              (chat['userId'] as String? ?? chat['id'] as String? ?? '')
                  .toLowerCase()
                  .trim();
          finalUniqueChats[normalizedId] = chat;
        }
      }

      // Use finalUniqueChats if we found duplicates by name, otherwise use uniqueChats
      final List<Map<String, dynamic>> finalChatsList;
      if (finalUniqueChats.length < uniqueChats.length) {
        print(
          '📊 ChatList: Removed ${uniqueChats.length - finalUniqueChats.length} duplicates by userName',
        );
        finalChatsList = finalUniqueChats.values.toList();
      } else {
        finalChatsList = uniqueChats.values.toList();
      }

      // Sort by timestamp
      finalChatsList.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );

      print(
        '✅ ChatList: Loaded ${finalChatsList.length} unique chats (${chats.length} before deduplication)',
      );
      if (finalChatsList.isNotEmpty) {
        print(
          '📋 ChatList: First chat: ${finalChatsList.first['userName']} - "${finalChatsList.first['lastMessage']}"',
        );
      }

      if (mounted) {
        setState(() {
          _allChats = finalChatsList;
          _filteredChats = List.from(finalChatsList);
          _isLoading = false;
        });
        print('✅ ChatList: State updated with ${_allChats.length} chats');
      }

      // Always set up listeners (they will cancel existing ones)
      _setupMessagesListener();
    } catch (e) {
      print('❌ ChatList: Error loading chats: $e');
      print('   - Error type: ${e.runtimeType}');

      // Check if it's a permission error
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('permission-denied') ||
          errorString.contains('permission_denied') ||
          errorString.contains('permission denied')) {
        print(
          '❌ ChatList: PERMISSION DENIED - Firestore rules may not be published!',
        );
      }

      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  StreamSubscription<QuerySnapshot>? _connectionsSubscription;

  void _setupMessagesListener() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    print('🔔 ChatList: Setting up message listeners');

    // Cancel existing subscriptions
    _messagesSubscription?.cancel();
    _connectionsSubscription?.cancel();

    // Listen for sent messages
    final sentMessagesQuery = FirebaseFirestore.instance
        .collection('messages')
        .where('senderId', isEqualTo: currentUser.uid);

    _messagesSubscription = sentMessagesQuery.snapshots().listen(
      (snapshot) {
        print(
          '📨 ChatList: Sent messages updated (${snapshot.docs.length} total)',
        );
        if (snapshot.docChanges.isNotEmpty) {
          print('📨 ChatList: ${snapshot.docChanges.length} changes detected');
          for (var change in snapshot.docChanges) {
            print(
              '📨 ChatList: Change type: ${change.type.name}, docId: ${change.doc.id}',
            );
            final data = change.doc.data() as Map<String, dynamic>;
            print('   - senderId: ${data['senderId']}');
            print('   - receiverId: ${data['receiverId']}');
            print('   - content: ${data['content']}');
          }
          // Always reload when there are changes (even if it's just metadata)
          print('🔄 ChatList: Reloading chats due to sent message changes...');
          _loadChats();
        } else {
          // Even if no changes, reload periodically to catch any missed updates
          print(
            '📨 ChatList: No changes detected, but checking for updates...',
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            _loadChats();
          });
        }
      },
      onError: (error) {
        print('❌ ChatList: Error in sent messages listener: $error');
        // Retry loading on error
        Future.delayed(const Duration(seconds: 2), () {
          _loadChats();
        });
      },
    );

    // Also listen for received messages
    final receivedMessagesQuery = FirebaseFirestore.instance
        .collection('messages')
        .where('receiverId', isEqualTo: currentUser.uid);

    // Use a separate subscription for received messages
    receivedMessagesQuery.snapshots().listen(
      (snapshot) {
        print(
          '📬 ChatList: Received messages updated (${snapshot.docs.length} total)',
        );
        if (snapshot.docChanges.isNotEmpty) {
          print(
            '📬 ChatList: ${snapshot.docChanges.length} received message changes detected',
          );
          for (var change in snapshot.docChanges) {
            print(
              '📬 ChatList: Change type: ${change.type.name}, docId: ${change.doc.id}',
            );
          }
          // Always reload when there are changes
          print(
            '🔄 ChatList: Reloading chats due to received message changes...',
          );
          _loadChats();
        } else {
          // Even if no changes, reload periodically to catch any missed updates
          print(
            '📬 ChatList: No changes detected, but checking for updates...',
          );
          Future.delayed(const Duration(milliseconds: 500), () {
            _loadChats();
          });
        }
      },
      onError: (error) {
        print('❌ ChatList: Error in received messages listener: $error');
        // Retry loading on error
        Future.delayed(const Duration(seconds: 2), () {
          _loadChats();
        });
      },
    );

    // Also listen for connection changes (new accepted connections)
    _connectionsSubscription = FirebaseFirestore.instance
        .collection('connections')
        .where('status', isEqualTo: 'accepted')
        .where(
          Filter.or(
            Filter('userId', isEqualTo: currentUser.uid),
            Filter('connectedUserId', isEqualTo: currentUser.uid),
          ),
        )
        .snapshots()
        .listen(
          (snapshot) {
            print('🔗 ChatList: Connection changes detected');
            // Refresh chats when connections change
            _loadChats();
          },
          onError: (error) {
            print('❌ ChatList: Error in connections listener: $error');
          },
        );
  }

  Timer? _searchDebounce;

  void _searchChats(String query) {
    // Cancel previous debounce
    _searchDebounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _filteredChats = List.from(_allChats);
        _isSearching = false;
      });
      return;
    }

    // Show loading state
    setState(() {
      _isSearching = true;
    });

    // Debounce search to avoid too many Firestore queries
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _filteredChats = [];
        _isSearching = false;
      });
      return;
    }

    final queryLower = query.trim().toLowerCase();
    print('Searching for: $queryLower');

    // First, filter existing chats locally (instant)
    final filteredExistingChats = _allChats.where((chat) {
      final userName = (chat['userName'] ?? '').toString().toLowerCase();
      final faculty = (chat['faculty'] ?? '').toString().toLowerCase();
      final lastMessage = (chat['lastMessage'] ?? '').toString().toLowerCase();

      return userName.contains(queryLower) ||
          faculty.contains(queryLower) ||
          lastMessage.contains(queryLower);
    }).toList();

    print('Found ${filteredExistingChats.length} existing chats');

    // Show existing chats immediately
    setState(() {
      _filteredChats = filteredExistingChats;
    });

    // If query is too short, don't search Firestore
    if (query.length < 2) {
      setState(() {
        _isSearching = false;
      });
      return;
    }

    // Search in Firestore for users without existing chats
    try {
      print('Searching Firestore for users...');
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('profileCompleted', isEqualTo: true)
          .get();

      print('Found ${usersSnapshot.docs.length} users in Firestore');

      final List<Map<String, dynamic>> searchResults = List.from(
        filteredExistingChats,
      );
      final Set<String> existingUserIds = _allChats
          .map((c) => c['userId'] as String)
          .toSet();

      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data();
        final userId = userDoc.id;

        // Skip current user
        if (userId == currentUser.uid) continue;

        // Skip if already in existing chats
        if (existingUserIds.contains(userId)) continue;

        // Check if name or faculty matches
        final userName = (userData['name'] ?? '').toString().toLowerCase();
        final userFaculty = (userData['faculty'] ?? '')
            .toString()
            .toLowerCase();

        if (userName.contains(queryLower) || userFaculty.contains(queryLower)) {
          print('Match found: ${userData['name']}');
          // Get last message if exists
          String lastMessage = 'No messages yet';
          DateTime lastMessageTime = DateTime.now();

          try {
            final messagesQuery = await FirebaseFirestore.instance
                .collection('messages')
                .where(
                  Filter.or(
                    Filter.and(
                      Filter('senderId', isEqualTo: currentUser.uid),
                      Filter('receiverId', isEqualTo: userId),
                    ),
                    Filter.and(
                      Filter('senderId', isEqualTo: userId),
                      Filter('receiverId', isEqualTo: currentUser.uid),
                    ),
                  ),
                )
                .orderBy('createdAt', descending: true)
                .limit(1)
                .get();

            if (messagesQuery.docs.isNotEmpty) {
              final msgData = messagesQuery.docs.first.data();
              lastMessage = msgData['content'] ?? 'No messages yet';
              lastMessageTime =
                  (msgData['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime.now();
            }
          } catch (e) {
            // If orderBy fails, try without it
            try {
              final messagesQuery = await FirebaseFirestore.instance
                  .collection('messages')
                  .where(
                    Filter.or(
                      Filter.and(
                        Filter('senderId', isEqualTo: currentUser.uid),
                        Filter('receiverId', isEqualTo: userId),
                      ),
                      Filter.and(
                        Filter('senderId', isEqualTo: userId),
                        Filter('receiverId', isEqualTo: currentUser.uid),
                      ),
                    ),
                  )
                  .limit(1)
                  .get();

              if (messagesQuery.docs.isNotEmpty) {
                final msgData = messagesQuery.docs.first.data();
                lastMessage = msgData['content'] ?? 'No messages yet';
                lastMessageTime =
                    (msgData['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now();
              }
            } catch (e2) {
              print('Error getting last message: $e2');
            }
          }

          // Get unread count
          int unreadCount = 0;
          try {
            final unreadQuery = await FirebaseFirestore.instance
                .collection('messages')
                .where('receiverId', isEqualTo: currentUser.uid)
                .where('senderId', isEqualTo: userId)
                .where('read', isEqualTo: false)
                .get();
            unreadCount = unreadQuery.docs.length;
          } catch (e) {
            print('Error getting unread count: $e');
          }

          searchResults.add({
            'id': userId,
            'userId': userId,
            'userName': userData['name'] ?? 'Unknown',
            'userAvatar': (userData['name'] ?? 'U')[0].toUpperCase(),
            'faculty': userData['faculty'] ?? '',
            'lastMessage': lastMessage,
            'timestamp': lastMessageTime,
            'unreadCount': unreadCount,
            'isOnline': false,
            'isTyping': false,
          });
        }
      }

      // Sort by timestamp
      searchResults.sort(
        (a, b) =>
            (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime),
      );

      print('Total search results: ${searchResults.length}');

      if (mounted) {
        setState(() {
          _filteredChats = searchResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      print('Error searching chats: $e');
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    // Handle future timestamps (shouldn't happen, but just in case)
    if (difference.isNegative) {
      return 'Just now';
    }

    // Less than 1 minute
    if (difference.inSeconds < 60) {
      return 'Just now';
    }
    // Less than 1 hour
    else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    }
    // Less than 24 hours
    else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    }
    // Yesterday
    else if (difference.inDays == 1) {
      return 'Yesterday';
    }
    // Less than 7 days
    else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    }
    // Less than 30 days
    else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
    }
    // Less than 365 days
    else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return months == 1 ? '1 month ago' : '$months months ago';
    }
    // More than a year - show date
    else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _filteredChats
        .where((chat) => chat['unreadCount'] > 0)
        .fold(0, (sum, chat) => sum + (chat['unreadCount'] as int));

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
            ...List.generate(10, (index) => _buildParticle(index)),
            // Main content
            SafeArea(
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  children: [
                    // Header
                    _buildHeader(unreadCount),
                    // Search Bar
                    _buildSearchBar(),
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
                            // Tabs or filters (optional)
                            _buildChatTabs(),
                            // Chat List
                            Expanded(
                              child: _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF667eea),
                                      ),
                                    )
                                  : _isSearching && _filteredChats.isEmpty
                                  ? const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF667eea),
                                      ),
                                    )
                                  : _filteredChats.isEmpty
                                  ? _buildEmptyState()
                                  : _buildChatList(),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.messages,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Stay connected with your matches',
                  style: TextStyle(fontSize: 13, color: Colors.white70),
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            _searchChats(value);
          },
          decoration: InputDecoration(
            hintText: context.l10n.searchConversations,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            prefixIcon: const Icon(
              Icons.search,
              color: Color(0xFF667eea),
              size: 24,
            ),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                      _searchChats('');
                    },
                    icon: const Icon(Icons.clear, color: Colors.grey),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      child: Row(
        children: [
          _buildTabChip('All', _filteredChats.length, true),
          const SizedBox(width: 10),
          _buildTabChip(
            'Unread',
            _filteredChats.where((c) => c['unreadCount'] > 0).length,
            false,
          ),
          const SizedBox(width: 10),
          _buildTabChip(
            'Online',
            _filteredChats.where((c) => c['isOnline'] == true).length,
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildTabChip(String label, int count, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        gradient: isSelected
            ? const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              )
            : null,
        color: isSelected ? null : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? Colors.transparent : Colors.grey.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.grey.shade700,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withOpacity(0.3)
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey.shade700,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _filteredChats.length,
      itemBuilder: (context, index) {
        final chat = _filteredChats[index];
        return _buildChatItem(chat);
      },
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => IndividualChatScreen(
              userName: chat['userName'] ?? 'Unknown',
              userAvatar: chat['userAvatar'] ?? 'U',
              userId: chat['userId'] ?? '',
              isOnline: chat['isOnline'] ?? false,
              faculty: chat['faculty'] ?? '',
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(15),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: (chat['unreadCount'] as int) > 0
              ? const Color(0xFF667eea).withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: (chat['unreadCount'] as int) > 0
                ? const Color(0xFF667eea).withOpacity(0.3)
                : Colors.grey.shade200,
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
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: (chat['isOnline'] as bool)
                          ? Colors.green
                          : Colors.grey.shade300,
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      chat['userAvatar'] ?? 'U',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Online indicator
                if (chat['isOnline'] as bool)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 15),
            // Chat info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat['userName'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: (chat['unreadCount'] as int) > 0
                                ? FontWeight.bold
                                : FontWeight.w600,
                            color: Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTimestamp(chat['timestamp'] as DateTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: (chat['unreadCount'] as int) > 0
                              ? const Color(0xFF667eea)
                              : Colors.grey.shade600,
                          fontWeight: (chat['unreadCount'] as int) > 0
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Expanded(
                        child: (chat['isTyping'] as bool)
                            ? Row(
                                children: [
                                  Icon(
                                    Icons.edit,
                                    size: 14,
                                    color: Colors.green.shade600,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'typing...',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.green.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                chat['lastMessage'] ?? '',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: (chat['unreadCount'] as int) > 0
                                      ? Colors.black87
                                      : Colors.grey.shade600,
                                  fontWeight: (chat['unreadCount'] as int) > 0
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                      ),
                      if ((chat['unreadCount'] as int) > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${chat['unreadCount']}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
              Icons.chat_bubble_outline,
              size: 60,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Start connecting with people to begin chatting',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to browse
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BrowseScreen()),
              );
            },
            icon: const Icon(Icons.explore),
            label: const Text('Browse Users'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            ),
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
    final top = random.nextDouble() * 250;

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
