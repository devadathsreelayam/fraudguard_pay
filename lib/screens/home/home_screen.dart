import 'package:flutter/material.dart';
import 'package:fraudguard_pay/config/theme.dart';
import 'package:fraudguard_pay/screens/money/money_screen.dart';
import 'package:fraudguard_pay/screens/contacts/contacts_screen.dart';
import 'package:fraudguard_pay/screens/money/history/transaction_history_screen.dart';
import 'package:fraudguard_pay/screens/qr_scanner/qr_scanner_screen.dart';
import 'package:fraudguard_pay/screens/fraud/fraudguard_summary_screen.dart';
import 'package:fraudguard_pay/services/user_manager.dart';

/// Home/Dashboard screen showing user balance, quick actions, and contacts.
/// Flows: Main Navigation → Home Screen (entry point of app) → {Money, Contacts, QR Scanner, Fraud Guard}
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  String _userName = "User";
  String _userVpa = "user@fgpay";
  bool _isFabVisible = true;
  bool _isPeopleExpanded = false;
  bool _isBusinessExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadUserName();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels > 50) {
        if (_isFabVisible) setState(() => _isFabVisible = false);
      } else {
        if (!_isFabVisible) setState(() => _isFabVisible = true);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    final name = await UserManager.getUserName();
    final vpa = await UserManager.getUserVpa();
    setState(() {
      _userName = name;
      _userVpa = vpa;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryDark,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildHeader(context),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  children: [
                    _buildPromoBanner(),
                    const SizedBox(height: 24),
                    _buildTransferGrid(context),
                    const SizedBox(height: 32),
                    _buildSectionTitle("People"),
                    _buildPeopleGrid(),
                    const SizedBox(height: 32),
                    _buildSectionTitle("Businesses"),
                    _buildBusinessGrid(),
                    const SizedBox(height: 32),
                    _buildUtilityList(context),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildScanFAB(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      backgroundColor: primaryDark,
      floating: true,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 22,
                backgroundColor: accentOrange,
                child: Icon(Icons.person, color: textPrimary),
              ),
              const SizedBox(width: 12),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Hey, $_userName",
                    style: TextStyle(
                      color: textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _userVpa,
                    style: TextStyle(color: textSecondary, fontSize: 13),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.search, color: textPrimary),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      width: double.infinity,
      height: 140,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [secondaryDark, Color(0xFF254B8C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Secure payments\nfor everybody",
              style: TextStyle(
                color: textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: accentOrange,
                shape: const StadiumBorder(),
              ),
              child: const Text(
                "Know More",
                style: TextStyle(
                  color: textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferGrid(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 0.9,
      children: [
        _gridItem(
          Icons.qr_code_scanner,
          "Scan QR",
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QrScannerScreen()),
          ),
        ),
        _gridItem(
          Icons.contacts,
          "Pay\ncontacts",
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ContactsScreen()),
          ),
        ),
        _gridItem(
          Icons.phone_android,
          "Pay phone",
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ContactsScreen()),
          ),
        ),
        _gridItem(Icons.account_balance, "Bank", () {}),
        _gridItem(Icons.alternate_email, "UPI ID", () {}),
        _gridItem(Icons.person_pin, "Self", () {}),
        _gridItem(Icons.receipt_long, "Bills", () {}),
        _gridItem(
          Icons.history,
          "History",
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
          ),
        ),
      ],
    );
  }

  Widget _gridItem(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: secondaryDark.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: accentOrange, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildPeopleGrid() {
    final names = [
      "Deepa",
      "Kiran",
      "Sanusha",
      "Arun",
      "Jamal",
      "Biju",
      "Sara",
      "Ali",
      "Tom",
      "Rex",
    ];

    int maxItems = _isPeopleExpanded ? 24 : 8;
    int displayCount = names.length < maxItems ? names.length : maxItems - 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: displayCount + 1,
      itemBuilder: (context, i) {
        if (i == displayCount) {
          return _buildToggleButton();
        }
        return _buildPersonItem(names[i]);
      },
    );
  }

  Widget _buildPersonItem(String name) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: secondaryDark,
          child: Text(
            name[0],
            style: const TextStyle(color: accentOrange, fontSize: 22),
          ),
        ),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(color: textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildToggleButton() {
    return GestureDetector(
      onTap: () => setState(() => _isPeopleExpanded = !_isPeopleExpanded),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: borderColor,
            child: Icon(
              _isPeopleExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: textPrimary,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isPeopleExpanded ? "Show less" : "View more",
            style: const TextStyle(color: textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBusinessGrid() {
    final names = [
      "Airtel",
      "Swiggy",
      "Zomato",
      "Uber",
      "Jio",
      "Netflix",
      "Amazon",
      "Nike",
      "Adidas",
      "Apple",
    ];

    int maxItems = _isBusinessExpanded ? 24 : 8;
    int displayCount = names.length < maxItems ? names.length : maxItems - 1;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 8,
        childAspectRatio: 0.8,
      ),
      itemCount: displayCount + 1,
      itemBuilder: (context, i) {
        if (i == displayCount) {
          return _buildBusinessToggle();
        }
        return _buildBusinessItem(names[i]);
      },
    );
  }

  Widget _buildBusinessItem(String name) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: cardBg,
          child: const Icon(Icons.business, color: textPrimary),
        ),
        const SizedBox(height: 8),
        Text(name, style: const TextStyle(color: textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _buildBusinessToggle() {
    return GestureDetector(
      onTap: () => setState(() => _isBusinessExpanded = !_isBusinessExpanded),
      child: Column(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: borderColor,
            child: Icon(
              _isBusinessExpanded
                  ? Icons.keyboard_arrow_up
                  : Icons.keyboard_arrow_down,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isBusinessExpanded ? "Show less" : "View more",
            style: const TextStyle(color: textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildUtilityList(BuildContext context) {
    return Column(
      children: [
        _utilityTile(
          Icons.account_balance_wallet,
          "View bank balance",
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const MoneyScreen()),
          ),
        ),
        _utilityTile(
          Icons.history,
          "See transaction history",
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TransactionHistoryScreen()),
          ),
        ),
        _utilityTile(
          Icons.security,
          "Check Fraud History",
          () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const FraudGuardSummaryScreen()),
          ),
          color: Colors.redAccent,
        ),
      ],
    );
  }

  Widget _utilityTile(
    IconData icon,
    String title,
    VoidCallback onTap, {
    Color color = textSecondary,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: const Icon(
            Icons.chevron_right,
            color: textSecondary,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildScanFAB(BuildContext context) {
    return AnimatedScale(
      scale: _isFabVisible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: FloatingActionButton.extended(
        onPressed:
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QrScannerScreen()),
            ),
        backgroundColor: accentOrange,
        icon: const Icon(Icons.qr_code_scanner, color: textPrimary),
        label: const Text(
          "Scan any QR",
          style: TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
