import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/push_notification_service.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/change_password_screen.dart';
import 'screens/main_app.dart';
import 'screens/create_post_screen.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/edit_post_screen.dart';
import 'screens/trending_screen.dart';
import 'models/post_model.dart';
import 'firebase_options.dart';

/// Global navigator key so PushNotificationService can route from background.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await PushNotificationService.initialize(navigatorKey: navigatorKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.deepPurple,
      brightness: Brightness.dark,
    );
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [Provider<AuthService>(create: (_) => AuthService())],
      child: MaterialApp(
        title: 'Starpage',
        navigatorKey: navigatorKey,
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        themeMode: ThemeMode.system,
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignUpScreen(),
          '/create-post': (context) => const CreatePostScreen(),
          '/edit-profile': (context) => const EditProfileScreen(),
          '/trending': (context) => const TrendingScreen(),
          '/forgot-password': (context) => const ForgotPasswordScreen(),
          '/change-password': (context) => const ChangePasswordScreen(),
          '/notifications': (context) => const MainApp(initialIndex: 4),
          '/messages': (context) => const MainApp(initialIndex: 3),
        },
        onGenerateRoute: (settings) {
          if (settings.name == '/edit-post') {
            if (settings.arguments == null) {
              debugPrint('ERROR: /edit-post called with null arguments');
              return null;
            }
            try {
              final post = settings.arguments as PostModel;
              debugPrint('Opening EditPostScreen for post: ${post.postId}');
              return MaterialPageRoute(
                builder: (context) => EditPostScreen(post: post),
              );
            } catch (e) {
              debugPrint('ERROR casting arguments to PostModel: $e');
              return null;
            }
          }
          return null;
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Avoid visible delay: route immediately using cached auth state.
          if (currentUser != null) {
            return const MainApp();
          }
          return const LoginScreen();
        }

        if (snapshot.hasData && snapshot.data != null) {
          return const MainApp();
        }

        return const LoginScreen();
      },
    );
  }
}
