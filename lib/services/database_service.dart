import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/transaction_model.dart';
import '../models/address_model.dart';

class DatabaseService {
  static DatabaseService? _instance;
  static Database? _database;
  
  DatabaseService._internal();
  
  static DatabaseService get instance {
    _instance ??= DatabaseService._internal();
    return _instance!;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'bitcoinz_wallet.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    // Create transactions table
    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        txid TEXT UNIQUE NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        fee REAL,
        timestamp INTEGER NOT NULL,
        confirmations INTEGER DEFAULT 0,
        from_address TEXT,
        to_address TEXT,
        memo TEXT,
        block_height INTEGER,
        is_sent INTEGER NOT NULL DEFAULT 0,
        is_received INTEGER NOT NULL DEFAULT 0,
        is_pending INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create addresses table
    await db.execute('''
      CREATE TABLE addresses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        address TEXT UNIQUE NOT NULL,
        type TEXT NOT NULL,
        label TEXT,
        balance REAL DEFAULT 0.0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_transactions_txid ON transactions(txid)');
    await db.execute('CREATE INDEX idx_transactions_timestamp ON transactions(timestamp DESC)');
    await db.execute('CREATE INDEX idx_transactions_type ON transactions(type)');
    await db.execute('CREATE INDEX idx_transactions_pending ON transactions(is_pending)');
    await db.execute('CREATE INDEX idx_addresses_address ON addresses(address)');
    await db.execute('CREATE INDEX idx_addresses_type ON addresses(type)');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Handle database schema upgrades here
    if (oldVersion < newVersion) {
      // Add future schema changes here
    }
  }

  // Transaction CRUD operations
  Future<void> insertTransaction(TransactionModel transaction) async {
    final db = await database;
    await db.insert(
      'transactions',
      _transactionToMap(transaction),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertTransactions(List<TransactionModel> transactions) async {
    final db = await database;
    final batch = db.batch();
    
    for (final transaction in transactions) {
      batch.insert(
        'transactions',
        _transactionToMap(transaction),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  Future<List<TransactionModel>> getTransactions({
    int? limit,
    int? offset,
    String? type,
    bool? isPending,
    String? searchQuery,
  }) async {
    final db = await database;
    
    String whereClause = '';
    List<Object?> whereArgs = [];
    
    List<String> conditions = [];
    
    if (type != null) {
      conditions.add('type = ?');
      whereArgs.add(type);
    }
    
    if (isPending != null) {
      conditions.add('is_pending = ?');
      whereArgs.add(isPending ? 1 : 0);
    }
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add('''
        (txid LIKE ? OR 
         from_address LIKE ? OR 
         to_address LIKE ? OR 
         memo LIKE ?)
      ''');
      final query = '%$searchQuery%';
      whereArgs.addAll([query, query, query, query]);
    }
    
    if (conditions.isNotEmpty) {
      whereClause = 'WHERE ${conditions.join(' AND ')}';
    }
    
    final limitClause = limit != null ? 'LIMIT $limit' : '';
    final offsetClause = offset != null ? 'OFFSET $offset' : '';
    
    final results = await db.rawQuery('''
      SELECT * FROM transactions 
      $whereClause 
      ORDER BY timestamp DESC 
      $limitClause $offsetClause
    ''', whereArgs);

    return results.map((map) => _mapToTransaction(map)).toList();
  }

  Future<int> getTransactionCount({
    String? type,
    bool? isPending,
    String? searchQuery,
  }) async {
    final db = await database;
    
    String whereClause = '';
    List<Object?> whereArgs = [];
    
    List<String> conditions = [];
    
    if (type != null) {
      conditions.add('type = ?');
      whereArgs.add(type);
    }
    
    if (isPending != null) {
      conditions.add('is_pending = ?');
      whereArgs.add(isPending ? 1 : 0);
    }
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add('''
        (txid LIKE ? OR 
         from_address LIKE ? OR 
         to_address LIKE ? OR 
         memo LIKE ?)
      ''');
      final query = '%$searchQuery%';
      whereArgs.addAll([query, query, query, query]);
    }
    
    if (conditions.isNotEmpty) {
      whereClause = 'WHERE ${conditions.join(' AND ')}';
    }
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count FROM transactions $whereClause
    ''', whereArgs);
    
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<TransactionModel?> getTransactionByTxid(String txid) async {
    final db = await database;
    final results = await db.query(
      'transactions',
      where: 'txid = ?',
      whereArgs: [txid],
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return _mapToTransaction(results.first);
    }
    return null;
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    final db = await database;
    await db.update(
      'transactions',
      _transactionToMap(transaction),
      where: 'txid = ?',
      whereArgs: [transaction.txid],
    );
  }

  Future<void> deleteTransaction(String txid) async {
    final db = await database;
    await db.delete(
      'transactions',
      where: 'txid = ?',
      whereArgs: [txid],
    );
  }

  // Address CRUD operations
  Future<void> insertAddress(AddressModel address) async {
    final db = await database;
    await db.insert(
      'addresses',
      _addressToMap(address),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertAddresses(List<AddressModel> addresses) async {
    final db = await database;
    final batch = db.batch();
    
    for (final address in addresses) {
      batch.insert(
        'addresses',
        _addressToMap(address),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    
    await batch.commit(noResult: true);
  }

  Future<List<AddressModel>> getAddresses({
    String? type,
    bool? isActive,
  }) async {
    final db = await database;
    
    String whereClause = '';
    List<Object?> whereArgs = [];
    
    List<String> conditions = [];
    
    if (type != null) {
      conditions.add('type = ?');
      whereArgs.add(type);
    }
    
    if (isActive != null) {
      conditions.add('is_active = ?');
      whereArgs.add(isActive ? 1 : 0);
    }
    
    if (conditions.isNotEmpty) {
      whereClause = 'WHERE ${conditions.join(' AND ')}';
    }
    
    final results = await db.rawQuery('''
      SELECT * FROM addresses 
      $whereClause 
      ORDER BY created_at DESC
    ''', whereArgs);

    return results.map((map) => _mapToAddress(map)).toList();
  }

  Future<void> updateAddress(AddressModel address) async {
    final db = await database;
    await db.update(
      'addresses',
      _addressToMap(address),
      where: 'address = ?',
      whereArgs: [address.address],
    );
  }

  // Utility methods
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('addresses');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }

  // Conversion methods
  Map<String, dynamic> _transactionToMap(TransactionModel transaction) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'txid': transaction.txid,
      'type': transaction.type,
      'amount': transaction.amount,
      'fee': transaction.fee,
      'timestamp': transaction.timestamp.millisecondsSinceEpoch,
      'confirmations': transaction.confirmations,
      'from_address': transaction.fromAddress,
      'to_address': transaction.toAddress,
      'memo': transaction.memo,
      'block_height': transaction.blockHeight,
      'is_sent': transaction.isSent ? 1 : 0,
      'is_received': transaction.isReceived ? 1 : 0,
      'is_pending': transaction.isPending ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    };
  }

  TransactionModel _mapToTransaction(Map<String, dynamic> map) {
    return TransactionModel(
      txid: map['txid'] as String,
      type: map['type'] as String,
      amount: map['amount'] as double,
      fee: map['fee'] as double?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
      confirmations: map['confirmations'] as int? ?? 0,
      fromAddress: map['from_address'] as String?,
      toAddress: map['to_address'] as String?,
      memo: map['memo'] as String?,
      blockHeight: map['block_height'] as int?,
    );
  }

  Map<String, dynamic> _addressToMap(AddressModel address) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'address': address.address,
      'type': address.type,
      'label': address.label,
      'balance': address.balance,
      'is_active': address.isActive ? 1 : 0,
      'created_at': now,
      'updated_at': now,
    };
  }

  AddressModel _mapToAddress(Map<String, dynamic> map) {
    return AddressModel(
      address: map['address'] as String,
      type: map['type'] as String,
      label: map['label'] as String?,
      balance: map['balance'] as double? ?? 0.0,
      isActive: (map['is_active'] as int? ?? 1) == 1,
    );
  }
}