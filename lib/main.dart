import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  // REQUIRED FOR v7+: Initialize the singleton
  await GoogleSignIn.instance.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Firebase OAuth App v7',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const AuthGate(),
    );
  }
}

/// Listens to the auth state and shows the appropriate screen.
class AuthGate extends StatelessWidget {
  const AuthGate({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        
        if (snapshot.hasData) {
          return HomeScreen(user: snapshot.data!);
        }

        return const LoginScreen();
      },
    );
  }
}

/// The login screen handling the v7 OAuth flow.
class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  Future<void> signInWithGoogle() async {
    try {
      final googleSignIn = GoogleSignIn.instance;

      // 1. Authentication (Identity)
      // This triggers the modern Credential Manager / account picker sheet
      final GoogleSignInAccount? googleUser = await googleSignIn.authenticate();

      if (googleUser == null) {
        return; // The user canceled the sign-in
      }

      // 2. Get the ID token from the authentication phase
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Authorization (Permissions)
      // REQUIRED FOR FIREBASE: Explicitly request scopes to get the Access Token
      final clientAuth = await googleUser.authorizationClient.authorizeScopes(['email', 'profile']);

      // 4. Create the Firebase credential using both tokens
      final AuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: clientAuth.accessToken,
      );

      // 5. Sign in to Firebase
      await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      debugPrint("Error during Google Sign-In v7: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: signInWithGoogle,
          icon: const Icon(Icons.login),
          label: const Text('Sign in with Google'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
    );
  }
}

/// The home screen shown after a successful login.
class HomeScreen extends StatelessWidget {
  final User user;

  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              // Sign out using the singleton instance
              await GoogleSignIn.instance.signOut();
              await FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (user.photoURL != null)
              CircleAvatar(
                backgroundImage: NetworkImage(user.photoURL!),
                radius: 40,
              ),
            const SizedBox(height: 16),
            Text(
              'Welcome, ${user.displayName ?? 'User'}!',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(user.email ?? ''),
          ],
        ),
      ),
    );
  }
}