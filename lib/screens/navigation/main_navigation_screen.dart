import 'package:flutter/material.dart';
import 'package:fraudguard_pay/config/theme.dart';
import 'package:fraudguard_pay/screens/home/home_screen.dart';
import 'package:fraudguard_pay/screens/money/money_screen.dart';
import 'package:fraudguard_pay/screens/fraud/fraudguard_summary_screen.dart';
import 'package:fraudguard_pay/screens/profile/profile_screen.dart';

/// Main navigation hub with bottom tabs.
/// Flows: App Entry → Main Navigation (never leaves) → All Screens
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const MoneyScreen(),
    const FraudGuardSummaryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: primaryDark,
        selectedItemColor: accentOrange,
        unselectedItemColor: textSecondary,
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.money), label: "Money"),
          BottomNavigationBarItem(
            icon: Icon(Icons.security),
            label: "FG Shield",
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}
