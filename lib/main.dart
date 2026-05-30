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
import 'utils/time_utils.dart';

/// Global navigator key so PushNotificationService can route from background.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
bool _servicesInitialized = false;

Future<void> _initializeAppServices() async {
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } on FirebaseException catch (e) {
      if (e.code != 'duplicate-app') {
        rethrow;
      }
    }
  }

  if (_servicesInitialized) {
    return;
  }

  await PushNotificationService.initialize(navigatorKey: navigatorKey);
  _servicesInitialized = true;
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeAppServices();
  TimeUtils.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildLightTheme() {
    final colorScheme = ColorScheme.fromSeed(seedColor: Colors.deepPurple);
    return ThemeData(
      colorScheme: colorScheme,
      useMaterial3: true,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontWeight: FontWeight.w500),
        bodyMedium: TextStyle(fontWeight: FontWeight.w500),
        titleLarge: TextStyle(fontWeight: FontWeight.bold),
        titleMedium: TextStyle(fontWeight: FontWeight.bold),
        titleSmall: TextStyle(fontWeight: FontWeight.bold),
      ),
      appBarTheme: const AppBarTheme(elevation: 0, centerTitle: true),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
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
      scaffoldBackgroundColor: const Color(0xFF0F1116),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(fontWeight: FontWeight.w500, color: Colors.white),
        bodyMedium: TextStyle(
          fontWeight: FontWeight.w500,
          color: Colors.white70,
        ),
        titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        titleMedium: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        titleSmall: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F1116),
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1A1D23),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF2D323C)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
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
