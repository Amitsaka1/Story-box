import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:my_app/providers/auth_provider.dart';
import 'package:my_app/providers/theme_provider.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('en'),
        Locale('hi'),
        Locale('bn'),
        Locale('ta'),
        Locale('te'),
        Locale('mr'),
        Locale('gu'),
        Locale('kn'),
        Locale('ml'),
        Locale('pa'),
        Locale('ur'),
      ],
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      // startLocale intentionally omitted -- when it's not set,
      // easy_localization auto-detects the phone's system language on
      // first launch, then remembers whatever the user picks after that.
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()..tryRestoreSession()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()..loadSavedTheme()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Story Box',
            localizationsDelegates: context.localizationDelegates,
            supportedLocales: context.supportedLocales,
            locale: context.locale,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.deepPurple,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: themeProvider.themeMode,
            home: const AuthGate(),
          );
        },
      ),
    );
  }
}

/// App khulte hi decide karta hai: token save hai to seedha Dashboard
/// (proof ki backend se connected user hai), warna Login screen.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (auth.isRestoring) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (auth.isLoggedIn) {
      return const SettingsScreen();
    }
    return const LoginScreen();
  }
}
