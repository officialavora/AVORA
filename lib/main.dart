import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'services/avora_firebase_auth_bridge.dart';
import 'services/avora_google_sign_in_adapter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AvoraApp());
}

Future<Map<String, dynamic>> ensureAvoraAccount({
  void Function(String status)? onProgress,
}) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw StateError('Not signed in');
  }

  onProgress?.call('Creating AVORA account');

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

    onProgress?.call('Generating permanent AVORA ID');
    final nextId = (counter['lastUserId'] as int) + 1;
    final name = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName!.trim()
        : 'AVORA User';

    transaction.update(counterRef, {'lastUserId': nextId});

    onProgress?.call('Saving profile');
    transaction.set(userRef, {
      'originalAvoraId': nextId,
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
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.35,
                colors: [
                  Color(0xFF3B176B),
                  Color(0xFF130B26),
                  Color(0xFF05040A),
                ],
              ),
            ),
          ),
          Positioned(
            top: -90,
            right: -70,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFB55CFF).withValues(alpha: 0.10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x557C4DFF),
                    blurRadius: 100,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 24),
              child: Column(
                children: [
                  const Spacer(flex: 2),
                  TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutBack,
                    tween: Tween(begin: 0.78, end: 1),
                    builder: (context, value, child) =>
                        Transform.scale(scale: value, child: child),
                    child: const AvoraLogo(size: 112),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'AVORA',
                    style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 7,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'VOICE • CONNECT • CELEBRATE',
                    style: TextStyle(
                      color: Color(0xFFD8B86A),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Your stage. Your people. Your world.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  const Spacer(flex: 3),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.13),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x66000000),
                          blurRadius: 30,
                          offset: Offset(0, 16),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Welcome to AVORA',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const SignupScreen(),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 15),
                              child: Text('Create AVORA account'),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => LoginScreen(
                                    onDemoLogin: () => _openHome(context),
                                  ),
                                ),
                              );
                            },
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 15),
                              child: Text('Log in with Google or Email'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'By continuing, you agree to AVORA Terms and Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.white54),
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

class LoginScreen extends StatefulWidget {
  final VoidCallback onDemoLogin;

  const LoginScreen({super.key, required this.onDemoLogin});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController();
  final password = TextEditingController();

  bool googleBusy = false;
  String? authProgress;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  void _setProgress(String value) {
    if (!mounted) return;
    setState(() => authProgress = value);
  }

  String _googleFailureMessage(AvoraGoogleAuthResult result) {
    switch (result.error) {
      case AvoraGoogleAuthError.notInitialized:
        return 'Google sign-in is still preparing. Please try again.';
      case AvoraGoogleAuthError.interactiveAuthUnsupported:
        return 'Google sign-in is not available on this device.';
      case AvoraGoogleAuthError.missingIdToken:
        return 'Google could not verify this account. Please try again.';
      case AvoraGoogleAuthError.firebaseBridgeRejected:
        if (result.firebaseError ==
            AvoraFirebaseAuthBridgeError.networkError) {
          return 'Your connection was interrupted. Check the network and retry.';
        }
        if (result.firebaseError ==
            AvoraFirebaseAuthBridgeError.userDisabled) {
          return 'This account is unavailable. Please contact AVORA support.';
        }
        return 'AVORA could not complete Google sign-in. Please try again.';
      case AvoraGoogleAuthError.googleAuthenticationFailed:
        return 'Google sign-in did not complete. Please try again.';
      case AvoraGoogleAuthError.avoraPolicyApprovalRequired:
        return 'This account cannot be linked yet.';
      case AvoraGoogleAuthError.none:
        return 'Google sign-in did not complete. Please try again.';
    }
  }

  Future<void> _signInWithGoogle() async {
    if (googleBusy) return;

    setState(() {
      googleBusy = true;
      authProgress = 'Connecting to Google';
    });

    try {
      final adapter = AvoraGoogleSignInAdapter();
      await adapter.initialize();

      _setProgress('Waiting for Google account');
      final result = await adapter.signIn();

      if (!mounted) return;

      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_googleFailureMessage(result))),
        );
        return;
      }

      _setProgress('Google account verified');

      await ensureAvoraAccount(
        onProgress: _setProgress,
      );

      _setProgress('Account ready');
      if (!mounted) return;
      widget.onDemoLogin();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'AVORA could not finish signing in. Please check your connection and retry.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          googleBusy = false;
          authProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log in')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (authProgress != null) ...[
            Semantics(
              liveRegion: true,
              label: authProgress,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 14),
                      Expanded(child: Text(authProgress!)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
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
            onPressed: googleBusy
                ? null
                : () async {
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
                    } on FirebaseAuthException {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Login failed. Check your email and password, then try again.',
                          ),
                        ),
                      );
                    }
                  },
            child: const Text('Log in'),
          ),
          OutlinedButton.icon(
            onPressed: googleBusy ? null : _signInWithGoogle,
            icon: const Icon(Icons.login),
            label: const Text('Continue with Google'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: googleBusy
                ? null
                : () async {
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
                        const SnackBar(
                          content: Text('Password reset email sent'),
                        ),
                      );
                    } on FirebaseAuthException {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not send the reset email. Please verify the address and retry.',
                          ),
                        ),
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

  final displayName = TextEditingController();
  final country = TextEditingController();
  final invite = TextEditingController();
  final dob = TextEditingController();
  final bio = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  @override
  void dispose() {
    displayName.dispose();
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
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () async {
              if (displayName.text.trim().isEmpty ||
                  country.text.trim().isEmpty ||
                  email.text.trim().isEmpty ||
                  password.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Name, country, email and 6+ digit password required'),
                  ),
                );
                return;
              }

              try {
                final result =
                    await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: email.text.trim(),
                  password: password.text,
                );

                await result.user?.updateDisplayName(displayName.text.trim());

                final account = await ensureAvoraAccount();
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(result.user!.uid)
                    .set({
                  'displayName': displayName.text.trim(),
                  'gender': gender,
                  'country': country.text.trim(),
                  'invitationCode': invite.text.trim().isEmpty
                      ? null
                      : invite.text.trim(),
                  'dateOfBirth': dob.text.trim().isEmpty ? null : dob.text.trim(),
                  'bio': bio.text.trim().isEmpty ? null : bio.text.trim(),
                  'profileSetupComplete': true,
                  'updatedAt': FieldValue.serverTimestamp(),
                  'originalAvoraId': account['originalAvoraId'],
                }, SetOptions(merge: true));

                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const MainShell()),
                  (_) => false,
                );
              } on FirebaseAuthException catch (error) {
                if (!context.mounted) return;
                final message = switch (error.code) {
                  'email-already-in-use' =>
                    'This email already has an AVORA account. Please log in.',
                  'invalid-email' =>
                    'Please enter a valid email address.',
                  'weak-password' =>
                    'Choose a stronger password with at least 6 characters.',
                  _ =>
                    'AVORA could not create the account. Please try again.',
                };
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Your account was created, but the profile could not be saved. Please retry.',
                    ),
                  ),
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
          const RoomsPage(),
          const MessagesPage(),
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
          IconButton(onPressed: () {}, icon: const Icon(Icons.search)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _HeroCard(),
          SizedBox(height: 18),
          Text('Discover',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          _FeatureTile(
              icon: Icons.mic,
              title: 'Voice Rooms',
              subtitle: 'Join conversations and communities'),
          _FeatureTile(
              icon: Icons.videocam,
              title: 'Live',
              subtitle: 'Video and interactive live rooms — planned'),
          _FeatureTile(
              icon: Icons.card_giftcard,
              title: 'Rewards',
              subtitle: 'Tasks, levels and rewards — planned'),
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
          Text('Starter build v0.1'),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
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
          const TextField(
            decoration: InputDecoration(labelText: 'Room name *'),
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
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Demo room created locally')),
              );
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
      body: const Center(
        child: Text('Notifications • System Notice • Contact Us • Chats'),
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
          const _FeatureTile(
            icon: Icons.account_balance_wallet,
            title: 'Wallet',
            subtitle: 'Coins, diamonds and transactions',
          ),
          const _FeatureTile(
            icon: Icons.workspace_premium,
            title: 'VIP / Levels',
            subtitle: 'Benefits and premium identity',
          ),
          const _FeatureTile(
            icon: Icons.groups,
            title: 'Family / CP',
            subtitle: 'Family and relationship center',
          ),
          const _FeatureTile(
            icon: Icons.settings,
            title: 'Settings',
            subtitle: 'Privacy, security and preferences',
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
