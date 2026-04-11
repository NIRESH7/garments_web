import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:garments/screens/dashboard/dashboard_screen.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/splash/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: TextileLotManagementApp()));
}

class TextileLotManagementApp extends ConsumerWidget {
  const TextileLotManagementApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = ref.watch(themeProvider);

    return MaterialApp(
      title: 'Om Vinayaka Garments - Web Dashboard',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(primaryColor),
      initialRoute: kIsWeb ? '/login' : '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/dashboard': (context) => const DashboardScreen(),
      },
      builder: (context, child) {
        if (child == null) return const SizedBox.shrink();
        final data = MediaQuery.maybeOf(context);
        return MediaQuery(
          data: (data ?? const MediaQueryData()).copyWith(
            textScaleFactor: 1.0,
          ),
          child: child,
        );
      },
    );
  }
}
