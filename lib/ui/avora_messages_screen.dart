import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AvoraMessagesScreen extends StatefulWidget {
  const AvoraMessagesScreen({super.key});

  @override
  State<AvoraMessagesScreen> createState() => _AvoraMessagesScreenState();
}

class _AvoraMessagesScreenState extends State<AvoraMessagesScreen> {
  final _db = FirebaseFirestore.instance;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  Stream<QuerySnapshot<Map<String, dynamic>>> _threads() => _db
      .collection('conversations')
      .where('participantUids', arrayContains: _uid)
      .orderBy('updatedAt', descending: true)
      .limit(100)
      .snapshots();

  Future<void> _startConversation() async {
    final controller = TextEditingController();
    final username = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('New AVORA message'),
        content: TextField(
          controller: controller,
          autofocus: true,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'Unique username',
            prefixText: '@',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              controller.text.trim().toLowerCase(),
            ),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (username == null || username.isEmpty || !mounted) return;
    try {
      final reservation = await _db.collection('usernames').doc(username).get();
      if (!reservation.exists) throw StateError('Username not found');
      final peerUid = reservation.data()!['uid'] as String;
      if (peerUid == _uid) throw StateError('Choose another AVORA member');
      final ids = [_uid, peerUid]..sort();
      final conversationId = ids.join('_');
      final ref = _db.collection('conversations').doc(conversationId);
      await _db.runTransaction((transaction) async {
        final existing = await transaction.get(ref);
        if (!existing.exists) {
          transaction.set(ref, {
            'participantUids': ids,
            'participantNames': {_uid: 'You', peerUid: username},
            'createdBy': _uid,
            'status': 'active',
            'lastMessage': '',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      });
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AvoraDirectChatScreen(
            conversationId: conversationId,
            peerUid: peerUid,
            peerName: username,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start chat: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
          actions: [
            IconButton(
              onPressed: _startConversation,
              icon: const Icon(Icons.edit_square),
              tooltip: 'New message',
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _threads(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _MessageState(
                icon: Icons.cloud_off,
                title: 'Messages unavailable',
                detail: '${snapshot.error}',
                action: () => setState(() {}),
              );
            }
            final rows = snapshot.data?.docs ?? const [];
            if (rows.isEmpty) {
              return _MessageState(
                icon: Icons.mark_chat_unread_outlined,
                title: 'No conversations yet',
                detail: 'Start a secure AVORA conversation by username.',
                action: _startConversation,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: rows.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final data = rows[index].data();
                final participants = List<String>.from(
                  data['participantUids'] as List? ?? const [],
                );
                final peerUid = participants.firstWhere(
                  (item) => item != _uid,
                  orElse: () => '',
                );
                final names = Map<String, dynamic>.from(
                  data['participantNames'] as Map? ?? const {},
                );
                final peerName = (names[peerUid] ?? 'AVORA Member').toString();
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text('@$peerName'),
                    subtitle: Text(
                      (data['lastMessage'] ?? 'Start the conversation').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AvoraDirectChatScreen(
                          conversationId: rows[index].id,
                          peerUid: peerUid,
                          peerName: peerName,
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
}

class AvoraDirectChatScreen extends StatefulWidget {
  const AvoraDirectChatScreen({
    super.key,
    required this.conversationId,
    required this.peerUid,
    required this.peerName,
  });

  final String conversationId;
  final String peerUid;
  final String peerName;

  @override
  State<AvoraDirectChatScreen> createState() => _AvoraDirectChatScreenState();
}

class _AvoraDirectChatScreenState extends State<AvoraDirectChatScreen> {
  final _message = TextEditingController();
  final _db = FirebaseFirestore.instance;
  bool _sending = false;
  Object? _error;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _message.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final thread = _db.collection('conversations').doc(widget.conversationId);
      final message = thread.collection('messages').doc();
      final batch = _db.batch();
      batch.set(message, {
        'senderUid': _uid,
        'body': body,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
      });
      batch.update(thread, {
        'lastMessage': body,
        'lastSenderUid': _uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      _message.clear();
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _block() async {
    final ref = _db.collection('blocks').doc('${_uid}_${widget.peerUid}');
    await ref.set({
      'blockerUid': _uid,
      'blockedUid': widget.peerUid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) Navigator.pop(context);
  }

  Future<void> _report() async {
    await _db.collection('reports').add({
      'reporterUid': _uid,
      'targetUid': widget.peerUid,
      'conversationId': widget.conversationId,
      'category': 'direct_message',
      'details': 'Reported from direct conversation',
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report submitted for Owner review.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = _db
        .collection('conversations')
        .doc(widget.conversationId)
        .collection('messages')
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
    return Scaffold(
      appBar: AppBar(
        title: Text('@${widget.peerName}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'report') _report();
              if (value == 'block') _block();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'report', child: Text('Report')),
              PopupMenuItem(value: 'block', child: Text('Block')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_error != null)
            MaterialBanner(
              content: Text('Message failed: $_error'),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _error = null),
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Chat unavailable: ${snapshot.error}'));
                }
                final rows = snapshot.data?.docs ?? const [];
                if (rows.isEmpty) {
                  return const Center(child: Text('Send the first message.'));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final data = rows[index].data();
                    final mine = data['senderUid'] == _uid;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Card(
                        color: mine
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          child: Text((data['body'] ?? '').toString()),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _message,
                      maxLength: 2000,
                      maxLines: 4,
                      minLines: 1,
                      decoration: const InputDecoration(
                        hintText: 'Message',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
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

class _MessageState extends StatelessWidget {
  const _MessageState({
    required this.icon,
    required this.title,
    required this.detail,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String detail;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 52),
              const SizedBox(height: 12),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(detail, textAlign: TextAlign.center),
              const SizedBox(height: 18),
              FilledButton(onPressed: action, child: const Text('Continue')),
            ],
          ),
        ),
      );
}
