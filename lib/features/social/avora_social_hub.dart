import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

enum AvoraSocialCategory { friends, followers, following, visitors, gifters }

extension AvoraSocialCategoryPresentation on AvoraSocialCategory {
  String get label => switch (this) {
        AvoraSocialCategory.friends => 'Friends',
        AvoraSocialCategory.followers => 'Followers',
        AvoraSocialCategory.following => 'Following',
        AvoraSocialCategory.visitors => 'Visitors',
        AvoraSocialCategory.gifters => 'Gifters',
      };

  IconData get icon => switch (this) {
        AvoraSocialCategory.friends => Icons.people_alt_rounded,
        AvoraSocialCategory.followers => Icons.favorite_rounded,
        AvoraSocialCategory.following => Icons.person_add_alt_1_rounded,
        AvoraSocialCategory.visitors => Icons.visibility_rounded,
        AvoraSocialCategory.gifters => Icons.card_giftcard_rounded,
      };
}

class AvoraSocialHubPage extends StatelessWidget {
  const AvoraSocialHubPage({
    super.key,
    required this.account,
    this.initialCategory = AvoraSocialCategory.friends,
  });

  final Map<String, dynamic> account;
  final AvoraSocialCategory initialCategory;

  int countFor(AvoraSocialCategory category) => switch (category) {
        AvoraSocialCategory.friends =>
          (account['friendsCount'] as num?)?.toInt() ?? 0,
        AvoraSocialCategory.followers =>
          (account['followersCount'] as num?)?.toInt() ?? 0,
        AvoraSocialCategory.following =>
          (account['followingCount'] as num?)?.toInt() ?? 0,
        AvoraSocialCategory.visitors =>
          (account['visitorsCount'] as num?)?.toInt() ?? 0,
        AvoraSocialCategory.gifters =>
          (account['giftersCount'] as num?)?.toInt() ?? 0,
      };

  @override
  Widget build(BuildContext context) {
    const categories = AvoraSocialCategory.values;
    return DefaultTabController(
      length: categories.length,
      initialIndex: categories.indexOf(initialCategory),
      child: Scaffold(
        backgroundColor: const Color(0xFF07050D),
        appBar: AppBar(
          title: const Text('My people'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final category in categories)
                Tab(text: '${category.label} ${countFor(category)}'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            for (final category in categories)
              _SocialCategoryView(category: category),
          ],
        ),
      ),
    );
  }
}

class _SocialCategoryView extends StatelessWidget {
  const _SocialCategoryView({required this.category});
  final AvoraSocialCategory category;

  @override
  Widget build(BuildContext context) {
    if (Firebase.apps.isEmpty) {
      return _SocialEmptyState(category: category);
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return _SocialEmptyState(category: category);
    if (category == AvoraSocialCategory.gifters) {
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('testGiftLedger')
            .where('receiverUid', isEqualTo: uid)
            .limit(100)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return _SocialErrorState(category: category);
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final gifts = snapshot.data!.docs;
          if (gifts.isEmpty) return _SocialEmptyState(category: category);
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: gifts.length,
            itemBuilder: (context, index) {
              final gift = gifts[index].data();
              return _SocialPersonTile(
                icon: category.icon,
                title: (gift['giftName'] ?? 'AVORA gift').toString(),
                subtitle: 'From AVORA member • ×${gift['quantity'] ?? 1}',
              );
            },
          );
        },
      );
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('socialGraphs')
          .doc(uid)
          .collection(category.name)
          .limit(100)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return _SocialErrorState(category: category);
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final people = snapshot.data!.docs;
        if (people.isEmpty) return _SocialEmptyState(category: category);
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: people.length,
          itemBuilder: (context, index) {
            final person = people[index].data();
            return _SocialPersonTile(
              icon: category.icon,
              title: (person['displayName'] ?? 'AVORA member').toString(),
              subtitle: 'ID ${person['originalAvoraId'] ?? '—'}',
            );
          },
        );
      },
    );
  }
}

class _SocialPersonTile extends StatelessWidget {
  const _SocialPersonTile({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
        color: Colors.white.withValues(alpha: 0.055),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: const Color(0xFF7C4DFF).withValues(alpha: 0.18),
            child: Icon(icon, color: const Color(0xFFD8B86A)),
          ),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
        ),
      );
}

class _SocialEmptyState extends StatelessWidget {
  const _SocialEmptyState({required this.category});
  final AvoraSocialCategory category;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(category.icon, size: 54, color: const Color(0xFFD8B86A)),
              const SizedBox(height: 16),
              Text('No ${category.label.toLowerCase()} yet',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                category == AvoraSocialCategory.visitors
                    ? 'Profile visits appear here according to your privacy settings.'
                    : category == AvoraSocialCategory.gifters
                        ? 'Members who send you gifts appear here.'
                        : 'Your AVORA connections will appear here.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60),
              ),
            ],
          ),
        ),
      );
}

class _SocialErrorState extends StatelessWidget {
  const _SocialErrorState({required this.category});
  final AvoraSocialCategory category;

  @override
  Widget build(BuildContext context) =>
      Center(child: Text('${category.label} could not refresh. Please retry.'));
}
