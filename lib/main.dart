import 'package:flutter/material.dart';
import 'package:fraudguard_pay/database/initialise_database.dart';
import 'package:fraudguard_pay/services/user_manager.dart';
import 'package:fraudguard_pay/screens/server_config/server_config_screen.dart';
import 'package:fraudguard_pay/screens/login/login_screen.dart';
import 'package:fraudguard_pay/screens/navigation/main_navigation_screen.dart';
import 'package:fraudguard_pay/config/theme.dart';
import 'package:fraudguard_pay/services/api_service.dart';
import 'package:fraudguard_pay/utils/settings_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDatabaseData();

  runApp(const FGPayApp());
}

class FGPayApp extends StatelessWidget {
  const FGPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FG Pay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      // Define all routes
      initialRoute: '/',
      routes: {
        '/': (context) => const AppInitializer(),
        'login': (context) => const LoginScreen(),
        'home': (context) => const MainNavigationScreen(),
        'server_config': (context) => const ServerConfigScreen(),
      },
      // Fallback for any unknown routes
      onUnknownRoute: (settings) {
        return MaterialPageRoute(builder: (context) => const AppInitializer());
      },
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool _isLoading = true;
  String? _initialRoute;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Step 1: Check if server URL is configured
    final endpoint = await SettingsManager.getApiEndpoint();
    final isUrlConfigured =
        endpoint.isNotEmpty && endpoint != SettingsManager.defaultApiEndpoint;

    if (!isUrlConfigured) {
      setState(() {
        _initialRoute = 'server_config';
        _isLoading = false;
      });
      return;
    }

    // Step 2: Test server connection
    final apiService = ApiService();
    final isServerReachable = await apiService.healthCheck();

    if (!isServerReachable) {
      _showServerErrorDialog();
      return;
    }

    // Step 3: Check if user is logged in
    final customerId = await UserManager.getCustomerId();

    setState(() {
      _initialRoute = customerId != null ? 'home' : 'login';
      _isLoading = false;
    });
  }

  void _showServerErrorDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Server Unreachable'),
            content: const Text(
              'Cannot connect to the server at the configured URL.\n\n'
              'Please check your network connection and server URL.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() {
                    _initialRoute = 'server_config';
                    _isLoading = false;
                  });
                },
                child: const Text('Reconfigure URL'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Navigate to the appropriate screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_initialRoute != null) {
        Navigator.pushReplacementNamed(context, _initialRoute!);
      }
    });

    return const SizedBox.shrink();
  }
}
