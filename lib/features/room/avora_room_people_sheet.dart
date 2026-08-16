import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AvoraRoomPeopleSheet extends StatelessWidget {
  const AvoraRoomPeopleSheet({
    super.key,
    required this.roomId,
    required this.isOwner,
    required this.accent,
  });

  final String roomId;
  final bool isOwner;
  final Color accent;

  FirebaseFirestore get _db => FirebaseFirestore.instance;
  String? get _myUid => FirebaseAuth.instance.currentUser?.uid;

  Future<void> _follow(String targetUid) async {
    final me = _myUid;
    if (me == null || me == targetUid) return;
    final batch = _db.batch();
    batch.set(
      _db.collection('socialGraphs').doc(me).collection('following').doc(targetUid),
      {'profileUid': targetUid, 'createdAt': FieldValue.serverTimestamp()},
    );
    batch.set(
      _db.collection('socialGraphs').doc(targetUid).collection('followers').doc(me),
      {'profileUid': me, 'createdAt': FieldValue.serverTimestamp()},
    );
    await batch.commit();
  }

  Future<void> _addFriend(String targetUid) async {
    final me = _myUid;
    if (me == null || me == targetUid) return;
    final batch = _db.batch();
    batch.set(
      _db.collection('socialGraphs').doc(me).collection('friends').doc(targetUid),
      {
        'profileUid': targetUid,
        'status': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
    batch.set(
      _db.collection('socialGraphs').doc(targetUid).collection('friends').doc(me),
      {
        'profileUid': me,
        'status': 'accepted',
        'createdAt': FieldValue.serverTimestamp(),
      },
    );
    await batch.commit();
  }

  Future<void> _moderate(String targetUid, String action) async {
    final member =
        _db.collection('rooms').doc(roomId).collection('members').doc(targetUid);
    if (action == 'kick') {
      await member.delete();
    } else {
      await member.set({
        'moderationMuted': action == 'mute',
        'lastModeratedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  void _notice(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final me = _myUid;
    return SafeArea(
      child: FractionallySizedBox(
        heightFactor: 0.78,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 10, 8),
              child: Row(
                children: [
                  Icon(Icons.groups_2_outlined, color: accent),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Room People',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _db
                    .collection('rooms')
                    .doc(roomId)
                    .collection('members')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final people = snapshot.data!.docs;
                  if (people.isEmpty) {
                    return const Center(child: Text('No active members'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
                    itemCount: people.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final person = people[index];
                      final data = person.data();
                      final uid = person.id;
                      final mine = uid == me;
                      final name =
                          (data['displayName'] ?? 'AVORA Member').toString();
                      final photo = data['photoUrl']?.toString();
                      final muted = data['moderationMuted'] == true;
                      final seat =
                          ((data['seatIndex'] as num?)?.toInt() ?? -1) + 1;
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
                        leading: CircleAvatar(
                          backgroundColor: accent.withValues(alpha: 0.18),
                          backgroundImage: photo != null && photo.isNotEmpty
                              ? NetworkImage(photo)
                              : null,
                          child: photo == null || photo.isEmpty
                              ? Text(name.isEmpty ? 'A' : name[0].toUpperCase())
                              : null,
                        ),
                        title: Text(mine ? '$name • You' : name),
                        subtitle: Text(
                          muted ? 'Muted by room owner' : 'Seat $seat',
                          style: TextStyle(
                            color: muted ? Colors.redAccent : Colors.white60,
                          ),
                        ),
                        trailing: mine
                            ? const Chip(label: Text('You'))
                            : Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Follow',
                                    onPressed: () async {
                                      try {
                                        await _follow(uid);
                                        if (context.mounted) {
                                          _notice(context, 'Following $name');
                                        }
                                      } catch (_) {
                                        if (context.mounted) {
                                          _notice(context, 'Follow could not be saved.');
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.person_add_alt_1),
                                  ),
                                  IconButton(
                                    tooltip: 'Add friend',
                                    onPressed: () async {
                                      try {
                                        await _addFriend(uid);
                                        if (context.mounted) {
                                          _notice(context, '$name added as friend');
                                        }
                                      } catch (_) {
                                        if (context.mounted) {
                                          _notice(context, 'Friend could not be saved.');
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.group_add_outlined),
                                  ),
                                  if (isOwner)
                                    PopupMenuButton<String>(
                                      onSelected: (action) async {
                                        try {
                                          await _moderate(uid, action);
                                          if (context.mounted) {
                                            _notice(
                                              context,
                                              action == 'kick'
                                                  ? '$name removed from room'
                                                  : action == 'mute'
                                                      ? '$name muted'
                                                      : '$name unmuted',
                                            );
                                          }
                                        } catch (_) {
                                          if (context.mounted) {
                                            _notice(context, 'Owner action failed.');
                                          }
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                          value: muted ? 'unmute' : 'mute',
                                          child: Text(
                                            muted ? 'Unmute member' : 'Mute member',
                                          ),
                                        ),
                                        const PopupMenuItem(
                                          value: 'kick',
                                          child: Text('Kick from room'),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
