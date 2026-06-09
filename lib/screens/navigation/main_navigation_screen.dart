// screens/navigation/main_navigation_screen.dart
// Full replacement — adds periodic sync and a global refresh notifier.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fraudguard_pay/services/sync_manager.dart';
import 'package:fraudguard_pay/services/user_manager.dart';
import 'package:fraudguard_pay/screens/home/home_screen.dart';
// import 'package:fraudguard_pay/screens/contacts/contacts_screen.dart';
import 'package:fraudguard_pay/screens/money/money_screen.dart';
import 'package:fraudguard_pay/screens/fraud/fraudguard_summary_screen.dart';
import 'package:fraudguard_pay/screens/profile/profile_screen.dart';
import 'package:fraudguard_pay/config/theme.dart';

// ── Global refresh notifier ──────────────────────────────────────────────────
// Any screen can call `AppRefresh.notify()` after a payment to trigger
// a re-sync without navigating away.
class AppRefresh {
  static final _controller = StreamController<void>.broadcast();
  static Stream<void> get stream => _controller.stream;
  static void notify() => _controller.add(null);
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  Timer? _syncTimer;
  StreamSubscription? _refreshSub;
  bool _isSyncing = false;
  String? _userId;

  // Keep screens alive when switching tabs
  final List<Widget> _screens = const [
    HomeScreen(),
    // ContactsScreen(),
    MoneyScreen(),
    FraudGuardSummaryScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    _userId = await UserManager.getCustomerId();
    if (_userId == null) return;

    // Initial sync on launch
    await _doSync();

    // Sync every 60 seconds while app is open
    _syncTimer = Timer.periodic(const Duration(seconds: 60), (_) => _doSync());

    // Listen for manual refresh triggers (e.g., after payment)
    _refreshSub = AppRefresh.stream.listen((_) => _doSync());
  }

  Future<void> _doSync() async {
    if (_isSyncing || _userId == null) return;
    setState(() => _isSyncing = true);
    try {
      await SyncManager().syncAll(_userId!);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // Sync when app comes back to foreground
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _doSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    _refreshSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),
          // Subtle sync indicator at top
          if (_isSyncing)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(accentOrange),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        type: BottomNavigationBarType.fixed,
        backgroundColor: secondaryDark,
        selectedItemColor: accentOrange,
        unselectedItemColor: textSecondary,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: const TextStyle(fontSize: 10),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          // BottomNavigationBarItem(
          //   icon: Icon(Icons.people_rounded),
          //   label: 'Contacts',
          // ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet_rounded),
            label: 'Money',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.security_rounded),
            label: 'FraudGuard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
