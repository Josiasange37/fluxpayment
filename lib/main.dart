import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'theme/app_colors.dart';
import 'services/api_service.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/shell_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fluxpay',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primary,
          surface: AppColors.surface,
        ),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.surfaceBorder),
          ),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final ApiService _apiService = ApiService();
  bool _isLoading = true;
  bool _isLoggedIn = false;
  bool _onboardingComplete = false;
  String _useCase = 'subscriptions';

  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    await _apiService.init();

    if (_apiService.token == null) {
      if (mounted) setState(() { _isLoading = false; _isLoggedIn = false; });
      return;
    }

    final prefs = await _apiService.getPreferences();
    final complete = prefs['onboarding_complete'] == true;
    final useCase = prefs['use_case'] ?? 'subscriptions';
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isLoggedIn = true;
        _onboardingComplete = complete;
        _useCase = useCase;
      });
    }
  }

  void _onLoginSuccess() => _checkAuth();

  void _onOnboardingSuccess() => setState(() { _onboardingComplete = true; });

  void _onLogout() => setState(() { _isLoggedIn = false; _onboardingComplete = false; });

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (!_isLoggedIn) {
      return LoginScreen(
        apiService: _apiService,
        onLoginSuccess: _onLoginSuccess,
      );
    }

    if (!_onboardingComplete) {
      return OnboardingScreen(
        apiService: _apiService,
        onOnboardingSuccess: _onOnboardingSuccess,
      );
    }

    return ShellScreen(
      apiService: _apiService,
      useCase: _useCase,
      onLogout: _onLogout,
    );
  }
}
