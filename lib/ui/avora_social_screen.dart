import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AvoraPeopleScreen extends StatefulWidget {
  const AvoraPeopleScreen({super.key});

  @override
  State<AvoraPeopleScreen> createState() => _AvoraPeopleScreenState();
}

class _AvoraPeopleScreenState extends State<AvoraPeopleScreen> {
  final _search = TextEditingController();
  final _db = FirebaseFirestore.instance;
  Map<String, dynamic>? _result;
  String? _username;
  Object? _error;
  bool _loading = false;

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final username = _search.text.trim().toLowerCase();
    if (!RegExp(r'^[a-z][a-z0-9_]{3,19}$').hasMatch(username)) return;
    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });
    try {
      final document = await _db.collection('usernames').doc(username).get();
      if (!document.exists) throw StateError('AVORA member not found');
      setState(() {
        _username = username;
        _result = document.data();
      });
    } catch (error) {
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _follow() async {
    final result = _result;
    final username = _username;
    if (result == null || username == null) return;
    final targetUid = result['uid'] as String;
    if (targetUid == _uid) return;
    final follow = _db.collection('follows').doc('${_uid}_$targetUid');
    final notice = _db.collection('notifications').doc(targetUid).collection('items').doc();
    final batch = _db.batch();
    batch.set(follow, {
      'sourceUid': _uid,
      'targetUid': targetUid,
      'targetUsername': username,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(notice, {
      'recipientUid': targetUid,
      'actorUid': _uid,
      'type': 'follow',
      'title': 'New follower',
      'body': 'An AVORA member followed you',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Following @$username')),
    );
    setState(() {});
  }

  Future<void> _unfollow(String targetUid) async {
    await _db.collection('follows').doc('${_uid}_$targetUid').delete();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final targetUid = _result?['uid'] as String?;
    final followStream = targetUid == null || targetUid == _uid
        ? null
        : _db.collection('follows').doc('${_uid}_$targetUid').snapshots();
    return Scaffold(
      appBar: AppBar(title: const Text('Find AVORA people')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _search,
            autocorrect: false,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Exact username',
              prefixText: '@',
              suffixIcon: IconButton(
                onPressed: _loading ? null : _find,
                icon: const Icon(Icons.search),
              ),
            ),
            onSubmitted: (_) => _find(),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Text('Search failed: $_error'),
            ),
          if (_result != null) ...[
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    const CircleAvatar(
                      radius: 34,
                      child: Icon(Icons.person, size: 34),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '@$_username',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text('AVORA ID ${_result!['avoraId']}'),
                    const SizedBox(height: 16),
                    if (targetUid == _uid)
                      const Chip(label: Text('This is you'))
                    else
                      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: followStream,
                        builder: (context, snapshot) {
                          final following = snapshot.data?.exists == true;
                          return FilledButton.icon(
                            onPressed: following
                                ? () => _unfollow(targetUid!)
                                : _follow,
                            icon: Icon(
                              following ? Icons.person_remove : Icons.person_add,
                            ),
                            label: Text(following ? 'Unfollow' : 'Follow'),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AvoraNotificationsScreen extends StatelessWidget {
  const AvoraNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final items = FirebaseFirestore.instance
        .collection('notifications')
        .doc(user.uid)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: items,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Notifications unavailable: ${snapshot.error}'));
          }
          final rows = snapshot.data?.docs ?? const [];
          if (rows.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final row = rows[index];
              final data = row.data();
              return Card(
                child: ListTile(
                  leading: Icon(
                    data['read'] == true
                        ? Icons.notifications_none
                        : Icons.notifications_active,
                  ),
                  title: Text((data['title'] ?? 'AVORA').toString()),
                  subtitle: Text((data['body'] ?? '').toString()),
                  onTap: () => row.reference.update({'read': true}),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class AvoraOwnerModerationScreen extends StatelessWidget {
  const AvoraOwnerModerationScreen({super.key});

  Future<bool> _isOwner() async {
    final token = await FirebaseAuth.instance.currentUser!.getIdTokenResult(true);
    return token.claims?['avora_owner'] == true;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _isOwner(),
        builder: (context, owner) {
          if (owner.connectionState != ConnectionState.done) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (owner.data != true) {
            return Scaffold(
              appBar: AppBar(title: const Text('Owner moderation')),
              body: const Center(child: Text('Verified Owner access required.')),
            );
          }
          final reports = FirebaseFirestore.instance
              .collection('reports')
              .where('status', isEqualTo: 'pending')
              .orderBy('createdAt')
              .limit(100)
              .snapshots();
          return Scaffold(
            appBar: AppBar(title: const Text('Owner moderation')),
            body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: reports,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Queue unavailable: ${snapshot.error}'));
                }
                final rows = snapshot.data?.docs ?? const [];
                if (rows.isEmpty) {
                  return const Center(child: Text('No pending reports.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rows.length,
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final data = row.data();
                    return Card(
                      child: ListTile(
                        title: Text((data['category'] ?? 'Report').toString()),
                        subtitle: Text((data['details'] ?? '').toString()),
                        trailing: PopupMenuButton<String>(
                          onSelected: (status) => row.reference.update({
                            'status': status,
                            'reviewedBy': FirebaseAuth.instance.currentUser!.uid,
                            'reviewedAt': FieldValue.serverTimestamp(),
                          }),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'approved', child: Text('Approve')),
                            PopupMenuItem(value: 'rejected', child: Text('Reject')),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      );
}
