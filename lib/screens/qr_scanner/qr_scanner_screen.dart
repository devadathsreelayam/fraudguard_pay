import 'package:flutter/material.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fraudguard_pay/screens/payment/payment_input_screen.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool isScanCompleted = false;

  void _handleQrDetection(BarcodeCapture capture) async {
    if (isScanCompleted) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null && code.contains("upi://pay")) {
        setState(() => isScanCompleted = true);

        // Parse the name from upi://pay?pa=xyz@bank&pn=Name
        Uri uri = Uri.parse(code);
        String vpa = uri.queryParameters['pa'] ?? "";
        String name = uri.queryParameters['pn'] ?? "Merchant";
        String amount = uri.queryParameters['am'] ?? "Merchant";

        if (vpa.isEmpty) {
          // Invalid QR code
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Invalid QR code")));
          return;
        }

        final dbHelper = DatabaseHelper();
        final allContacts = await dbHelper.getContacts();
        Contact? existingContact = allContacts.firstWhere(
          (c) => c.vpa == vpa,
          orElse: () => Contact(id: null, name: name, vpa: vpa, phone: ""),
        );

        Contact contactToUse;

        if (existingContact.id == -1) {
          // Contact doesn't exist, create a new one
          final newId = await dbHelper.insertContact(existingContact);
          contactToUse = Contact(id: newId, name: name, vpa: vpa, phone: "");
        } else {
          contactToUse = existingContact;
        }

        // Vibrate or play sound here if you like

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder:
                (_) =>
                    PaymentInputScreen(contact: contactToUse, amount: amount),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan QR Code"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(onDetect: _handleQrDetection),
          // The "Scanner Overlay" Window
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          const Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Text(
                "Align QR code within the frame",
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
