import 'package:flutter/material.dart';
import 'package:fraudguard_pay/database/initialise_database.dart';
import 'package:fraudguard_pay/models/app_state_model.dart';
import 'constants/colors.dart';
import 'screens/navigation/main_navigation_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDatabaseData();
  await initializeGlobalData();
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
      home: const MainNavigationScreen(),
    );
  }
}
