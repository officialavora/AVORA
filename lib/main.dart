import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:country_picker/country_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'services/avora_country_suggestion.dart';
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
  final publicRef = db.collection('publicProfiles').doc(user.uid);
  final counterRef = db.collection('system').doc('counters');

  return db.runTransaction<Map<String, dynamic>>((transaction) async {
    final userSnapshot = await transaction.get(userRef);
    final existing = userSnapshot.data();

    if (userSnapshot.exists && existing != null) {
      transaction.set(publicRef, {
        'originalAvoraId': existing['originalAvoraId'],
        'displayName': existing['displayName'] ?? user.displayName ?? 'AVORA User',
        'photoDataUrl': existing['photoDataUrl'],
        'photoUrl': existing['photoUrl'],
        'bio': existing['bio'],
        'country': existing['country'],
        'countryCode': existing['countryCode'],
        'richLevel': existing['richLevel'] ?? 0,
        'charmLevel': existing['charmLevel'] ?? 0,
        'vipLevel': existing['vipLevel'] ?? 0,
        'friendsCount': existing['friendsCount'] ?? 0,
        'followersCount': existing['followersCount'] ?? 0,
        'followingCount': existing['followingCount'] ?? 0,
        'verified': existing['verified'] == true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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

    transaction.set(publicRef, {
      'originalAvoraId': nextId,
      'displayName': name,
      'richLevel': 0,
      'charmLevel': 0,
      'vipLevel': 0,
      'friendsCount': 0,
      'followersCount': 0,
      'followingCount': 0,
      'verified': false,
      'updatedAt': FieldValue.serverTimestamp(),
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

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController ambience;

  @override
  void initState() {
    super.initState();
    ambience = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    ambience.dispose();
    super.dispose();
  }

  void _openHome(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const MainShell()),
      (_) => false,
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
          AnimatedBuilder(
            animation: ambience,
            builder: (context, child) => Stack(children: [
              Positioned(
                left: 28 + (ambience.value * 36),
                top: 110 + (ambience.value * 18),
                child: const _WelcomeSpark(icon: Icons.auto_awesome, color: Color(0xFFD8B86A)),
              ),
              Positioned(
                right: 30 + (ambience.value * 20),
                top: 300 - (ambience.value * 24),
                child: const _WelcomeSpark(icon: Icons.music_note, color: Color(0xFFBD8CFF)),
              ),
              Positioned(
                left: 55 + (ambience.value * 18),
                bottom: 310 + (ambience.value * 18),
                child: const _WelcomeSpark(icon: Icons.celebration, color: Color(0xFF63C9FF)),
              ),
            ]),
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
                  const SizedBox(height: 18),
                  const Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _WelcomeFeature(icon: Icons.mic_rounded, label: 'Voice rooms'),
                      _WelcomeFeature(icon: Icons.card_giftcard_rounded, label: 'Gifts'),
                      _WelcomeFeature(icon: Icons.celebration_rounded, label: 'Fun together'),
                    ],
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

class _WelcomeFeature extends StatelessWidget {
  final IconData icon;
  final String label;

  const _WelcomeFeature({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: const Color(0xFFD8B86A)),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      );
}

class _WelcomeSpark extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _WelcomeSpark({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.22), blurRadius: 22)],
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: color.withValues(alpha: 0.72), size: 20),
        ),
      );

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
  bool emailBusy = false;
  bool passwordVisible = false;
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

  Future<void> _signInWithEmail() async {
    if (emailBusy || googleBusy) return;
    if (email.text.trim().isEmpty || password.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your email and password')),
      );
      return;
    }
    setState(() {
      emailBusy = true;
      authProgress = 'Verifying your AVORA account';
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );
      _setProgress('Restoring your AVORA profile');
      await ensureAvoraAccount(onProgress: _setProgress);
      _setProgress('Account ready');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'invalid-email' => 'Enter a valid email address.',
        'user-disabled' =>
          'This account is unavailable. Please contact AVORA support.',
        'too-many-requests' =>
          'Too many attempts. Wait a moment, then try again.',
        _ => 'Email or password is incorrect. Please try again.',
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AVORA could not restore your profile. Please retry.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          emailBusy = false;
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
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: !passwordVisible,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: IconButton(
                tooltip: passwordVisible ? 'Hide password' : 'Show password',
                onPressed: () => setState(
                  () => passwordVisible = !passwordVisible,
                ),
                icon: Icon(
                  passwordVisible ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('email-login-submit'),
            onPressed: googleBusy || emailBusy ? null : _signInWithEmail,
            child: Text(emailBusy ? 'Logging in…' : 'Log in'),
          ),
          OutlinedButton.icon(
            key: const Key('google-login-submit'),
            onPressed: googleBusy || emailBusy ? null : _signInWithGoogle,
            icon: const Icon(Icons.login),
            label: const Text('Continue with Google'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: googleBusy || emailBusy
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
          const Divider(height: 30),
          TextButton(
            key: const Key('open-signup-from-login'),
            onPressed: googleBusy || emailBusy
                ? null
                : () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    ),
            child: const Text('New to AVORA? Create account'),
          ),
        ],
      ),
    );
  }
}


class PolicyDocumentScreen extends StatelessWidget {
  const PolicyDocumentScreen({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'AVORA Demo Policy • Version 2026-08-15',
              style: TextStyle(
                color: Color(0xFFD8B86A),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Text(body, style: const TextStyle(fontSize: 16, height: 1.55)),
            const SizedBox(height: 20),
            const Text(
              'Production release policies will include the final legal, regional, safety, payment, deletion, and store disclosures.',
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
}

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String gender = 'Prefer not to say';
  String selectedCountryCode = 'US';
  String selectedCountryName = 'United States';
  bool passwordVisible = false;
  bool signupBusy = false;
  bool acceptedPolicies = false;
  String? signupProgress;

  final displayName = TextEditingController();
  final invite = TextEditingController();
  final dob = TextEditingController();
  final bio = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _suggestCountry();
  }

  Future<void> _suggestCountry() async {
    final suggested = await AvoraCountrySuggestion.resolve();
    if (!mounted || suggested == null) return;
    Country? match;
    for (final country in CountryService().getAll()) {
      if (country.countryCode.toUpperCase() == suggested) {
        match = country;
        break;
      }
    }
    final selected = match;
    if (selected == null) return;
    setState(() {
      selectedCountryCode = selected.countryCode;
      selectedCountryName = selected.name;
    });
  }

  void _pickCountry() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      countryListTheme: const CountryListThemeData(
        backgroundColor: Color(0xFF100B1C),
        textStyle: TextStyle(color: Colors.white),
        searchTextStyle: TextStyle(color: Colors.white),
        inputDecoration: InputDecoration(
          labelText: 'Search every country',
          prefixIcon: Icon(Icons.search),
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      onSelect: (country) => setState(() {
        selectedCountryCode = country.countryCode;
        selectedCountryName = country.name;
      }),
    );
  }

  void _setSignupProgress(String value) {
    if (!mounted) return;
    setState(() => signupProgress = value);
  }

  Future<void> _signupWithGoogle() async {
    if (signupBusy) return;
    if (!acceptedPolicies) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Accept the AVORA Terms and Privacy Policy to continue.')),
      );
      return;
    }
    setState(() {
      signupBusy = true;
      signupProgress = 'Connecting to Google';
    });
    try {
      final adapter = AvoraGoogleSignInAdapter();
      await adapter.initialize();
      _setSignupProgress('Waiting for Google account');
      final result = await adapter.signIn();
      if (!result.success) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google signup did not complete. Please try again.'),
          ),
        );
        return;
      }
      _setSignupProgress('Google account verified');
      await ensureAvoraAccount(onProgress: _setSignupProgress);
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'policyVersion': 'demo-2026-08-15',
          'policyAcceptedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      _setSignupProgress('Account ready');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainShell()),
        (_) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AVORA could not create your account. Please retry.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          signupBusy = false;
          signupProgress = null;
        });
      }
    }
  }

  @override
  void dispose() {
    displayName.dispose();
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
          if (signupProgress != null) ...[
            Semantics(
              liveRegion: true,
              label: signupProgress,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    const SizedBox.square(
                      dimension: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Text(signupProgress!)),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],
          CheckboxListTile(
            key: const Key('signup-policy-consent'),
            contentPadding: EdgeInsets.zero,
            value: acceptedPolicies,
            onChanged: signupBusy
                ? null
                : (value) => setState(() => acceptedPolicies = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            title: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text('I agree to the '),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PolicyDocumentScreen(
                        title: 'AVORA Terms of Service',
                        body: 'Use AVORA respectfully. Do not abuse, harass, impersonate, defraud, or misuse rooms, accounts, gifts, or test currency. Test coins have no cash value and cannot be withdrawn. AVORA may moderate unsafe activity and protect users, rooms, and the platform.',
                      ),
                    ),
                  ),
                  child: const Text('Terms'),
                ),
                const Text('and'),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PolicyDocumentScreen(
                        title: 'AVORA Privacy Policy',
                        body: 'AVORA uses account, profile, device, room, safety, and transaction information to operate and secure the service. Passwords, OTPs, and authentication tokens are never shown to administrators. Demo and production data remain separated.',
                      ),
                    ),
                  ),
                  child: const Text('Privacy Policy'),
                ),
              ],
            ),
            subtitle: const Text('Demo policy version 2026-08-15'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            key: const Key('google-signup-submit'),
            onPressed: signupBusy ? null : _signupWithGoogle,
            icon: const Icon(Icons.login),
            label: const Text('Continue with Google'),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Row(children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('or create with email'),
              ),
              Expanded(child: Divider()),
            ]),
          ),
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
          InkWell(
            key: const Key('signup-country'),
            onTap: _pickCountry,
            borderRadius: BorderRadius.circular(16),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Country *',
                helperText: 'Suggested from your current network • Tap to change',
                prefixIcon: Icon(Icons.public),
                suffixIcon: Icon(Icons.keyboard_arrow_down),
              ),
              child: Text('$selectedCountryName ($selectedCountryCode)'),
            ),
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
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newUsername],
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Email *'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: password,
            obscureText: !passwordVisible,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.newPassword],
            enableSuggestions: false,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: 'Password *',
              helperText: 'Minimum 6 characters',
              suffixIcon: IconButton(
                tooltip: passwordVisible ? 'Hide password' : 'Show password',
                onPressed: () => setState(
                  () => passwordVisible = !passwordVisible,
                ),
                icon: Icon(
                  passwordVisible ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(
            key: const Key('email-signup-submit'),
            onPressed: signupBusy ? null : () async {
              if (!acceptedPolicies) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Accept the AVORA Terms and Privacy Policy to continue.')),
                );
                return;
              }
              if (displayName.text.trim().isEmpty ||
                  email.text.trim().isEmpty ||
                  password.text.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'Name, country, email and 6+ character password required'),
                  ),
                );
                return;
              }

              setState(() {
                signupBusy = true;
                signupProgress = 'Creating AVORA account';
              });
              try {
                final result =
                    await FirebaseAuth.instance.createUserWithEmailAndPassword(
                  email: email.text.trim(),
                  password: password.text,
                );

                await result.user?.updateDisplayName(displayName.text.trim());

                final account = await ensureAvoraAccount(
                  onProgress: _setSignupProgress,
                );
                _setSignupProgress('Saving profile');
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(result.user!.uid)
                    .set({
                  'displayName': displayName.text.trim(),
                  'gender': gender,
                  'country': selectedCountryName,
                  'countryCode': selectedCountryCode,
                  'invitationCode': invite.text.trim().isEmpty
                      ? null
                      : invite.text.trim(),
                  'dateOfBirth': dob.text.trim().isEmpty ? null : dob.text.trim(),
                  'bio': bio.text.trim().isEmpty ? null : bio.text.trim(),
                  'profileSetupComplete': true,
                  'policyVersion': 'demo-2026-08-15',
                  'policyAcceptedAt': FieldValue.serverTimestamp(),
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
              } finally {
                if (mounted) {
                  setState(() {
                    signupBusy = false;
                    signupProgress = null;
                  });
                }
              }
            },
            child: Text(signupBusy ? 'Creating account…' : 'Create account'),
          ),
          TextButton(
            key: const Key('back-to-login-from-signup'),
            onPressed: signupBusy ? null : () => Navigator.of(context).pop(),
            child: const Text('Already have an account? Log in'),
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
          const CreateHubPage(),
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
                label: 'Discover',
              ),
              NavigationDestination(
                icon: Icon(Icons.add_circle_outline),
                selectedIcon: Icon(Icons.add_circle),
                label: 'Create',
              ),
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline),
                selectedIcon: Icon(Icons.chat_bubble),
                label: 'Inbox',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Me',
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
            tooltip: 'Search rooms',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UserSearchPage()),
            ),
            icon: const Icon(Icons.search),
          ),
          IconButton(
            tooltip: 'Inbox',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MessagesPage()),
            ),
            icon: const Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _HeroCard(),
          const SizedBox(height: 18),
          const SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Chip(label: Text('For You')),
                SizedBox(width: 8),
                Chip(label: Text('Following')),
                SizedBox(width: 8),
                Chip(label: Text('Trending')),
                SizedBox(width: 8),
                Chip(label: Text('New')),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const Text('Discover',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _FeatureTile(
              icon: Icons.mic,
              title: 'Voice Rooms',
              subtitle: 'Join conversations and communities',
              onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RoomsPage()),
                  )),
          const _FeatureTile(
              icon: Icons.videocam,
              title: 'Live',
              subtitle: 'Coming after the audio-first launch'),
          const _FeatureTile(
              icon: Icons.card_giftcard,
              title: 'Rewards',
              subtitle: 'Test rewards unlock in the economy batch'),
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
          Text('Voice • Connect • Celebrate'),
          SizedBox(height: 30),
          Text('Enter a room. Meet your people.'),
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

class CreateHubPage extends StatelessWidget {
  const CreateHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: const LinearGradient(
                colors: [Color(0xFF3B176B), Color(0xFF151027)],
              ),
              border: Border.all(color: const Color(0x55D8B86A)),
            ),
            child: const Column(
              children: [
                Icon(Icons.graphic_eq, size: 54, color: Color(0xFFD8B86A)),
                SizedBox(height: 14),
                Text('Start your AVORA room',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                SizedBox(height: 8),
                Text('Choose a name, theme, privacy and mic-seat layout.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('create-hub-voice-room'),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CreateRoomScreen()),
            ),
            icon: const Icon(Icons.mic),
            label: const Text('Start Voice Room'),
          ),
          const SizedBox(height: 10),
          const ListTile(
            enabled: false,
            leading: Icon(Icons.videocam_outlined),
            title: Text('Start Live'),
            subtitle: Text('Available after the audio-first launch'),
          ),
          const ListTile(
            enabled: false,
            leading: Icon(Icons.sports_esports_outlined),
            title: Text('Start Game'),
            subtitle: Text('Games will be enabled through feature flags'),
          ),
        ],
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
      body: Firebase.apps.isEmpty || FirebaseAuth.instance.currentUser == null
          ? const _RoomFallback()
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('rooms')
                  .where('active', isEqualTo: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const _RoomFallback(
                    message: 'Live rooms could not refresh. Pull back and retry.',
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rooms = snapshot.data!.docs;
                if (rooms.isEmpty) {
                  return const _RoomFallback(
                    message: 'No live rooms yet. Start the first room.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    final data = room.data();
                    return _RoomCard(
                      roomId: room.id,
                      name: (data['name'] ?? 'AVORA Room').toString(),
                      themeName: (data['theme'] ?? 'Aurora').toString(),
                      members: (data['memberCount'] as num?)?.toInt() ?? 1,
                      seatCount: (data['seatCount'] as num?)?.toInt() ?? 10,
                    );
                  },
                );
              },
            ),
    );
  }
}

class _RoomFallback extends StatelessWidget {
  final String? message;
  const _RoomFallback({this.message});

  @override
  Widget build(BuildContext context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (message != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(message!, style: const TextStyle(color: Colors.white70)),
            ),
          const _RoomCard(name: 'Welcome to AVORA', themeName: 'Aurora', members: 1),
        ],
      );
}

class _RoomCard extends StatelessWidget {
  final String? roomId;
  final String name;
  final String themeName;
  final int members;
  final int seatCount;

  const _RoomCard({
    this.roomId,
    required this.name,
    required this.themeName,
    required this.members,
    this.seatCount = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.mic)),
        title: Text(name),
        subtitle: Text('$themeName theme • $members online'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VoiceRoomScreen(
              roomName: name,
              themeName: themeName,
              seatCount: seatCount,
              roomId: roomId,
            ),
          ),
        ),
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
  final roomNameController = TextEditingController();
  String themeName = 'Aurora';
  String privacy = 'Public';
  int seats = 10;
  bool creating = false;

  @override
  void dispose() {
    roomNameController.dispose();
    super.dispose();
  }

  Future<void> createRoom() async {
    final roomName = roomNameController.text.trim();
    if (roomName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a room name.')),
      );
      return;
    }

    if (creating) return;
    setState(() => creating = true);
    String? roomId;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (Firebase.apps.isNotEmpty && user != null) {
        final account = await ensureAvoraAccount();
        final room = FirebaseFirestore.instance.collection('rooms').doc(user.uid);
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final existing = await transaction.get(room);
          if (existing.exists) {
            transaction.update(room, {
              'name': roomName,
              'theme': themeName,
              'privacy': privacy,
              'seatCount': seats,
              'active': true,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          } else {
            transaction.set(room, {
              'name': roomName,
              'theme': themeName,
              'privacy': privacy,
              'seatCount': seats,
              'memberCount': 1,
              'active': true,
              'ownerUid': user.uid,
              'ownerAvoraId': account['originalAvoraId'],
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        });
        roomId = user.uid;
      }
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => creating = false);
      final message = error.code == 'permission-denied'
          ? 'AVORA could not create this room yet. Please retry in a moment.'
          : 'Room could not be saved. Check your connection and retry.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => VoiceRoomScreen(
          roomId: roomId,
          roomName: roomName,
          themeName: themeName,
          seatCount: seats,
          isOwner: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create room')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            key: const Key('create-room-name'),
            controller: roomNameController,
            textInputAction: TextInputAction.next,
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
            key: const Key('create-room-submit'),
            onPressed: creating ? null : createRoom,
            child: Text(creating ? 'Creating room…' : 'Create room'),
          ),
        ],
      ),
    );
  }
}

class VoiceRoomScreen extends StatefulWidget {
  const VoiceRoomScreen({
    super.key,
    required this.roomName,
    required this.themeName,
    required this.seatCount,
    this.isOwner = false,
    this.roomId,
  });

  final String roomName;
  final String themeName;
  final int seatCount;
  final bool isOwner;
  final String? roomId;

  @override
  State<VoiceRoomScreen> createState() => _VoiceRoomScreenState();
}

class _VoiceRoomScreenState extends State<VoiceRoomScreen> {
  bool microphoneEnabled = false;
  bool speakerEnabled = true;
  bool joining = false;
  bool joined = false;
  late int selectedSeat;

  Color get accent => switch (widget.themeName) {
        'Ocean' => const Color(0xFF27D7FF),
        'Night' => const Color(0xFFB56CFF),
        _ => const Color(0xFFFFC861),
      };

  @override
  void initState() {
    super.initState();
    selectedSeat = widget.isOwner ? 0 : -1;
    unawaited(_joinRoom());
  }

  @override
  void dispose() {
    unawaited(_leaveRoom());
    super.dispose();
  }

  Future<void> _joinRoom() async {
    final roomId = widget.roomId;
    if (roomId == null || Firebase.apps.isEmpty) {
      if (mounted) setState(() => joined = true);
      return;
    }
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => joined = false);
      return;
    }
    if (mounted) setState(() => joining = true);
    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('members')
          .doc(user.uid)
          .set({
        'userUid': user.uid,
        'displayName': user.displayName ?? 'AVORA User',
        'photoUrl': user.photoURL,
        'seatIndex': selectedSeat,
        'joinedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) setState(() => joined = true);
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AVORA could not join the room. Tap reconnect.')),
      );
    } finally {
      if (mounted) setState(() => joining = false);
    }
  }

  Future<void> _leaveRoom() async {
    final roomId = widget.roomId;
    if (roomId == null || Firebase.apps.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('members')
          .doc(user.uid)
          .delete();
    } catch (_) {
      // Presence expires through the backend recovery path when a device drops.
    }
  }

  Future<void> _selectSeat(int index) async {
    if (index == 0 && !widget.isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The host seat is reserved for the room owner.')),
      );
      return;
    }
    final nextSeat = selectedSeat == index && !widget.isOwner ? -1 : index;
    setState(() => selectedSeat = nextSeat);
    final roomId = widget.roomId;
    if (roomId == null || Firebase.apps.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('members')
          .doc(user.uid)
          .set({
        'userUid': user.uid,
        'seatIndex': nextSeat,
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seat could not be updated. Please retry.')),
      );
    }
  }

  void _openChat() {
    if (widget.roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create or join a saved room to use room chat.')),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF100C1A),
      builder: (_) => RoomChatSheet(roomId: widget.roomId!),
    );
  }

  Future<void> _openRoomControls() async {
    final roomId = widget.roomId;
    if (!widget.isOwner || roomId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room controls are available to the room owner.')),
      );
      return;
    }
    final endRoom = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: const Color(0xFF100C1A),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const ListTile(
              leading: Icon(Icons.admin_panel_settings_outlined),
              title: Text('Owner room controls'),
              subtitle: Text('Moderation and seat controls will expand here.'),
            ),
            ListTile(
              key: const Key('end-room-action'),
              leading: const Icon(Icons.stop_circle_outlined, color: Colors.redAccent),
              title: const Text('End room'),
              onTap: () => Navigator.pop(context, true),
            ),
          ]),
        ),
      ),
    );
    if (endRoom != true || !mounted) return;
    try {
      await FirebaseFirestore.instance.collection('rooms').doc(roomId).update({
        'active': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (mounted) Navigator.of(context).pop();
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Room could not be ended. Please retry.')),
      );
    }
  }

  Widget _presenceLabel() {
    final roomId = widget.roomId;
    if (roomId == null || Firebase.apps.isEmpty) {
      return Text(joined ? 'Demo room • connected' : 'Connecting…');
    }
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('rooms')
          .doc(roomId)
          .collection('members')
          .snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length;
        return Text(
          joining
              ? 'Connecting…'
              : joined
                  ? '${count ?? 1} in room • connected'
                  : 'Connection interrupted • tap reconnect',
          style: TextStyle(
            color: joined ? Colors.greenAccent : Colors.amberAccent,
            fontSize: 12,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF07050D),
      body: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.15,
                colors: [accent.withValues(alpha: 0.24), const Color(0xFF07050D)],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.keyboard_arrow_down),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.roomName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                            ),
                            _presenceLabel(),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const Key('room-reconnect'),
                        tooltip: 'Reconnect',
                        onPressed: joining ? null : _joinRoom,
                        icon: Icon(joined ? Icons.cloud_done_outlined : Icons.sync),
                      ),
                      IconButton(
                        key: const Key('room-owner-controls'),
                        onPressed: _openRoomControls,
                        icon: const Icon(Icons.more_horiz),
                      ),
                    ],
                  ),
                ),
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accent.withValues(alpha: 0.24)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.campaign_outlined, size: 18),
                      SizedBox(width: 8),
                      Expanded(child: Text('Welcome to AVORA • Be kind and enjoy the room')),
                    ],
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    key: const Key('voice-room-seats'),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: widget.seatCount,
                    itemBuilder: (context, index) {
                      final active = selectedSeat == index;
                      return InkWell(
                        key: Key('voice-seat-$index'),
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => _selectSeat(index),
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              width: 58,
                              height: 58,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: active
                                    ? accent.withValues(alpha: 0.20)
                                    : Colors.white.withValues(alpha: 0.06),
                                border: Border.all(
                                  color: active ? accent : Colors.white24,
                                  width: active ? 2.2 : 1,
                                ),
                                boxShadow: active
                                    ? [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 18)]
                                    : null,
                              ),
                              child: Icon(
                                index == 0
                                    ? Icons.workspace_premium
                                    : active
                                        ? Icons.person
                                        : Icons.add,
                              ),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              index == 0
                                  ? 'Host'
                                  : active
                                      ? 'You'
                                      : 'Seat ${index + 1}',
                              maxLines: 1,
                              style: const TextStyle(fontSize: 11, color: Colors.white70),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF100C1A).withValues(alpha: 0.96),
                    border: const Border(top: BorderSide(color: Colors.white12)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _RoomControl(
                        key: const Key('voice-room-chat'),
                        icon: Icons.chat_bubble_outline,
                        label: 'Chat',
                        onTap: _openChat,
                      ),
                      _RoomControl(
                        icon: microphoneEnabled ? Icons.mic : Icons.mic_off,
                        label: microphoneEnabled ? 'Mic on' : 'Mic off',
                        active: microphoneEnabled,
                        key: const Key('voice-room-mic'),
                        onTap: () => setState(() => microphoneEnabled = !microphoneEnabled),
                      ),
                      _RoomControl(
                        icon: speakerEnabled ? Icons.volume_up : Icons.volume_off,
                        label: speakerEnabled ? 'Speaker' : 'Muted',
                        active: speakerEnabled,
                        onTap: () => setState(() => speakerEnabled = !speakerEnabled),
                      ),
                      _RoomControl(
                        icon: Icons.card_giftcard,
                        label: 'Gifts',
                        onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Test gifts are in the next economy batch.')),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class RoomChatSheet extends StatefulWidget {
  const RoomChatSheet({super.key, required this.roomId});
  final String roomId;

  @override
  State<RoomChatSheet> createState() => _RoomChatSheetState();
}

class _RoomChatSheetState extends State<RoomChatSheet> {
  final message = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = message.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (text.isEmpty || user == null || sending) return;
    setState(() => sending = true);
    try {
      await FirebaseFirestore.instance
          .collection('rooms')
          .doc(widget.roomId)
          .collection('messages')
          .add({
        'senderUid': user.uid,
        'senderName': user.displayName ?? 'AVORA User',
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });
      message.clear();
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message could not be sent. Please retry.')),
      );
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 14,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 14,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.62,
          child: Column(
            children: [
              const Text('Room chat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('rooms')
                      .doc(widget.roomId)
                      .collection('messages')
                      .orderBy('createdAt', descending: true)
                      .limit(50)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Center(child: Text('Chat could not refresh.'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data!.docs;
                    if (messages.isEmpty) {
                      return const Center(child: Text('Start the conversation.'));
                    }
                    return ListView.builder(
                      reverse: true,
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final data = messages[index].data();
                        return ListTile(
                          dense: true,
                          title: Text((data['senderName'] ?? 'AVORA User').toString()),
                          subtitle: Text((data['text'] ?? '').toString()),
                        );
                      },
                    );
                  },
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('room-chat-message'),
                      controller: message,
                      maxLength: 300,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Message the room',
                        counterText: '',
                      ),
                    ),
                  ),
                  IconButton.filled(
                    key: const Key('room-chat-send'),
                    onPressed: sending ? null : _send,
                    icon: sending
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
}

class _RoomControl extends StatelessWidget {
  const _RoomControl({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.active = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: active ? const Color(0xFFFFC861) : Colors.white),
            const SizedBox(height: 3),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key});

  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage> {
  int section = 0;

  static const sections = <({IconData icon, String label, String title, String body})>[
    (icon: Icons.notifications_none, label: 'Notifications', title: 'Your activity', body: 'Follows, gifts, room invites and rewards will appear here.'),
    (icon: Icons.campaign_outlined, label: 'System', title: 'System notices', body: 'Security, policy, maintenance and official AVORA notices.'),
    (icon: Icons.support_agent, label: 'Support', title: 'Contact AVORA', body: 'Report a problem or request help from the AVORA support team.'),
    (icon: Icons.chat_bubble_outline, label: 'Chats', title: 'Messages', body: 'Friend conversations and message requests will appear here.'),
  ];

  @override
  Widget build(BuildContext context) {
    final selected = sections[section];
    return Scaffold(
      appBar: AppBar(title: const Text('Inbox')),
      body: Column(
        children: [
          SizedBox(
            height: 88,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemCount: sections.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final item = sections[index];
                return ChoiceChip(
                  key: Key('inbox-section-$index'),
                  selected: section == index,
                  onSelected: (_) => setState(() => section = index),
                  avatar: Icon(item.icon, size: 18),
                  label: Text(item.label),
                );
              },
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _InboxSection(
                key: ValueKey(section),
                icon: selected.icon,
                title: selected.title,
                body: selected.body,
                support: section == 2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxSection extends StatelessWidget {
  const _InboxSection({super.key, required this.icon, required this.title, required this.body, required this.support});
  final IconData icon;
  final String title;
  final String body;
  final bool support;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 20),
      children: [
        Icon(icon, size: 54, color: const Color(0xFFD8B86A)),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(body, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
        if (support) ...[
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const Key('contact-avora'),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ContactAvoraScreen())),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Create support request'),
          ),
        ],
      ],
    );
  }
}

class ContactAvoraScreen extends StatefulWidget {
  const ContactAvoraScreen({super.key});
  @override
  State<ContactAvoraScreen> createState() => _ContactAvoraScreenState();
}

class _ContactAvoraScreenState extends State<ContactAvoraScreen> {
  final subject = TextEditingController();
  final message = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (subject.text.trim().isEmpty || message.text.trim().length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add a subject and at least 10 message characters.')));
      return;
    }
    setState(() => sending = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('not_signed_in');
      await FirebaseFirestore.instance.collection('supportTickets').add({
        'userUid': user.uid,
        'subject': subject.text.trim(),
        'message': message.text.trim(),
        'status': 'open',
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Support request sent successfully.')));
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not send your request. Please try again.')));
    } finally {
      if (mounted) setState(() => sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact AVORA')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(key: const Key('support-subject'), controller: subject, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Subject')),
          const SizedBox(height: 12),
          TextField(key: const Key('support-message'), controller: message, minLines: 5, maxLines: 8, decoration: const InputDecoration(labelText: 'How can we help?')),
          const SizedBox(height: 18),
          FilledButton.icon(
            key: const Key('support-submit'),
            onPressed: sending ? null : submit,
            icon: sending ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send),
            label: Text(sending ? 'Sending…' : 'Send request'),
          ),
        ],
      ),
    );
  }
}

class UserSearchPage extends StatefulWidget {
  const UserSearchPage({super.key});

  @override
  State<UserSearchPage> createState() => _UserSearchPageState();
}

class _UserSearchPageState extends State<UserSearchPage> {
  final query = TextEditingController();
  bool searching = false;
  String? error;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> results = const [];

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> search() async {
    final value = query.text.trim();
    if (value.isEmpty || searching) return;
    FocusScope.of(context).unfocus();
    setState(() {
      searching = true;
      error = null;
      results = const [];
    });
    try {
      final lookup = int.tryParse(value) ?? value;
      final snapshot = await FirebaseFirestore.instance
          .collection('publicProfiles')
          .where('originalAvoraId', isEqualTo: lookup)
          .limit(10)
          .get();
      if (!mounted) return;
      setState(() {
        results = snapshot.docs;
        error = snapshot.docs.isEmpty ? 'No AVORA account found for this ID.' : null;
      });
    } on FirebaseException catch (firebaseError) {
      if (!mounted) return;
      setState(() {
        error = firebaseError.code == 'permission-denied'
            ? 'AVORA could not complete this search yet. Please retry in a moment.'
            : 'Search could not be completed. Please retry.';
      });
    } finally {
      if (mounted) setState(() => searching = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Search AVORA ID')),
        body: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            TextField(
              key: const Key('user-search-field'),
              controller: query,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => search(),
              decoration: InputDecoration(
                labelText: 'AVORA ID',
                hintText: 'Example: 10000003',
                prefixIcon: const Icon(Icons.badge_outlined),
                suffixIcon: IconButton(
                  key: const Key('user-search-submit'),
                  tooltip: 'Search',
                  onPressed: searching ? null : search,
                  icon: searching
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                ),
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.only(top: 22),
                child: Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
              ),
            ...results.map((document) {
              final account = document.data();
              final name = (account['displayName'] ?? 'AVORA User').toString();
              final official = account['isOfficial'] == true || account['verified'] == true;
              return Card(
                margin: const EdgeInsets.only(top: 14),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundImage: avoraProfileImage(account),
                    child: hasAvoraProfileImage(account)
                        ? null
                        : const Icon(Icons.person),
                  ),
                  title: Row(children: [
                    Flexible(child: Text(name)),
                    if (official) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.verified, color: Color(0xFF63C9FF), size: 18),
                    ],
                  ]),
                  subtitle: Text('ID ${account['originalAvoraId'] ?? '—'} • ${official ? 'OFFICIAL' : 'USER'}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => PublicProfilePage(account: account)),
                  ),
                ),
              );
            }),
          ],
        ),
      );
}


ImageProvider<Object>? avoraProfileImage(Map<String, dynamic> account) {
  final dataUrl = account['photoDataUrl'] as String?;
  if (dataUrl != null && dataUrl.contains(',')) {
    try {
      return MemoryImage(base64Decode(dataUrl.split(',').last));
    } on FormatException {
      return null;
    }
  }
  final url = account['photoUrl'] as String?;
  return url != null && url.isNotEmpty ? NetworkImage(url) : null;
}

bool hasAvoraProfileImage(Map<String, dynamic> account) =>
    avoraProfileImage(account) != null;

class PublicProfilePage extends StatelessWidget {
  final Map<String, dynamic> account;
  const PublicProfilePage({super.key, required this.account});

  @override
  Widget build(BuildContext context) {
    final avoraId = (account['originalAvoraId'] ?? '—').toString();
    final name = (account['displayName'] ?? 'AVORA User').toString();
    final official = account['isOfficial'] == true || account['verified'] == true;
    final richLevel = (account['richLevel'] as num?)?.toInt() ?? 0;
    final charmLevel = (account['charmLevel'] as num?)?.toInt() ?? 0;
    return Scaffold(
      appBar: AppBar(title: const Text('AVORA Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 52,
            backgroundImage: avoraProfileImage(account),
            child: hasAvoraProfileImage(account)
                ? null
                : const AvoraLogo(size: 76),
          ),
          const SizedBox(height: 14),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(name, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            if (official) ...[
              const SizedBox(width: 7),
              const Icon(Icons.verified, color: Color(0xFF63C9FF)),
            ],
          ]),
          const SizedBox(height: 8),
          Center(
            child: ActionChip(
              avatar: const Icon(Icons.copy, size: 16),
              label: Text('ID $avoraId • ${official ? 'OFFICIAL' : 'USER'}'),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: avoraId));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AVORA ID copied')));
              },
            ),
          ),
          const SizedBox(height: 22),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _Stat(value: '$richLevel', label: 'Rich Level'),
            _Stat(value: '$charmLevel', label: 'Charm Level'),
            _Stat(value: (account['vipLevel'] ?? 0).toString(), label: 'VIP'),
          ]),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
            _Stat(value: (account['friendsCount'] ?? 0).toString(), label: 'Friends'),
            _Stat(value: (account['followersCount'] ?? 0).toString(), label: 'Followers'),
            _Stat(value: (account['followingCount'] ?? 0).toString(), label: 'Following'),
          ]),
          const SizedBox(height: 22),
          if ((account['bio'] as String?)?.trim().isNotEmpty == true)
            Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(account['bio'] as String))),
        ],
      ),
    );
  }
}

class ProfilePage extends StatefulWidget {
  final Map<String, dynamic> account;

  const ProfilePage({super.key, required this.account});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Map<String, dynamic> account;
  bool savingPhoto = false;

  @override
  void initState() {
    super.initState();
    account = Map<String, dynamic>.from(widget.account);
  }

  Future<void> _changePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || savingPhoto) return;
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 55,
      maxWidth: 384,
      maxHeight: 384,
    );
    if (image == null || !mounted) return;
    setState(() => savingPhoto = true);
    try {
      final bytes = await File(image.path).readAsBytes();
      if (bytes.length > 650000) {
        throw const FormatException('Selected photo is too large');
      }
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      final batch = FirebaseFirestore.instance.batch();
      batch.set(FirebaseFirestore.instance.collection('users').doc(user.uid), {
        'photoDataUrl': dataUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(FirebaseFirestore.instance.collection('publicProfiles').doc(user.uid), {
        'photoDataUrl': dataUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await batch.commit();
      if (mounted) setState(() => account['photoDataUrl'] = dataUrl);
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profile photo could not be saved. Choose a smaller photo and retry.'),
      ));
    } finally {
      if (mounted) setState(() => savingPhoto = false);
    }
  }

  Future<void> _editProfile() async {
    final name = TextEditingController(text: (account['displayName'] ?? '').toString());
    final bio = TextEditingController(text: (account['bio'] ?? '').toString());
    var countryName = (account['country'] ?? 'Select country').toString();
    var countryCode = (account['countryCode'] ?? '').toString();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit profile'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, maxLength: 30, decoration: const InputDecoration(labelText: 'Display name')),
              TextField(controller: bio, maxLength: 160, maxLines: 3, decoration: const InputDecoration(labelText: 'Bio')),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.public),
                title: Text(countryName),
                subtitle: const Text('Country'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => showCountryPicker(
                  context: context,
                  onSelect: (country) => setDialogState(() {
                    countryName = country.name;
                    countryCode = country.countryCode;
                  }),
                ),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Save')),
          ],
        ),
      ),
    );
    if (saved != true || name.text.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await user.updateDisplayName(name.text.trim());
      final changes = <String, dynamic>{
        'displayName': name.text.trim(),
        'bio': bio.text.trim(),
        'country': countryName,
        'countryCode': countryCode,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final batch = FirebaseFirestore.instance.batch();
      batch.set(
        FirebaseFirestore.instance.collection('users').doc(user.uid),
        changes,
        SetOptions(merge: true),
      );
      batch.set(
        FirebaseFirestore.instance.collection('publicProfiles').doc(user.uid),
        {
          'displayName': name.text.trim(),
          'bio': bio.text.trim(),
          'country': countryName,
          'countryCode': countryCode,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await batch.commit();
      if (mounted) setState(() => account.addAll(changes));
    } on FirebaseException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile could not be saved. Please retry.')));
    }
  }

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
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [IconButton(key: const Key('edit-profile'), tooltip: 'Edit profile', onPressed: _editProfile, icon: const Icon(Icons.edit_outlined))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Center(
            child: Stack(children: [
              CircleAvatar(
                radius: 48,
                backgroundColor: const Color(0xFF5D36A3),
                backgroundImage: avoraProfileImage(account),
                child: hasAvoraProfileImage(account)
                    ? null
                    : const AvoraLogo(size: 72),
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: IconButton.filled(
                  key: const Key('change-profile-photo'),
                  tooltip: 'Change profile photo',
                  onPressed: savingPhoto ? null : _changePhoto,
                  icon: savingPhoto
                      ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.camera_alt, size: 18),
                ),
              ),
            ]),
          ),
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
            child: InkWell(
              key: const Key('copy-avora-id'),
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: avoraId.toString()));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('AVORA ID copied')),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ID: $avoraId',
                      style: const TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    const SizedBox(width: 7),
                    const Icon(Icons.copy, size: 16, color: Colors.white60),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(child: Chip(label: Text(role))),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _Stat(value: (account['friendsCount'] ?? 0).toString(), label: 'Friends'),
              _Stat(value: (account['followersCount'] ?? 0).toString(), label: 'Followers'),
              _Stat(value: (account['followingCount'] ?? 0).toString(), label: 'Following'),
              _Stat(value: (account['visitorsCount'] ?? 0).toString(), label: 'Visitors'),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(value: (account['richLevel'] ?? 0).toString(), label: 'Rich Level'),
              _Stat(value: (account['charmLevel'] ?? 0).toString(), label: 'Charm Level'),
              _Stat(value: (account['vipLevel'] ?? 0).toString(), label: 'VIP'),
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
            key: const Key('sign-out-button'),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => const AvoraSignOutConfirmationDialog(),
              );
              if (confirmed != true || !context.mounted) return;
              await FirebaseAuth.instance.signOut();
              await AvoraGoogleSignInAdapter().signOut();
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

class AvoraSignOutConfirmationDialog extends StatelessWidget {
  const AvoraSignOutConfirmationDialog({super.key});

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Sign out of AVORA?'),
        content: const Text(
          'Your permanent AVORA ID and profile will stay safe. You can log in again anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Stay logged in'),
          ),
          FilledButton(
            key: const Key('confirm-sign-out'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      );
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
