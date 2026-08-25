import 'package:flutter/material.dart';

class AvoraPrestigeShowcase extends StatelessWidget {
  const AvoraPrestigeShowcase({
    super.key,
    required this.account,
    this.photo,
    this.onPhotoTap,
  });

  final Map<String, dynamic> account;
  final ImageProvider<Object>? photo;
  final VoidCallback? onPhotoTap;

  int _level(String key) => (account[key] as num?)?.toInt() ?? 0;

  void _openGiftWall(BuildContext context) {
    const gifts = [
      ('Royal Rose', '🌹', 'Classic'),
      ('AVORA Crown', '👑', 'Royal'),
      ('Moon Wish', '🌙', 'Premium'),
      ('Celebration', '🎉', 'Party'),
      ('Golden Heart', '💛', 'Charm'),
      ('Diamond Star', '💎', 'Legend'),
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF130A20),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('AVORA Gift Wall',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(
              '${_level('giftersCount')} gifters • test gifts only',
              style: const TextStyle(color: Colors.white60),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: gifts.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: .86,
              ),
              itemBuilder: (context, index) {
                final gift = gifts[index];
                return DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3E1462), Color(0xFF160B25)],
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFD36B).withValues(alpha: .5)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text(gift.$2, style: const TextStyle(fontSize: 31)),
                      const SizedBox(height: 5),
                      Text(gift.$1, textAlign: TextAlign.center,
                          maxLines: 2, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                      Text(gift.$3, style: const TextStyle(fontSize: 9, color: Color(0xFFFFD36B))),
                    ]),
                  ),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final medal = _level('richLevel') + _level('charmLevel');
    final supporter = _level('vipLevel');
    return Column(
      key: const Key('profile-prestige-showcase'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Prestige',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _PrestigeCard(
            icon: Icons.military_tech,
            title: 'Medal',
            value: 'Level $medal',
            colors: const [Color(0xFFFFC65A), Color(0xFF7B2CBF)],
          )),
          const SizedBox(width: 10),
          Expanded(child: _PrestigeCard(
            icon: Icons.workspace_premium,
            title: 'Supporter',
            value: supporter > 0 ? 'VIP $supporter' : 'Starter',
            colors: const [Color(0xFFE248A6), Color(0xFF4A1C80)],
          )),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: InkWell(
              key: const Key('open-gift-wall'),
              borderRadius: BorderRadius.circular(18),
              onTap: () => _openGiftWall(context),
              child: const _WallCard(
                icon: Icons.card_giftcard,
                title: 'Gift Wall',
                subtitle: 'Gifts and supporters',
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              key: const Key('open-photo-wall'),
              borderRadius: BorderRadius.circular(18),
              onTap: onPhotoTap,
              child: _WallCard(
                icon: Icons.photo_library_outlined,
                title: 'Photo Wall',
                subtitle: onPhotoTap == null ? 'Profile showcase' : 'Tap to add photo',
                photo: photo,
              ),
            ),
          ),
        ]),
      ],
    );
  }
}

class _PrestigeCard extends StatelessWidget {
  const _PrestigeCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.colors,
  });
  final IconData icon;
  final String title;
  final String value;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      gradient: LinearGradient(colors: colors),
      borderRadius: BorderRadius.circular(18),
      boxShadow: [BoxShadow(color: colors.first.withValues(alpha: .24), blurRadius: 18)],
    ),
    child: Row(children: [
      Icon(icon, color: Colors.white),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        Text(value, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ])),
    ]),
  );
}

class _WallCard extends StatelessWidget {
  const _WallCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.photo,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final ImageProvider<Object>? photo;

  @override
  Widget build(BuildContext context) => Container(
    height: 104,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFFFD36B).withValues(alpha: .25)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      CircleAvatar(
        radius: 17,
        backgroundColor: const Color(0xFF5D258B),
        backgroundImage: photo,
        child: photo == null ? Icon(icon, size: 19, color: const Color(0xFFFFD36B)) : null,
      ),
      const Spacer(),
      Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
      Text(subtitle, maxLines: 1,
          style: const TextStyle(fontSize: 10, color: Colors.white60)),
    ]),
  );
}
