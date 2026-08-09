
import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const AvoraApp());
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
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
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
                      MaterialPageRoute(builder: (_) => LoginScreen(onDemoLogin: () => _openHome(context))),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Text('Log in'),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Social sign-in will be connected after Firebase Auth setup.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.white60),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoginScreen extends StatelessWidget {
  final VoidCallback onDemoLogin;
  const LoginScreen({super.key, required this.onDemoLogin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log in')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const TextField(
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          const TextField(
            obscureText: true,
            decoration: InputDecoration(labelText: 'Password'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: onDemoLogin,
            child: const Text('Continue — demo'),
          ),
          TextButton(
            onPressed: () {},
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const TextField(
            decoration: InputDecoration(labelText: 'Display name *'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: gender,
            decoration: const InputDecoration(labelText: 'Gender'),
            items: const [
              DropdownMenuItem(value: 'Male', child: Text('Male')),
              DropdownMenuItem(value: 'Female', child: Text('Female')),
              DropdownMenuItem(value: 'Prefer not to say', child: Text('Prefer not to say')),
            ],
            onChanged: (v) => setState(() => gender = v ?? gender),
          ),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(labelText: 'Country *'),
          ),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(labelText: 'Invitation code (optional)'),
          ),
          const SizedBox(height: 12),
          const TextField(
            decoration: InputDecoration(labelText: 'Date of birth (optional)'),
          ),
          const SizedBox(height: 12),
          const TextField(
            maxLines: 3,
            decoration: InputDecoration(labelText: 'Bio (optional)'),
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const MainShell()),
                (_) => false,
              );
            },
            child: const Text('Create demo profile'),
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

  final pages = const [
    HomePage(),
    RoomsPage(),
    MessagesPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.mic_none), selectedIcon: Icon(Icons.mic), label: 'Rooms'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
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
          Text('Discover', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          SizedBox(height: 10),
          _FeatureTile(icon: Icons.mic, title: 'Voice Rooms', subtitle: 'Join conversations and communities'),
          _FeatureTile(icon: Icons.videocam, title: 'Live', subtitle: 'Video and interactive live rooms — planned'),
          _FeatureTile(icon: Icons.card_giftcard, title: 'Rewards', subtitle: 'Tasks, levels and rewards — planned'),
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
          Text('AVORA', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
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
              DropdownMenuItem(value: 'Approval', child: Text('Approval required')),
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
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: AvoraLogo(size: 92)),
          const SizedBox(height: 14),
          const Center(
            child: Text('AVORA User', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
          ),
          const Center(child: Text('ID: demo')),
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
          const _FeatureTile(icon: Icons.account_balance_wallet, title: 'Wallet', subtitle: 'Economy module — planned'),
          const _FeatureTile(icon: Icons.workspace_premium, title: 'VIP / Levels', subtitle: 'Configurable system — planned'),
          const _FeatureTile(icon: Icons.groups, title: 'Family / CP', subtitle: 'Relationship module — planned'),
          const _FeatureTile(icon: Icons.settings, title: 'Settings', subtitle: 'Privacy, audio and app preferences'),
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
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.white70)),
      ],
    );
  }
}
