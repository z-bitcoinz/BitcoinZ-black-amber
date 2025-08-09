import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
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
    // Check if database exists and is open
    if (_database != null) {
      try {
        // Test if database is still valid by running a simple query
        await _database!.rawQuery('SELECT 1');
        return _database!;
      } catch (e) {
        if (kDebugMode) print('⚠️ Database is closed or invalid, resetting...');
        await _resetDatabase();
      }
    }
    
    // Initialize or reinitialize database
    try {
      _database = await _initDatabase();
      return _database!;
    } catch (e) {
      if (kDebugMode) print('❌ Database initialization failed: $e');
      
      // On authorization errors, reset and retry with fresh state
      if (e.toString().contains('authorization denied') || 
          e.toString().contains('authorization') ||
          e.toString().contains('sqlite3_step')) {
        if (kDebugMode) print('🔄 Authorization error detected, attempting recovery...');
        await _resetDatabase();
        
        // Delete the database file and try again
        await _deleteDatabaseFile();
        
        // Try one more time with completely fresh state
        try {
          _database = await _initDatabase();
          return _database!;
        } catch (retryError) {
          if (kDebugMode) print('❌ Database recovery failed: $retryError');
          // If still failing, throw a more descriptive error
          throw Exception('Database initialization failed. Please restart the app.');
        }
      }
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    String path;
    
    // Use application support directory for better permissions
    if (defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux) {
      // Desktop platforms: use application support directory
      final Directory appSupportDir = await getApplicationSupportDirectory();
      // Create database subdirectory if needed
      final dbDir = Directory(join(appSupportDir.path, 'database'));
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }
      path = join(dbDir.path, 'bitcoinz_wallet.db');
      if (kDebugMode) print('📁 Database path: $path');
    } else {
      // Mobile platforms: use default database path
      final databasesPath = await getDatabasesPath();
      path = join(databasesPath, 'bitcoinz_wallet.db');
    }

    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
      singleInstance: true,
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
        memo_read INTEGER NOT NULL DEFAULT 0,
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
    if (oldVersion < 2) {
      // Add memo_read column to existing transactions table
      await db.execute('ALTER TABLE transactions ADD COLUMN memo_read INTEGER NOT NULL DEFAULT 0');
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
    try {
      final db = await database;
      
      // Use individual inserts instead of batch to avoid transaction issues
      for (final transaction in transactions) {
        try {
          await db.insert(
            'transactions',
            _transactionToMap(transaction),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
        } catch (e) {
          // Continue with other transactions if one fails
          if (kDebugMode) print('Warning: Failed to insert transaction ${transaction.txid}: $e');
        }
      }
    } catch (e) {
      if (kDebugMode) print('Warning: Failed to insert transactions: $e');
      
      // If authorization error, try to reset and retry once
      if (e.toString().contains('authorization') && !e.toString().contains('retry')) {
        try {
          if (kDebugMode) print('🔄 Retrying after database reset...');
          await forceReset();
          final db = await database;
          
          for (final transaction in transactions) {
            try {
              await db.insert(
                'transactions',
                _transactionToMap(transaction),
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            } catch (insertError) {
              if (kDebugMode) print('Warning: Failed to insert transaction ${transaction.txid}: $insertError');
            }
          }
          if (kDebugMode) print('✅ Retry successful!');
        } catch (retryError) {
          if (kDebugMode) print('⚠️ Retry failed: $retryError');
        }
      }
    }
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

  Future<void> markTransactionMemoAsRead(String txid) async {
    try {
      final db = await database;
      await db.update(
        'transactions',
        {'memo_read': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'txid = ?',
        whereArgs: [txid],
      );
    } catch (e) {
      if (kDebugMode) print('Warning: Failed to mark memo as read: $e');
      
      // If authorization error, try to reset and retry once
      if (e.toString().contains('authorization') && !e.toString().contains('retry')) {
        try {
          if (kDebugMode) print('🔄 Retrying after database reset...');
          await forceReset();
          final db = await database;
          await db.update(
            'transactions',
            {'memo_read': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
            where: 'txid = ?',
            whereArgs: [txid],
          );
          if (kDebugMode) print('✅ Retry successful!');
          return;
        } catch (retryError) {
          if (kDebugMode) print('⚠️ Retry failed: $retryError');
        }
      }
      // Continue silently - memo status will be stored in memory/SharedPreferences
    }
  }

  Future<int> getUnreadMemoCount() async {
    try {
      final db = await database;
      final result = await db.rawQuery('''
        SELECT COUNT(*) as count FROM transactions 
        WHERE memo IS NOT NULL AND memo != '' AND memo_read = 0
      ''');
      
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      if (kDebugMode) print('Warning: Failed to get unread memo count: $e');
      
      // If authorization error, try to reset and retry once
      if (e.toString().contains('authorization') && !e.toString().contains('retry')) {
        try {
          if (kDebugMode) print('🔄 Retrying after database reset...');
          await forceReset();
          final db = await database;
          final result = await db.rawQuery('''
            SELECT COUNT(*) as count FROM transactions 
            WHERE memo IS NOT NULL AND memo != '' AND memo_read = 0
          ''');
          if (kDebugMode) print('✅ Retry successful!');
          return Sqflite.firstIntValue(result) ?? 0;
        } catch (retryError) {
          if (kDebugMode) print('⚠️ Retry failed: $retryError');
        }
      }
      return 0;
    }
  }
  
  Future<Map<String, bool>> getMemoReadStatus() async {
    try {
      final db = await database;
      final results = await db.rawQuery('''
        SELECT txid, memo_read FROM transactions 
        WHERE memo IS NOT NULL AND memo != ''
      ''');
      
      final Map<String, bool> readStatus = {};
      for (final row in results) {
        readStatus[row['txid'] as String] = (row['memo_read'] as int) == 1;
      }
      return readStatus;
    } catch (e) {
      if (kDebugMode) print('Warning: Failed to get memo read status: $e');
      
      // If authorization error, try to reset and retry once
      if (e.toString().contains('authorization') && !e.toString().contains('retry')) {
        try {
          if (kDebugMode) print('🔄 Retrying after database reset...');
          await forceReset();
          final db = await database;
          final results = await db.rawQuery('''
            SELECT txid, memo_read FROM transactions 
            WHERE memo IS NOT NULL AND memo != ''
          ''');
          
          final Map<String, bool> readStatus = {};
          for (final row in results) {
            readStatus[row['txid'] as String] = (row['memo_read'] as int) == 1;
          }
          if (kDebugMode) print('✅ Retry successful!');
          return readStatus;
        } catch (retryError) {
          if (kDebugMode) print('⚠️ Retry failed: $retryError');
        }
      }
      return {};
    }
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
    if (_database != null) {
      try {
        await _database!.close();
      } catch (e) {
        if (kDebugMode) print('⚠️ Error closing database: $e');
      } finally {
        _database = null; // Always clear the reference
      }
    }
  }
  
  /// Reset the database singleton
  static Future<void> _resetDatabase() async {
    if (_database != null) {
      try {
        if (kDebugMode) print('🔄 Resetting database singleton...');
        await _database!.close();
      } catch (e) {
        if (kDebugMode) print('⚠️ Error closing database during reset: $e');
      } finally {
        _database = null;
      }
    }
  }
  
  /// Delete the database file (for recovery from corruption)
  static Future<void> _deleteDatabaseFile() async {
    try {
      // First try to delete old wrongly-placed database on macOS
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        try {
          // Clean up old database in Documents directory
          final Directory oldDocDir = await getApplicationDocumentsDirectory();
          final oldPath = join(oldDocDir.path, 'bitcoinz_wallet.db');
          final oldDbFile = File(oldPath);
          if (await oldDbFile.exists()) {
            if (kDebugMode) print('🗑️ Deleting old database at wrong location: $oldPath');
            await oldDbFile.delete();
          }
          // Clean up journal files
          for (final suffix in ['-journal', '-wal', '-shm']) {
            try {
              final file = File('$oldPath$suffix');
              if (await file.exists()) await file.delete();
            } catch (_) {}
          }
        } catch (e) {
          if (kDebugMode) print('⚠️ Could not delete old database: $e');
        }
      }
      
      // Now delete the correct database location
      String path;
      
      if (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux) {
        final Directory appSupportDir = await getApplicationSupportDirectory();
        final dbDir = Directory(join(appSupportDir.path, 'database'));
        path = join(dbDir.path, 'bitcoinz_wallet.db');
      } else {
        final databasesPath = await getDatabasesPath();
        path = join(databasesPath, 'bitcoinz_wallet.db');
      }
      
      final dbFile = File(path);
      if (await dbFile.exists()) {
        if (kDebugMode) print('🗑️ Deleting corrupted database file: $path');
        await dbFile.delete();
        
        // Also delete journal and wal files if they exist
        final journalFile = File('$path-journal');
        if (await journalFile.exists()) {
          await journalFile.delete();
        }
        
        final walFile = File('$path-wal');
        if (await walFile.exists()) {
          await walFile.delete();
        }
        
        final shmFile = File('$path-shm');
        if (await shmFile.exists()) {
          await shmFile.delete();
        }
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Error deleting database file: $e');
    }
  }
  
  /// Force reset database (can be called externally if needed)
  static Future<void> forceReset() async {
    await _resetDatabase();
    await _deleteDatabaseFile();
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
      'memo_read': transaction.memoRead ? 1 : 0,
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
      memoRead: (map['memo_read'] as int? ?? 0) == 1,
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