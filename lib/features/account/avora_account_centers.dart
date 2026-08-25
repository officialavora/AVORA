import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AvoraFamilyCenterPage extends StatefulWidget {
  const AvoraFamilyCenterPage({super.key});
  @override
  State<AvoraFamilyCenterPage> createState() => _AvoraFamilyCenterPageState();
}

class _AvoraFamilyCenterPageState extends State<AvoraFamilyCenterPage> {
  bool saving = false;

  Future<void> _edit(Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final name = TextEditingController(text: (data['name'] ?? 'My AVORA Family').toString());
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit family'),
        content: TextField(controller: name, maxLength: 40, decoration: const InputDecoration(labelText: 'Family name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (accepted != true || name.text.trim().isEmpty) return;
    await FirebaseFirestore.instance.collection('families').doc(uid).set({
      'ownerUid': uid,
      'name': name.text.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _photo() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || saving) return;
    final image = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50, maxWidth: 512, maxHeight: 512);
    if (image == null) return;
    setState(() => saving = true);
    try {
      final bytes = await File(image.path).readAsBytes();
      if (bytes.length > 700000) throw const FormatException();
      await FirebaseFirestore.instance.collection('families').doc(uid).set({
        'ownerUid': uid,
        'photoDataUrl': 'data:image/jpeg;base64,${base64Encode(bytes)}',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const Scaffold(body: Center(child: Text('Sign in required')));
    return Scaffold(
      appBar: AppBar(title: const Text('Family center')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('families').doc(uid).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? const <String, dynamic>{};
          final photo = (data['photoDataUrl'] ?? '').toString();
          ImageProvider? image;
          if (photo.startsWith('data:image') && photo.contains(',')) {
            try { image = MemoryImage(base64Decode(photo.split(',').last)); } catch (_) {}
          }
          return ListView(padding: const EdgeInsets.all(24), children: [
            Center(child: Stack(children: [
              CircleAvatar(radius: 58, backgroundImage: image, child: image == null ? const Icon(Icons.groups, size: 52) : null),
              Positioned(right: 0, bottom: 0, child: IconButton.filled(onPressed: saving ? null : _photo, icon: const Icon(Icons.camera_alt))),
            ])),
            const SizedBox(height: 18),
            Text((data['name'] ?? 'My AVORA Family').toString(), textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: () => _edit(data), icon: const Icon(Icons.edit), label: const Text('Edit family name')),
            const SizedBox(height: 24),
            const Card(child: ListTile(leading: Icon(Icons.shield_outlined), title: Text('Family privacy'), subtitle: Text('Owner contact details are never shown publicly.'))),
          ]);
        },
      ),
    );
  }
}

class AvoraRechargeRequestPage extends StatefulWidget {
  const AvoraRechargeRequestPage({super.key});
  @override
  State<AvoraRechargeRequestPage> createState() => _AvoraRechargeRequestPageState();
}

class _AvoraRechargeRequestPageState extends State<AvoraRechargeRequestPage> {
  final id = TextEditingController();
  final amount = TextEditingController(text: '10000');
  bool sending = false;

  @override
  void dispose() { id.dispose(); amount.dispose(); super.dispose(); }

  Future<void> submit() async {
    final user = FirebaseAuth.instance.currentUser;
    final target = int.tryParse(id.text.trim());
    final coins = int.tryParse(amount.text.trim());
    if (user == null || target == null || coins == null || coins < 1 || coins > 1000000) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid AVORA ID and test coin amount.')));
      return;
    }
    setState(() => sending = true);
    try {
      await FirebaseFirestore.instance.collection('testRechargeRequests').add({
        'requesterUid': user.uid,
        'targetAvoraId': target,
        'testCoins': coins,
        'status': 'pending',
        'environment': 'test',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      id.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Test recharge request sent securely.')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Test coin recharge')),
    body: ListView(padding: const EdgeInsets.all(24), children: [
      const Card(child: ListTile(leading: Icon(Icons.science_outlined), title: Text('Test economy only'), subtitle: Text('No payment and no withdrawable value. Every approved grant must be recorded.'))),
      const SizedBox(height: 18),
      TextField(controller: id, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Receiver AVORA ID', prefixIcon: Icon(Icons.badge_outlined))),
      const SizedBox(height: 12),
      TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Test coins', prefixIcon: Icon(Icons.monetization_on_outlined))),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: sending ? null : submit, icon: const Icon(Icons.send), label: Text(sending ? 'Sending…' : 'Send recharge request')),
    ]),
  );
}
