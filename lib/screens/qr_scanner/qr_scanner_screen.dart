import 'package:flutter/material.dart';
import 'package:fraudguard_pay/config/theme.dart';
import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/services/contact_resolution_service.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:fraudguard_pay/screens/payment/payment_input_screen.dart';
import 'package:fluttertoast/fluttertoast.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  bool isScanCompleted = false;
  final ContactResolutionService _resolutionService =
      ContactResolutionService();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final MobileScannerController _scannerController = MobileScannerController();

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _handleQrDetection(BarcodeCapture capture) async {
    if (isScanCompleted) return;

    final List<Barcode> barcodes = capture.barcodes;
    for (final barcode in barcodes) {
      final String? code = barcode.rawValue;
      if (code != null && code.contains("upi://pay")) {
        setState(() => isScanCompleted = true);

        // Parse UPI QR code
        Uri uri = Uri.parse(code);
        String vpa = uri.queryParameters['pa'] ?? "";
        String name = uri.queryParameters['pn'] ?? "Merchant";
        String amount = uri.queryParameters['am'] ?? "";

        if (vpa.isEmpty) {
          vpa = uri.queryParameters['vpa'] ?? "";
        }
        if (name.isEmpty) {
          name = uri.queryParameters['name'] ?? "Merchant";
        }

        if (vpa.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Invalid QR code: VPA not found")),
            );
            setState(() => isScanCompleted = false);
          }
          return;
        }

        // Show loading
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text("Resolving contact..."),
                ],
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }

        try {
          final resolvedContact = await _resolutionService.resolveContact(
            vpa: vpa,
            name: name,
            phone: "",
          );

          if (!mounted) return;

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder:
                  (_) => PaymentInputScreen(
                    contact: resolvedContact,
                    amount: amount.isNotEmpty ? amount : "0",
                  ),
            ),
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Failed to resolve contact: $e"),
                backgroundColor: Colors.red,
              ),
            );
            setState(() => isScanCompleted = false);
          }
        }
      }
    }
  }

  Future<void> _toggleFlash() async {
    await _scannerController.toggleTorch();
  }

  Future<void> _toggleCamera() async {
    await _scannerController.switchCamera();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Scan QR Code"),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.flash_on), onPressed: _toggleFlash),
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            onPressed: _toggleCamera,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleQrDetection,
            errorBuilder: (context, error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      "Camera error: ${error.errorCode}",
                      style: const TextStyle(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        // Rebuild to retry
                        setState(() {});
                      },
                      child: const Text("Retry"),
                    ),
                  ],
                ),
              );
            },
          ),
          // Scanner overlay frame
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Stack(
                children: [
                  // Corner decorations
                  Positioned(
                    top: -2,
                    left: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: accentOrange, width: 4),
                          left: BorderSide(color: accentOrange, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -2,
                    right: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          top: BorderSide(color: accentOrange, width: 4),
                          right: BorderSide(color: accentOrange, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    left: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: accentOrange, width: 4),
                          left: BorderSide(color: accentOrange, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: accentOrange, width: 4),
                          right: BorderSide(color: accentOrange, width: 4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Scan line animation
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: TweenAnimationBuilder(
              tween: Tween<double>(begin: 0, end: 1),
              duration: const Duration(seconds: 2),
              builder: (context, value, child) {
                final screenHeight = MediaQuery.of(context).size.height;
                final scanTop = (screenHeight / 2) - 140 + (value * 280);
                return Positioned(
                  top: scanTop,
                  left: (MediaQuery.of(context).size.width / 2) - 140,
                  child: Container(
                    width: 280,
                    height: 2,
                    color: accentOrange.withOpacity(0.8),
                  ),
                );
              },
            ),
          ),
          // Instructions text
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Column(
              children: [
                const Text(
                  "Align QR code within the frame",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 14, color: Colors.white54),
                    const SizedBox(width: 4),
                    const Text(
                      "Supports UPI QR codes only",
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Manual entry option
          Positioned(
            bottom: 100,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: () {
                _showManualEntryDialog();
              },
              backgroundColor: accentOrange,
              child: const Icon(Icons.edit, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showManualEntryDialog() {
    final TextEditingController vpaController = TextEditingController();
    final TextEditingController nameController = TextEditingController();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text("Enter VPA Manually"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: vpaController,
                  decoration: const InputDecoration(
                    labelText: "VPA",
                    hintText: "username@bank",
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: "Name (optional)",
                    hintText: "Recipient name",
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () async {
                  final vpa = vpaController.text.trim();
                  if (vpa.isEmpty) {
                    Fluttertoast.showToast(msg: "Please enter a VPA");
                    return;
                  }

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Text("Resolving contact..."),
                        ],
                      ),
                    ),
                  );

                  try {
                    final name = nameController.text.trim();
                    final resolvedContact = await _resolutionService
                        .resolveContact(
                          vpa: vpa,
                          name: name.isEmpty ? vpa.split('@')[0] : name,
                          phone: "",
                        );

                    if (mounted) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) => PaymentInputScreen(
                                contact: resolvedContact,
                                amount: "0",
                              ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Failed to resolve: $e"),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                child: const Text("Continue"),
              ),
            ],
          ),
    );
  }
}
