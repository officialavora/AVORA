import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'core/avora_community_rules.dart';
import 'services/avora_google_sign_in_adapter.dart';
import 'ui/avora_games_screen.dart';
import 'ui/avora_messages_screen.dart';
import 'ui/avora_rooms_screen.dart';
import 'ui/avora_social_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AvoraApp());
}

String normalizeAvoraUsername(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
}

Future<Map<String, dynamic>> ensureAvoraAccount({String? requestedUsername}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('Not signed in');
  }

  final db = FirebaseFirestore.instance;
  final userRef = db.collection('users').doc(user.uid);
  final counterRef = db.collection('system').doc('counters');

  return db.runTransaction<Map<String, dynamic>>((transaction) async {
    final userSnapshot = await transaction.get(userRef);
    final existing = userSnapshot.data();

    if (userSnapshot.exists && existing != null) {
      return existing;
    }

    final counterSnapshot = await transaction.get(counterRef);
    final counter = counterSnapshot.data();

    if (!counterSnapshot.exists ||
        counter == null ||
        counter['lastUserId'] is! int) {
      throw StateError('AVORA ID counter is not configured');
    }

    final nextId = (counter['lastUserId'] as int) + 1;
    if (nextId < 10000000) {
      throw StateError('AVORA ID counter is below the production range');
    }

    final fallbackUsername = 'avora$nextId';
    final normalizedUsername = normalizeAvoraUsername(
      requestedUsername?.trim().isNotEmpty == true
          ? requestedUsername!
          : fallbackUsername,
    );
    if (!RegExp(r'^[a-z][a-z0-9_]{3,19}$').hasMatch(normalizedUsername)) {
      throw StateError(
        'Username must start with a letter and contain 4-20 letters, numbers or underscores',
      );
    }

    final usernameRef = db.collection('usernames').doc(normalizedUsername);
    final usernameSnapshot = await transaction.get(usernameRef);
    if (usernameSnapshot.exists) {
      throw StateError('Username is already taken');
    }
    final name = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : 'AVORA User';

    transaction.update(counterRef, {'lastUserId': nextId});

    transaction.set(usernameRef, {
      'uid': user.uid,
      'username': normalizedUsername,
      'avoraId': nextId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    transaction.set(userRef, {
      'originalAvoraId': nextId,
      'username': normalizedUsername,
      'usernameChangedAt': FieldValue.serverTimestamp(),
      'role': 'user',
      'authorityRole': 'user',
      'commerceRole': 'none',
      'staffAssignments': <String>[],
      'scopeType': 'self',
      'countryCode': null,
      'managerId': null,
      'bdId': null,
      'agencyId': null,
      'displayName': name,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return {
      'originalAvoraId': nextId,
      'username': normalizedUsername,
      'role': 'user',
      'displayName': name,
    };
  });
}

class AvoraApp extends StatelessWidget {
  const AvoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AVORA',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C4DFF),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0D0A1A),
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1800), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => FirebaseAuth.instance.currentUser == null
                ? const WelcomeScreen()
                : const MainShell()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AvoraLogo(size: 104),
            SizedBox(height: 18),
            Text(
              'AVORA',
              style: TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                letterSpacing: 5,
              ),
            ),
            SizedBox(height: 8),
            Text('Voice • Video • Live • Social'),
          ],
        ),
      ),
    );
  }
}

class AvoraLogo extends StatelessWidget {
  final double size;
  const AvoraLogo({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7C4DFF), Color(0xFFE040FB), Color(0xFF00D4FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF7C4DFF).withValues(alpha: 0.35),
            blurRadius: 30,
          ),
        ],
      ),
      child: const Center(
        child: Text(
          'A',
          style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  void _openHome(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              const AvoraLogo(size: 110),
              const SizedBox(height: 22),
              const Text(
                'Welcome to AVORA',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 31, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              const Text(
                'Meet, talk, create rooms and build your community.',
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Text('Create account'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => LoginScreen(
                              onAuthenticated: () => _openHome(context))),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Text('Log in'),
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  final VoidCallback onAuthenticated;
  const LoginScreen({super.key, required this.onAuthenticated});

  Future<void> _signInWithGoogle(BuildContext context) async {
    try {
      final adapter = AvoraGoogleSignInAdapter();
      await adapter.initialize();

      final result = await adapter.signIn();

      if (!context.mounted) return;

      if (result.success) {
        onAuthenticated();
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Google sign-in failed: ${result.error.name}',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Google sign-in error: $error'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = TextEditingController();
    final password = TextEditingController();

    return Scaffold(
      appBar: AppBar(title: const Text('Log in')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signInWithEmailAndPassword(
                  email: email.text.trim(),
                  password: password.text,
                );
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainShell()),
                  (_) => false,
                );
              } on FirebaseAuthException catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message ?? 'Login failed')),
                );
              }
            },
            child: const Text('Log in'),
          ),
          OutlinedButton.icon(
            onPressed: () => _signInWithGoogle(context),
            icon: const Icon(Icons.login),
            label: const Text('Continue with Google'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () async {
              if (email.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter your email first')),
                );
                return;
              }
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(
                  email: email.text.trim(),
                );
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password reset email sent')),
                );
              } on FirebaseAuthException catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(e.message ?? 'Could not send reset email')),
                );
              }
            },
            child: const Text('Forgot password'),
          ),
        ],
      ),
    );
  }
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String gender = 'Prefer not to say';
  bool acceptedPolicies = false;

  final displayName = TextEditingController();
  final username = TextEditingController();
  final country = TextEditingController();
  final invite = TextEditingController();
  final dob = TextEditingController();
  final bio = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  Future<void> showCommunityRules() async {
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AVORA Rules & Regulations'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final rule in AvoraCommunityRules.current) ...[
                Text(
                  rule.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(rule.summary),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    displayName.dispose();
    username.dispose();
    country.dispose();
    invite.dispose();
    dob.dispose();
    bio.dispose();
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: displayName,
            decoration: const InputDecoration(labelText: 'Display name *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: username,
            autocorrect: false,
            enableSuggestions: false,
            maxLength: 20,
            decoration: const InputDecoration(
              labelText: 'Unique username *',
              prefixText: '@',
              helperText: '4-20 lowercase letters, numbers or underscores',
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(
                value: 'Prefer not to say',
                child: Text('Prefer not to say'),
              ),
            ],
            onChanged: (v) => setState(() => gender = v ?? gender),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: country,
            decoration: const InputDecoration(labelText: 'Country *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: invite,
            decoration:
                const InputDecoration(labelText: 'Invitation code (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: dob,
            decoration:
                const InputDecoration(labelText: 'Date of birth (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: bio,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Bio (optional)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password *'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: acceptedPolicies,
            onChanged: (value) {
              setState(() => acceptedPolicies = value ?? false);
            },
            title: const Text('I agree to AVORA Terms, Privacy and Rules'),
            subtitle: TextButton(
              onPressed: showCommunityRules,
              child: const Align(
                alignment: Alignment.centerLeft,
                child: Text('Read Rules & Regulations'),
              ),
            ),
            controlAffinity: ListTileControlAffinity.leading,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () async {
              if (displayName.text.trim().isEmpty ||
                  !RegExp(r'^[a-z][a-z0-9_]{3,19}$')
                      .hasMatch(normalizeAvoraUsername(username.text)) ||
                  country.text.trim().isEmpty ||
                  email.text.trim().isEmpty ||
                  password.text.length < 6 ||
                  !acceptedPolicies) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Complete all required fields and accept AVORA policies'),
                  ),
                );
                return;
              }

              User? newlyCreatedUser;
              var identityCreated = false;
              try {
                final result =
                    await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: email.text.trim(),
                  password: password.text,
                );
                newlyCreatedUser = result.user;

                await result.user?.updateDisplayName(displayName.text.trim());

                final user = result.user;
                if (user != null) {
                  await ensureAvoraAccount(requestedUsername: username.text);
                  identityCreated = true;
                  await FirebaseFirestore.instance
                      .collection('policy_acceptances')
                      .doc(user.uid)
                      .set({
                    'avoraUid': user.uid,
                    'acceptedAt': FieldValue.serverTimestamp(),
                    'documents': [
                      for (final document
                          in AvoraCommunityRules.requiredSignupDocuments)
                        {
                          'type': document.type.name,
                          'version': document.version,
                        },
                    ],
                  });
                }

                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainShell()),
                  (_) => false,
                );
              } on FirebaseAuthException catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(e.message ?? 'Account creation failed')),
                );
              } on FirebaseException catch (e) {
                if (!identityCreated) {
                  await newlyCreatedUser?.delete();
                }
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message ?? 'Account setup failed')),
                );
              } on StateError catch (e) {
                if (!identityCreated) {
                  await newlyCreatedUser?.delete();
                }
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(e.message)),
                );
              }
            },
            child: const Text('Create account'),
          ),
        ],
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int index = 0;
  late Future<Map<String, dynamic>> accountFuture;

  @override
  void initState() {
    super.initState();
    accountFuture = ensureAvoraAccount();
  }

  void retry() {
    setState(() {
      accountFuture = ensureAvoraAccount();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: accountFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Could not prepare your AVORA ID',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: retry,
                      child: const Text('Try again'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final pages = <Widget>[
          const HomePage(),
          const AvoraRoomsScreen(),
          const AvoraMessagesScreen(),
          ProfilePage(account: snapshot.data!),
        ];

        return Scaffold(
          body: pages[index],
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (v) => setState(() => index = v),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: 'Home',
              ),
              NavigationDestination(
                icon: Icon(Icons.mic_none),
                selectedIcon: Icon(Icons.mic),
                label: 'Rooms',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Messages',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            AvoraLogo(size: 34),
            SizedBox(width: 10),
            Text('AVORA'),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AvoraPeopleScreen()),
            ),
            icon: const Icon(Icons.search),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _HeroCard(),
          const SizedBox(height: 18),
          const Text('Discover',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _FeatureTile(
              icon: Icons.mic,
              title: 'Voice Rooms',
              subtitle: 'Join conversations and communities',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VoiceRoomScreen(roomName: 'Welcome to AVORA', seatCount: 10)))),
          _FeatureTile(
              icon: Icons.videocam,
              title: 'Live',
              subtitle: 'Discover live creators and events',
              onTap: () => _openFeature(context, 'Live', Icons.videocam, const ['Live rooms will appear here when creators start streaming.'])),
          _FeatureTile(
              icon: Icons.card_giftcard,
              title: 'Rewards',
              subtitle: 'Daily tasks, levels and rewards',
              onTap: () => _openFeature(context, 'Rewards', Icons.card_giftcard, const ['Daily check-in', 'Join a room', 'Complete your profile'])),
          _FeatureTile(
              icon: Icons.sports_esports_rounded,
              title: 'Games',
              subtitle: 'Play 43 original AVORA games',
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const AvoraGamesScreen(),
                  ))),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF5E35B1), Color(0xFF8E24AA), Color(0xFF1565C0)],
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AVORA',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
          SizedBox(height: 6),
          Text('Your world. Your voice.'),
          SizedBox(height: 30),
          Text('Voice • Community • Entertainment'),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class RoomsPage extends StatelessWidget {
  const RoomsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rooms')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Create room'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _RoomCard(name: 'Welcome to AVORA', themeName: 'Aurora', members: 12),
          _RoomCard(name: 'Music & Friends', themeName: 'Night', members: 7),
        ],
      ),
    );
  }
}

class _RoomCard extends StatelessWidget {
  final String name;
  final String themeName;
  final int members;

  const _RoomCard({
    required this.name,
    required this.themeName,
    required this.members,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => VoiceRoomScreen(roomName: name, seatCount: 10),
        )),
        leading: const CircleAvatar(child: Icon(Icons.mic)),
        title: Text(name),
        subtitle: Text('$themeName theme • $members online'),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class CreateRoomScreen extends StatefulWidget {
  const CreateRoomScreen({super.key});

  @override
  State<CreateRoomScreen> createState() => _CreateRoomScreenState();
}

class _CreateRoomScreenState extends State<CreateRoomScreen> {
  final roomName = TextEditingController();
  String themeName = 'Aurora';
  String privacy = 'Public';
  int seats = 10;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create room')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: roomName,
            decoration: const InputDecoration(labelText: 'Room name *'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: themeName,
            decoration: const InputDecoration(labelText: 'Theme'),
            items: const [
              DropdownMenuItem(value: 'Aurora', child: Text('Aurora')),
              DropdownMenuItem(value: 'Night', child: Text('Night')),
              DropdownMenuItem(value: 'Ocean', child: Text('Ocean')),
            ],
            onChanged: (v) => setState(() => themeName = v ?? themeName),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: privacy,
            decoration: const InputDecoration(labelText: 'Privacy'),
            items: const [
              DropdownMenuItem(value: 'Public', child: Text('Public')),
              DropdownMenuItem(
                  value: 'Approval', child: Text('Approval required')),
              DropdownMenuItem(value: 'Private', child: Text('Private')),
            ],
            onChanged: (v) => setState(() => privacy = v ?? privacy),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: seats,
            decoration: const InputDecoration(labelText: 'Mic seats'),
            items: const [
              DropdownMenuItem(value: 8, child: Text('8 seats')),
              DropdownMenuItem(value: 10, child: Text('10 seats')),
              DropdownMenuItem(value: 15, child: Text('15 seats')),
            ],
            onChanged: (v) => setState(() => seats = v ?? seats),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: () {
              final name = roomName.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a room name')),
                );
                return;
              }
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                builder: (_) => VoiceRoomScreen(roomName: name, seatCount: seats),
              ));
            },
            child: const Text('Create room'),
          ),
        ],
      ),
    );
  }
}

class MessagesPage extends StatelessWidget {
  const MessagesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FeatureTile(icon: Icons.notifications, title: 'Notifications', subtitle: 'Room invites, follows and rewards', onTap: () => _openFeature(context, 'Notifications', Icons.notifications, const ['Welcome to AVORA', 'Your account is ready', 'Community rules are active'])),
          _FeatureTile(icon: Icons.campaign, title: 'System notices', subtitle: 'Official AVORA updates', onTap: () => _openFeature(context, 'System notices', Icons.campaign, const ['No new maintenance notices'])),
          _FeatureTile(icon: Icons.support_agent, title: 'Contact support', subtitle: 'Report a problem or request help', onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportScreen()))),
        ],
      ),
    );
  }
}

class ProfilePage extends StatelessWidget {
  final Map<String, dynamic> account;

  const ProfilePage({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final name = (account['displayName'] as String?)?.trim().isNotEmpty == true
        ? (account['displayName'] as String).trim()
        : ((user?.displayName?.trim().isNotEmpty ?? false)
            ? user!.displayName!.trim()
            : 'AVORA User');

    final avoraId = account['originalAvoraId'] ?? '—';
    final role = (account['role'] ?? 'user').toString().toUpperCase();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: AvoraLogo(size: 92)),
          const SizedBox(height: 14),
          Center(
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'ID: $avoraId',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Chip(label: Text(role))),
          const SizedBox(height: 22),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(value: '0', label: 'Friends'),
              _Stat(value: '0', label: 'Followers'),
              _Stat(value: '0', label: 'Following'),
              _Stat(value: '0', label: 'Visitors'),
            ],
          ),
          const SizedBox(height: 24),
          _FeatureTile(
            icon: Icons.edit_outlined,
            title: 'Edit profile',
            subtitle: 'Update your public name, bio and country',
            onTap: () => _editAvoraProfile(context, account),
          ),
          _FeatureTile(
            icon: Icons.account_balance_wallet,
            title: 'Wallet',
            subtitle: 'Coins, diamonds and transactions',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const WalletScreen())),
          ),
          _FeatureTile(
            icon: Icons.workspace_premium,
            title: 'VIP / Levels',
            subtitle: 'Benefits and premium identity',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const VipScreen())),
          ),
          _FeatureTile(
            icon: Icons.groups,
            title: 'Family / CP',
            subtitle: 'Family and relationship center',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FamilyScreen())),
          ),
          _FeatureTile(
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'Privacy, security and preferences',
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
          _FeatureTile(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Owner moderation',
            subtitle: 'Protected reports and review queue',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const AvoraOwnerModerationScreen(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
              if (!context.mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                (_) => false,
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

Future<void> _editAvoraProfile(
  BuildContext context,
  Map<String, dynamic> account,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;
  final name = TextEditingController(
    text: (account['displayName'] ?? user.displayName ?? '').toString(),
  );
  final bio = TextEditingController(text: (account['bio'] ?? '').toString());
  final country = TextEditingController(
    text: (account['countryCode'] ?? '').toString(),
  );
  final save = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Edit AVORA profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              maxLength: 60,
              decoration: const InputDecoration(labelText: 'Display name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bio,
              maxLength: 240,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: country,
              maxLength: 2,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Country code',
                hintText: 'IN, SA, AE',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (save != true || !context.mounted) return;
  final displayName = name.text.trim();
  final countryCode = country.text.trim().toUpperCase();
  if (displayName.length < 2 ||
      displayName.length > 60 ||
      (countryCode.isNotEmpty &&
          !RegExp(r'^[A-Z]{2}$').hasMatch(countryCode))) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Check the name and country code.')),
    );
    return;
  }
  try {
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'displayName': displayName,
      'bio': bio.text.trim(),
      'countryCode': countryCode.isEmpty ? null : countryCode,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await user.updateDisplayName(displayName);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile saved securely.')),
    );
  } on FirebaseException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.message ?? error.code)),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}

void _openFeature(BuildContext context, String title, IconData icon,
    List<String> items) {
  Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => SimpleFeatureScreen(title: title, icon: icon, items: items),
  ));
}

class SimpleFeatureScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<String> items;
  const SimpleFeatureScreen({super.key, required this.title, required this.icon, required this.items});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, i) => Card(child: ListTile(
            leading: CircleAvatar(child: Icon(icon)),
            title: Text(items[i]),
          )),
        ),
      );
}

class VoiceRoomScreen extends StatefulWidget {
  final String roomName;
  final int seatCount;
  const VoiceRoomScreen({super.key, required this.roomName, required this.seatCount});
  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  int? mySeat;
  bool muted = false;
  final messages = <String>['AVORA: Welcome to the room'];
  final message = TextEditingController();

  void send() {
    final value = message.text.trim();
    if (value.isEmpty) return;
    setState(() => messages.add('You: $value'));
    message.clear();
  }

  void gifts() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Send a gift', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Wrap(spacing: 12, runSpacing: 12, children: [
              for (final gift in const [('Rose', '🌹', 10), ('Star', '⭐', 50), ('Crown', '👑', 200), ('Rocket', '🚀', 500)])
                ActionChip(label: Text('${gift.$2} ${gift.$1} · ${gift.$3}'), onPressed: () {
                  Navigator.pop(context);
                  setState(() => messages.add('You sent ${gift.$2} ${gift.$1}'));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${gift.$1} sent')));
                }),
            ])
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.roomName, style: const TextStyle(fontSize: 17)),
            const Text('Public room', style: TextStyle(fontSize: 11, color: Colors.white70)),
          ]),
          actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert))],
        ),
        body: Column(children: [
          Expanded(flex: 3, child: GridView.builder(
            padding: const EdgeInsets.all(18),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 4, mainAxisSpacing: 18, crossAxisSpacing: 12),
            itemCount: widget.seatCount,
            itemBuilder: (_, i) {
              final occupied = mySeat == i;
              return InkWell(
                borderRadius: BorderRadius.circular(40),
                onTap: () => setState(() { mySeat = occupied ? null : i; muted = false; }),
                child: Column(children: [
                  CircleAvatar(radius: 25, backgroundColor: occupied ? const Color(0xFF7C4DFF) : Colors.white12,
                    child: Icon(occupied ? (muted ? Icons.mic_off : Icons.mic) : Icons.add)),
                  const SizedBox(height: 5),
                  Text(occupied ? 'You' : 'Seat ${i + 1}', style: const TextStyle(fontSize: 10), overflow: TextOverflow.ellipsis),
                ]),
              );
            },
          )),
          Expanded(flex: 2, child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: messages.length,
            itemBuilder: (_, i) => Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text(messages[i])),
          )),
          SafeArea(top: false, child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(children: [
              IconButton(onPressed: mySeat == null ? null : () => setState(() => muted = !muted), icon: Icon(muted ? Icons.mic_off : Icons.mic)),
              Expanded(child: TextField(controller: message, onSubmitted: (_) => send(), decoration: const InputDecoration(hintText: 'Say something…', isDense: true))),
              IconButton(onPressed: send, icon: const Icon(Icons.send)),
              IconButton(onPressed: gifts, icon: const Icon(Icons.card_giftcard)),
            ]),
          )),
        ]),
      );
}

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override
  State<WalletScreen> createState() => _WalletScreenState();
}
class _WalletScreenState extends State<WalletScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Wallet')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Card(child: Padding(padding: EdgeInsets.all(22), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
        _Balance(icon: Icons.monetization_on, value: '0', label: 'Coins'),
        _Balance(icon: Icons.diamond, value: '0', label: 'Diamonds'),
      ]))),
      const SizedBox(height: 12),
      const Text('Recharge', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 2.1, children: [
        for (final amount in const [100, 500, 1000, 5000]) Card(child: InkWell(onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Online payment provider is not active in this test build'))), child: Center(child: Text('🪙 $amount coins')))),
      ]),
      const ListTile(leading: Icon(Icons.receipt_long), title: Text('Transactions'), subtitle: Text('No transactions yet')),
    ]),
  );
}
class _Balance extends StatelessWidget {
  final IconData icon; final String value; final String label;
  const _Balance({required this.icon, required this.value, required this.label});
  @override Widget build(BuildContext context) => Column(children: [Icon(icon, size: 30), Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold)), Text(label)]);
}

class VipScreen extends StatelessWidget {
  const VipScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('VIP & Levels')), body: ListView(padding: const EdgeInsets.all(16), children: [
    const Card(child: ListTile(leading: CircleAvatar(child: Icon(Icons.person)), title: Text('Level 1'), subtitle: LinearProgressIndicator(value: .1))),
    const SizedBox(height: 12),
    for (final vip in const [('VIP 1', 'Profile badge and colored name'), ('VIP 2', 'Premium frame and entry effect'), ('VIP 3', 'Exclusive room identity and mount')])
      Card(child: ListTile(leading: const Icon(Icons.workspace_premium), title: Text(vip.$1), subtitle: Text(vip.$2), trailing: const Icon(Icons.lock_outline))),
  ]));
}

class FamilyScreen extends StatelessWidget {
  const FamilyScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Family & CP')), body: ListView(padding: const EdgeInsets.all(16), children: [
    const Icon(Icons.groups, size: 80), const Center(child: Text('Build your AVORA family', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
    const SizedBox(height: 12), const Text('Create a family, invite members and grow together.', textAlign: TextAlign.center), const SizedBox(height: 22),
    FilledButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Family request form opened'))), child: const Text('Create family')),
    OutlinedButton(onPressed: () => _openFeature(context, 'CP Center', Icons.favorite, const ['No CP relationship connected']), child: const Text('Open CP Center')),
  ]));
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsScreenState();
}
class _SettingsScreenState extends State<SettingsScreen> {
  bool notifications = true; bool privateProfile = false; bool hidePresence = false;
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Settings')), body: ListView(children: [
    SwitchListTile(value: notifications, onChanged: (v) => setState(() => notifications = v), title: const Text('Notifications')),
    SwitchListTile(value: privateProfile, onChanged: (v) => setState(() => privateProfile = v), title: const Text('Private profile')),
    SwitchListTile(value: hidePresence, onChanged: (v) => setState(() => hidePresence = v), title: const Text('Hide online status')),
    ListTile(leading: const Icon(Icons.rule), title: const Text('Rules & Regulations'), trailing: const Icon(Icons.chevron_right), onTap: () => showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('AVORA Community Rules'), content: SingleChildScrollView(child: Text(AvoraCommunityRules.current.map((e) => '${e.title}\n${e.summary}').join('\n\n'))), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))]))),
    ListTile(leading: const Icon(Icons.support_agent), title: const Text('Help & Support'), onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportScreen()))),
    ListTile(leading: const Icon(Icons.delete_outline), title: const Text('Delete account'), subtitle: const Text('Request permanent account deletion'), onTap: () => showDialog<void>(context: context, builder: (_) => AlertDialog(title: const Text('Delete account?'), content: const Text('This submits a deletion request. Your account is not deleted until the request is confirmed.'), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')), FilledButton(onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deletion request recorded for review'))); }, child: const Text('Request deletion'))]))),
  ]));
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});
  @override State<SupportScreen> createState() => _SupportScreenState();
}
class _SupportScreenState extends State<SupportScreen> {
  final subject = TextEditingController(); final details = TextEditingController();
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Contact support')), body: ListView(padding: const EdgeInsets.all(18), children: [
    TextField(controller: subject, decoration: const InputDecoration(labelText: 'Subject')),
    const SizedBox(height: 12), TextField(controller: details, maxLines: 6, decoration: const InputDecoration(labelText: 'Describe the problem')),
    const SizedBox(height: 18), FilledButton(onPressed: () { if (subject.text.trim().isEmpty || details.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Complete both fields'))); return; } ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support request prepared'))); }, child: const Text('Submit request')),
  ]));
}
