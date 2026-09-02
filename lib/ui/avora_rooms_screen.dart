import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AvoraRoomsScreen extends StatefulWidget {
  const AvoraRoomsScreen({super.key});

  @override
  State<AvoraRoomsScreen> createState() => _AvoraRoomsScreenState();
}

class _AvoraRoomsScreenState extends State<AvoraRoomsScreen> {
  final _firestore = FirebaseFirestore.instance;
  Object? _createError;
  bool _creating = false;

  Stream<QuerySnapshot<Map<String, dynamic>>> _rooms() => _firestore
      .collection('rooms')
      .where('status', isEqualTo: 'active')
      .orderBy('updatedAt', descending: true)
      .limit(100)
      .snapshots();

  Future<void> _createRoom() async {
    final name = TextEditingController();
    final description = TextEditingController();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create an AVORA room'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Room name'),
            ),
            TextField(
              controller: description,
              maxLength: 240,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    if (accepted != true) return;

    final roomName = name.text.trim();
    if (roomName.length < 3) {
      setState(() => _createError = 'Room name must contain 3-60 characters');
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _creating = true;
      _createError = null;
    });
    try {
      final roomRef = _firestore.collection('rooms').doc();
      final memberRef = roomRef.collection('members').doc(user.uid);
      final batch = _firestore.batch();
      batch.set(roomRef, {
        'ownerUid': user.uid,
        'name': roomName,
        'description': description.text.trim(),
        'status': 'active',
        'visibility': 'public',
        'memberCount': 1,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      batch.set(memberRef, {
        'uid': user.uid,
        'role': 'host',
        'status': 'active',
        'joinedAt': FieldValue.serverTimestamp(),
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AvoraRoomChatScreen(
            roomId: roomRef.id,
            roomName: roomName,
          ),
        ),
      );
    } on FirebaseException catch (error) {
      if (mounted) setState(() => _createError = error.message ?? error.code);
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AVORA Rooms'),
        actions: [
          IconButton(
            onPressed: _creating ? null : _createRoom,
            icon: _creating
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add_circle_outline),
            tooltip: 'Create room',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_createError != null)
            MaterialBanner(
              content: Text('Could not create room: $_createError'),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _createError = null),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _rooms(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return _RoomState(
                    icon: Icons.cloud_off,
                    title: 'Rooms could not be loaded',
                    subtitle: '${snapshot.error}',
                    action: () => setState(() {}),
                  );
                }
                final rooms = snapshot.data?.docs ?? const [];
                if (rooms.isEmpty) {
                  return _RoomState(
                    icon: Icons.forum_outlined,
                    title: 'No active rooms yet',
                    subtitle: 'Create the first original AVORA room.',
                    action: _createRoom,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => setState(() {}),
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: rooms.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final room = rooms[index];
                      final data = room.data();
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.auto_awesome),
                          ),
                          title: Text(data['name'] as String? ?? 'AVORA Room'),
                          subtitle: Text(
                            data['description'] as String? ?? '',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Text('${data['memberCount'] ?? 0}'),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AvoraRoomChatScreen(
                                roomId: room.id,
                                roomName:
                                    data['name'] as String? ?? 'AVORA Room',
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class AvoraRoomChatScreen extends StatefulWidget {
  const AvoraRoomChatScreen({
    super.key,
    required this.roomId,
    required this.roomName,
  });

  final String roomId;
  final String roomName;

  @override
  State<AvoraRoomChatScreen> createState() => _AvoraRoomChatScreenState();
}

class _AvoraRoomChatScreenState extends State<AvoraRoomChatScreen> {
  final _message = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  bool _joining = true;
  bool _sending = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _join();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final memberRef = _firestore
          .collection('rooms')
          .doc(widget.roomId)
          .collection('members')
          .doc(user.uid);
      await _firestore.runTransaction((transaction) async {
        final member = await transaction.get(memberRef);
        if (member.exists) {
          transaction.update(memberRef, {
            'status': 'active',
            'lastActiveAt': FieldValue.serverTimestamp(),
          });
        } else {
          transaction.set(memberRef, {
            'uid': user.uid,
            'role': 'member',
            'status': 'active',
            'joinedAt': FieldValue.serverTimestamp(),
            'lastActiveAt': FieldValue.serverTimestamp(),
          });
        }
      });
    } on FirebaseException catch (error) {
      _error = error.message ?? error.code;
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  Future<void> _send() async {
    final body = _message.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (body.isEmpty || user == null || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await _firestore
          .collection('rooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'senderUid': user.uid,
        'senderName': user.displayName ?? 'AVORA Member',
        'body': body,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
      _message.clear();
    } on FirebaseException catch (error) {
      if (mounted) setState(() => _error = error.message ?? error.code);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = _firestore
        .collection('rooms')
        .doc(widget.roomId)
        .collection('messages')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
    return Scaffold(
      appBar: AppBar(title: Text(widget.roomName)),
      body: Column(
        children: [
          if (_joining) const LinearProgressIndicator(),
          if (_error != null)
            MaterialBanner(
              content: Text('Room error: $_error'),
              actions: [
                TextButton(onPressed: _join, child: const Text('Retry')),
              ],
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: messages,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Messages unavailable: ${snapshot.error}'));
                }
                final rows = snapshot.data?.docs ?? const [];
                if (rows.isEmpty) {
                  return const Center(child: Text('Start the conversation.'));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final data = rows[index].data();
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(child: Icon(Icons.person)),
                      title: Text(data['senderName'] as String? ?? 'Member'),
                      subtitle: Text(data['body'] as String? ?? ''),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      enabled: !_joining,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        hintText: 'Message the room',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending || _joining ? null : _send,
                    icon: _sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoomState extends StatelessWidget {
  const _RoomState({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 54),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(subtitle, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(onPressed: action, child: const Text('Continue')),
            ],
          ),
        ),
      );
}
