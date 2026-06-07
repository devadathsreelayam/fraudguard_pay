import 'package:fraudguard_pay/database/database_helper.dart';
import 'package:fraudguard_pay/models/contact_model.dart';
import 'package:fraudguard_pay/models/transaction_model.dart';

Future<void> initDatabaseData() async {
  print("🔵 initDatabaseData: Started");

  final dbHelper = DatabaseHelper();

  final existingTransactions = await dbHelper.getTransactions();
  final existingContacts = await dbHelper.getContacts();

  print("🔵 Existing transactions: ${existingTransactions.length}");
  print("🔵 Existing contacts: ${existingContacts.length}");

  if (existingTransactions.isNotEmpty && existingContacts.isNotEmpty) {
    print("🟢 Database already has data. Skipping initialisation.");
    return;
  }
}
