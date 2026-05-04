## SQLite Database Access Guide for FG Pay

This guide explains how to view, edit, and manage the FG Pay SQLite database directly on your computer.

---

## Where is the Database Located?

The SQLite database file (`fg_pay.db`) is stored in your app's **documents directory**:

### Android
```
/data/data/com.fraudguard_pay/files/fg_pay.db
```
or
```
/sdcard/Android/data/com.fraudguard_pay/files/Documents/fg_pay.db
```

### Windows (Emulator/Desktop)
If running on Flutter Desktop or Android Emulator on Windows, the database is in:
```
%APPDATA%\<app_name>\fg_pay.db
```

or when running on physical Android device via ADB:
```bash
adb pull /data/data/com.fraudguard_pay/files/fg_pay.db ~/Downloads/
```

### macOS/Linux
```
~/.local/share/<app_name>/fg_pay.db
```

---

## Tools to View/Edit the Database

### Option 1: **SQLite Browser (Recommended - Free & Easy)**
**Download:** [DB Browser for SQLite](https://sqlitebrowser.org/)

**Steps:**
1. Download and install DB Browser for SQLite
2. Open the application
3. Click **File → Open Database**
4. Navigate to your `fg_pay.db` file
5. Browse tables, view data, and make changes

**Advantages:**
- GUI interface (no command line needed)
- Visual table editor
- Can execute SQL queries
- Export/Import data

---

### Option 2: **Command Line (SQLite CLI)**
If you have SQLite installed on your system:

```bash
# Open the database
sqlite3 ~/path/to/fg_pay.db

# Inside SQLite shell:
# List all tables
.tables

# View table schema
.schema contacts
.schema transactions

# Query data
SELECT * FROM contacts;
SELECT * FROM transactions;

# Insert data
INSERT INTO contacts (name, vpa, phone, avatar)
VALUES ('John Doe', 'john@oksbi', '9876543210', NULL);

# Update data
UPDATE contacts SET phone = '9999999999' WHERE name = 'John Doe';

# Delete data
DELETE FROM contacts WHERE name = 'John Doe';

# Exit
.quit
```

---

### Option 3: **VS Code Extension**
**Extension:** SQLite (by alexcvzz)

**Steps:**
1. Open VS Code
2. Go to Extensions (Ctrl+Shift+X)
3. Search for "SQLite"
4. Install "SQLite" by alexcvzz
5. Right-click `fg_pay.db` in file explorer
6. Select "Open with SQLite"

---

### Option 4: **Python Script (Programmatic)**
Create a Python script to query and manage data:

```python
import sqlite3
from datetime import datetime

# Connect to database
conn = sqlite3.connect('path/to/fg_pay.db')
cursor = conn.cursor()

# View all contacts
print("=== All Contacts ===")
cursor.execute('SELECT * FROM contacts')
for row in cursor.fetchall():
    print(row)

# Insert new contact
print("\n=== Inserting New Contact ===")
cursor.execute('''
    INSERT INTO contacts (name, vpa, phone, avatar)
    VALUES (?, ?, ?, ?)
''', ('Jane Smith', 'jane@oksbi', '9988776655', None))
conn.commit()
print("Contact inserted!")

# View all transactions
print("\n=== All Transactions ===")
cursor.execute('SELECT id, timestamp, sender_id, recipient, amount, status FROM transactions ORDER BY timestamp DESC LIMIT 5')
for row in cursor.fetchall():
    print(row)

# Update transaction fraud status
print("\n=== Updating Fraud Status ===")
cursor.execute('''
    UPDATE transactions
    SET is_fraud = 1, risk_factors = ?
    WHERE id = ?
''', ('Test fraud update', 'TEST_ID_123'))
conn.commit()

conn.close()
```

---

## Database Schema

### Contacts Table
```sql
CREATE TABLE contacts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  vpa TEXT NOT NULL UNIQUE,
  phone TEXT,
  avatar TEXT
)
```

### Transactions Table
```sql
CREATE TABLE transactions (
  id TEXT PRIMARY KEY,
  timestamp TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  recipient TEXT NOT NULL,
  amount REAL NOT NULL,
  type TEXT NOT NULL,
  status TEXT NOT NULL,
  note TEXT,
  is_fraud INTEGER DEFAULT 0,
  risk_factors TEXT,
  server_transaction_id TEXT
)
```

### Fraud Flags Table
```sql
CREATE TABLE fraud_flags (
  transaction_id TEXT PRIMARY KEY,
  risk_score REAL,
  risk_factors TEXT,
  flagged_at TEXT,
  FOREIGN KEY (transaction_id) REFERENCES transactions (id) ON DELETE CASCADE
)
```

---

## Common SQL Operations

### Insert a New Contact
```sql
INSERT INTO contacts (name, vpa, phone, avatar)
VALUES ('Raj Kumar', 'raj@oksbi', '9123456789', NULL);
```

### Insert a New Transaction
```sql
INSERT INTO transactions (id, timestamp, sender_id, recipient, amount, type, status, note, is_fraud, risk_factors)
VALUES (
  'TXN_' || datetime('now'),
  datetime('now'),
  'me',
  'Raj Kumar',
  2500,
  'Money Sent',
  'Success',
  'Test transaction',
  0,
  NULL
);
```

### Mark a Transaction as Fraudulent
```sql
UPDATE transactions
SET is_fraud = 1, risk_factors = 'High-risk pattern detected'
WHERE id = 'TXN_123';
```

### Delete a Contact
```sql
DELETE FROM contacts WHERE name = 'Test User';
```

### Delete Transactions Older Than 30 Days
```sql
DELETE FROM transactions
WHERE timestamp < datetime('now', '-30 days');
```

### View Fraud Statistics
```sql
SELECT
  COUNT(*) as total_fraud,
  SUM(amount) as fraud_total_amount
FROM transactions
WHERE is_fraud = 1;
```

### Get Recent Transactions for a Specific Contact
```sql
SELECT * FROM transactions
WHERE recipient = 'Raj Kumar' OR sender_id = 'Raj Kumar'
ORDER BY timestamp DESC
LIMIT 10;
```

---

## Important Notes

⚠️ **Backup Before Editing:** Always backup your database before making direct edits:
```bash
cp fg_pay.db fg_pay.db.backup
```

⚠️ **Data Types:** Be careful with data types:
- `INTEGER` for numbers
- `TEXT` for strings
- `REAL` for decimals
- `is_fraud` should be 0 (false) or 1 (true)

⚠️ **Foreign Keys:** If you have fraud flags, don't delete transactions that have associated fraud records (due to CASCADE delete)

⚠️ **Timestamps:** Use ISO 8601 format: `2026-04-20T14:20:00.000`

---

## Running the Test Suite

To run the database CRUD tests:

```bash
flutter test test/database_test.dart
```

This will test all Create, Read, Update, Delete operations for contacts and transactions.

---

## Recommended Workflow

1. **For Manual Testing:** Use DB Browser for SQLite (easiest GUI)
2. **For Automated Testing:** Run the test suite in `test/database_test.dart`
3. **For Production Issues:** Use the Python script or command line
4. **For Development:** Keep DB Browser open while developing to inspect data in real-time
