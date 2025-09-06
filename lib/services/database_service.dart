import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/transaction_model.dart';
import '../models/address_model.dart';
import '../models/contact_model.dart';
import '../models/message_label.dart';
import '../models/transaction_category.dart';
import '../models/address_label.dart';
import './wallet_storage_service.dart';
import '../utils/logger.dart';

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
        Logger.database('Database is closed or invalid, resetting...', level: LogLevel.warning);
        await _resetDatabase();
      }
    }
    
    // Initialize or reinitialize database
    try {
      _database = await _initDatabase();
      return _database!;
    } catch (e) {
      Logger.database('Database initialization failed', level: LogLevel.error);
      
      // On authorization errors, reset and retry with fresh state
      if (e.toString().contains('authorization denied') || 
          e.toString().contains('authorization') ||
          e.toString().contains('sqlite3_step')) {
        Logger.database('Authorization error detected, attempting recovery...', level: LogLevel.warning);
        await _resetDatabase();
        
        // Delete the database file and try again
        await _deleteDatabaseFile();
        
        // Try one more time with completely fresh state
        try {
          _database = await _initDatabase();
          return _database!;
        } catch (retryError) {
          Logger.database('Database recovery failed', level: LogLevel.error);
          // If still failing, throw a more descriptive error
          throw Exception('Database initialization failed. Please restart the app.');
        }
      }
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    // Use WalletStorageService for consistent cross-platform paths
    final dbPath = await WalletStorageService.getDatabasePath();

    Logger.database('Database path: $dbPath - App: BitcoinZ Black Amber');

    return await openDatabase(
      dbPath,
      version: 7, // Increment version for notifications
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

    // Create contacts table
    await db.execute('''
      CREATE TABLE contacts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        address TEXT UNIQUE NOT NULL,
        type TEXT NOT NULL,
        description TEXT,
        picture_base64 TEXT,
        is_favorite INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create message_labels table for enhanced message management
    await db.execute('''
      CREATE TABLE message_labels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        txid TEXT NOT NULL,
        label_name TEXT NOT NULL,
        label_color TEXT DEFAULT '#2196F3',
        is_auto_generated INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (txid) REFERENCES transactions (txid) ON DELETE CASCADE
      )
    ''');

    // Create transaction_categories table for automatic categorization
    await db.execute('''
      CREATE TABLE transaction_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        txid TEXT NOT NULL UNIQUE,
        category_type TEXT NOT NULL,
        category_name TEXT NOT NULL,
        confidence_score REAL NOT NULL DEFAULT 0.0,
        is_manual INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (txid) REFERENCES transactions (txid) ON DELETE CASCADE
      )
    ''');

    // Create address_labels table for address labeling and analytics
    await db.execute('''
      CREATE TABLE address_labels (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        address TEXT NOT NULL,
        label_name TEXT NOT NULL,
        category TEXT NOT NULL,
        type TEXT NOT NULL,
        description TEXT,
        color TEXT NOT NULL DEFAULT '#9E9E9E',
        is_owned INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        UNIQUE(address, label_name)
      )
    ''');

    // Create notifications table for notification history
    await db.execute('''
      CREATE TABLE notifications (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        category TEXT NOT NULL,
        priority TEXT NOT NULL,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        subtitle TEXT,
        payload TEXT,
        timestamp INTEGER NOT NULL,
        is_read INTEGER NOT NULL DEFAULT 0,
        action_url TEXT,
        icon_path TEXT,
        image_path TEXT,
        sound_path TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Create indexes for better performance
    await db.execute('CREATE INDEX idx_transactions_txid ON transactions(txid)');
    await db.execute('CREATE INDEX idx_transactions_timestamp ON transactions(timestamp DESC)');
    await db.execute('CREATE INDEX idx_transactions_type ON transactions(type)');
    await db.execute('CREATE INDEX idx_transactions_pending ON transactions(is_pending)');
    await db.execute('CREATE INDEX idx_transactions_memo ON transactions(memo)');
    await db.execute('CREATE INDEX idx_transactions_memo_read ON transactions(memo_read)');
    await db.execute('CREATE INDEX idx_addresses_address ON addresses(address)');
    await db.execute('CREATE INDEX idx_addresses_type ON addresses(type)');
    await db.execute('CREATE INDEX idx_contacts_address ON contacts(address)');
    await db.execute('CREATE INDEX idx_contacts_name ON contacts(name)');
    await db.execute('CREATE INDEX idx_contacts_favorite ON contacts(is_favorite)');
    await db.execute('CREATE INDEX idx_message_labels_txid ON message_labels(txid)');
    await db.execute('CREATE INDEX idx_message_labels_name ON message_labels(label_name)');
    await db.execute('CREATE INDEX idx_transaction_categories_txid ON transaction_categories(txid)');
    await db.execute('CREATE INDEX idx_transaction_categories_type ON transaction_categories(category_type)');
    await db.execute('CREATE INDEX idx_transaction_categories_name ON transaction_categories(category_name)');
    await db.execute('CREATE INDEX idx_address_labels_address ON address_labels(address)');
    await db.execute('CREATE INDEX idx_address_labels_category ON address_labels(category)');
    await db.execute('CREATE INDEX idx_address_labels_type ON address_labels(type)');
    await db.execute('CREATE INDEX idx_address_labels_owned ON address_labels(is_owned)');
    await db.execute('CREATE INDEX idx_notifications_timestamp ON notifications(timestamp DESC)');
    await db.execute('CREATE INDEX idx_notifications_type ON notifications(type)');
    await db.execute('CREATE INDEX idx_notifications_category ON notifications(category)');
    await db.execute('CREATE INDEX idx_notifications_read ON notifications(is_read)');
  }

  Future<void> _upgradeDatabase(Database db, int oldVersion, int newVersion) async {
    // Handle database schema upgrades here
    if (oldVersion < 2) {
      // Add memo_read column to existing transactions table
      await db.execute('ALTER TABLE transactions ADD COLUMN memo_read INTEGER NOT NULL DEFAULT 0');
    }

    if (oldVersion < 3) {
      // Create contacts table
      await db.execute('''
        CREATE TABLE contacts (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          address TEXT UNIQUE NOT NULL,
          type TEXT NOT NULL,
          description TEXT,
          picture_base64 TEXT,
          is_favorite INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      // Create indexes for contacts
      await db.execute('CREATE INDEX idx_contacts_address ON contacts(address)');
      await db.execute('CREATE INDEX idx_contacts_name ON contacts(name)');
      await db.execute('CREATE INDEX idx_contacts_favorite ON contacts(is_favorite)');
    }

    if (oldVersion < 4) {
      // Create message_labels table for enhanced message management
      await db.execute('''
        CREATE TABLE message_labels (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          txid TEXT NOT NULL,
          label_name TEXT NOT NULL,
          label_color TEXT DEFAULT '#2196F3',
          is_auto_generated INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (txid) REFERENCES transactions (txid) ON DELETE CASCADE
        )
      ''');

      // Create indexes for message labels
      await db.execute('CREATE INDEX idx_message_labels_txid ON message_labels(txid)');
      await db.execute('CREATE INDEX idx_message_labels_name ON message_labels(label_name)');

      // Add missing indexes for better performance
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_memo ON transactions(memo)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_transactions_memo_read ON transactions(memo_read)');
    }

    if (oldVersion < 5) {
      // Create transaction_categories table for automatic categorization
      await db.execute('''
        CREATE TABLE transaction_categories (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          txid TEXT NOT NULL UNIQUE,
          category_type TEXT NOT NULL,
          category_name TEXT NOT NULL,
          confidence_score REAL NOT NULL DEFAULT 0.0,
          is_manual INTEGER NOT NULL DEFAULT 0,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          FOREIGN KEY (txid) REFERENCES transactions (txid) ON DELETE CASCADE
        )
      ''');

      // Create indexes for transaction categories
      await db.execute('CREATE INDEX idx_transaction_categories_txid ON transaction_categories(txid)');
      await db.execute('CREATE INDEX idx_transaction_categories_type ON transaction_categories(category_type)');
      await db.execute('CREATE INDEX idx_transaction_categories_name ON transaction_categories(category_name)');
    }

    if (oldVersion < 6) {
      // Create address_labels table for address labeling and analytics
      await db.execute('''
        CREATE TABLE address_labels (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          address TEXT NOT NULL,
          label_name TEXT NOT NULL,
          category TEXT NOT NULL,
          type TEXT NOT NULL,
          description TEXT,
          color TEXT NOT NULL DEFAULT '#9E9E9E',
          is_owned INTEGER NOT NULL DEFAULT 0,
          is_active INTEGER NOT NULL DEFAULT 1,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          UNIQUE(address, label_name)
        )
      ''');

      // Create indexes for address labels
      await db.execute('CREATE INDEX idx_address_labels_address ON address_labels(address)');
      await db.execute('CREATE INDEX idx_address_labels_category ON address_labels(category)');
      await db.execute('CREATE INDEX idx_address_labels_type ON address_labels(type)');
      await db.execute('CREATE INDEX idx_address_labels_owned ON address_labels(is_owned)');
    }

    if (oldVersion < 7) {
      // Create notifications table for notification history
      await db.execute('''
        CREATE TABLE notifications (
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          category TEXT NOT NULL,
          priority TEXT NOT NULL,
          title TEXT NOT NULL,
          body TEXT NOT NULL,
          subtitle TEXT,
          payload TEXT,
          timestamp INTEGER NOT NULL,
          is_read INTEGER NOT NULL DEFAULT 0,
          action_url TEXT,
          icon_path TEXT,
          image_path TEXT,
          sound_path TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      // Create indexes for notifications
      await db.execute('CREATE INDEX idx_notifications_timestamp ON notifications(timestamp DESC)');
      await db.execute('CREATE INDEX idx_notifications_type ON notifications(type)');
      await db.execute('CREATE INDEX idx_notifications_category ON notifications(category)');
      await db.execute('CREATE INDEX idx_notifications_read ON notifications(is_read)');
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
          Logger.database('Failed to insert transaction ${transaction.txid}', level: LogLevel.warning);
        }
      }
    } catch (e) {
      Logger.database('Failed to insert transactions', level: LogLevel.warning);
      
      // If authorization error, try to reset and retry once
      if (e.toString().contains('authorization') && !e.toString().contains('retry')) {
        try {
          Logger.database('Retrying after database reset...', level: LogLevel.warning);
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
              Logger.database('Failed to insert transaction ${transaction.txid}', level: LogLevel.warning);
            }
          }
                  } catch (retryError) {
          Logger.database('Retry failed', level: LogLevel.error);
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
      Logger.database('Failed to mark memo as read', level: LogLevel.warning);
      
      // If authorization error, try to reset and retry once
      if (e.toString().contains('authorization') && !e.toString().contains('retry')) {
        try {
          Logger.database('Retrying after database reset...', level: LogLevel.warning);
          await forceReset();
          final db = await database;
          await db.update(
            'transactions',
            {'memo_read': 1, 'updated_at': DateTime.now().millisecondsSinceEpoch},
            where: 'txid = ?',
            whereArgs: [txid],
          );
                    return;
        } catch (retryError) {
          Logger.database('Retry failed', level: LogLevel.error);
        }
      }
      // Continue silently - memo status will be stored in memory/SharedPreferences
    }
  }

  Future<void> markTransactionMemoAsUnread(String txid) async {
    try {
      final db = await database;
      await db.update(
        'transactions',
        {'memo_read': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
        where: 'txid = ?',
        whereArgs: [txid],
      );
    } catch (e) {
      Logger.database('Failed to mark memo as unread', level: LogLevel.warning);

      // If authorization error, try to reset and retry once
      if (e.toString().contains('authorization') && !e.toString().contains('retry')) {
        try {
          Logger.database('Retrying after database reset...', level: LogLevel.warning);
          await forceReset();
          final db = await database;
          await db.update(
            'transactions',
            {'memo_read': 0, 'updated_at': DateTime.now().millisecondsSinceEpoch},
            where: 'txid = ?',
            whereArgs: [txid],
          );
                    return;
        } catch (retryError) {
          Logger.database('Retry failed', level: LogLevel.error);
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
      Logger.database('Failed to get unread memo count', level: LogLevel.warning);
      
      // If authorization error, try to reset and retry once
      if (e.toString().contains('authorization') && !e.toString().contains('retry')) {
        try {
          Logger.database('Retrying after database reset...', level: LogLevel.warning);
          await forceReset();
          final db = await database;
          final result = await db.rawQuery('''
            SELECT COUNT(*) as count FROM transactions 
            WHERE memo IS NOT NULL AND memo != '' AND memo_read = 0
          ''');
                    return Sqflite.firstIntValue(result) ?? 0;
        } catch (retryError) {
          Logger.database('Retry failed', level: LogLevel.error);
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
          Logger.database('Retrying after database reset...', level: LogLevel.warning);
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
                    return readStatus;
        } catch (retryError) {
          Logger.database('Retry failed', level: LogLevel.error);
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

  // Contact CRUD operations
  Future<void> insertContact(ContactModel contact) async {
    final db = await database;
    await db.insert(
      'contacts',
      _contactToMap(contact),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ContactModel>> getContacts({
    bool? isFavorite,
    String? searchQuery,
  }) async {
    final db = await database;
    
    String whereClause = '';
    List<Object?> whereArgs = [];
    
    List<String> conditions = [];
    
    if (isFavorite != null) {
      conditions.add('is_favorite = ?');
      whereArgs.add(isFavorite ? 1 : 0);
    }
    
    if (searchQuery != null && searchQuery.isNotEmpty) {
      conditions.add('''
        (name LIKE ? OR 
         address LIKE ? OR 
         description LIKE ?)
      ''');
      final query = '%$searchQuery%';
      whereArgs.addAll([query, query, query]);
    }
    
    if (conditions.isNotEmpty) {
      whereClause = 'WHERE ${conditions.join(' AND ')}';
    }
    
    final results = await db.rawQuery('''
      SELECT * FROM contacts 
      $whereClause 
      ORDER BY is_favorite DESC, name ASC
    ''', whereArgs);

    return results.map((map) => _mapToContact(map)).toList();
  }

  Future<ContactModel?> getContactByAddress(String address) async {
    final db = await database;
    final results = await db.query(
      'contacts',
      where: 'address = ?',
      whereArgs: [address],
      limit: 1,
    );
    
    if (results.isNotEmpty) {
      return _mapToContact(results.first);
    }
    return null;
  }

  Future<void> updateContact(ContactModel contact) async {
    final db = await database;
    await db.update(
      'contacts',
      _contactToMap(contact),
      where: 'id = ?',
      whereArgs: [contact.id],
    );
  }

  Future<void> deleteContact(int contactId) async {
    final db = await database;
    await db.delete(
      'contacts',
      where: 'id = ?',
      whereArgs: [contactId],
    );
  }

  Future<int> getContactsCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM contacts');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  // Utility methods
  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('transactions');
    await db.delete('addresses');
    await db.delete('contacts');
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

  // Message Label CRUD operations
  Future<void> insertMessageLabel(MessageLabel label) async {
    final db = await database;
    await db.insert(
      'message_labels',
      _messageLabelToMap(label),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<MessageLabel>> getMessageLabelsForTransaction(String txid) async {
    final db = await database;
    final results = await db.query(
      'message_labels',
      where: 'txid = ?',
      whereArgs: [txid],
      orderBy: 'created_at ASC',
    );

    return results.map((map) => _mapToMessageLabel(map)).toList();
  }

  Future<List<MessageLabel>> getAllMessageLabels() async {
    final db = await database;
    final results = await db.query(
      'message_labels',
      orderBy: 'label_name ASC',
    );

    return results.map((map) => _mapToMessageLabel(map)).toList();
  }

  Future<void> updateMessageLabel(MessageLabel label) async {
    final db = await database;
    await db.update(
      'message_labels',
      _messageLabelToMap(label),
      where: 'id = ?',
      whereArgs: [label.id],
    );
  }

  Future<void> deleteMessageLabel(int labelId) async {
    final db = await database;
    await db.delete(
      'message_labels',
      where: 'id = ?',
      whereArgs: [labelId],
    );
  }

  Future<void> deleteMessageLabelsForTransaction(String txid) async {
    final db = await database;
    await db.delete(
      'message_labels',
      where: 'txid = ?',
      whereArgs: [txid],
    );
  }

  /// Get transactions with their message labels (optimized query)
  Future<Map<String, List<MessageLabel>>> getTransactionLabelsMap({
    List<String>? txids,
  }) async {
    final db = await database;

    String whereClause = '';
    List<Object?> whereArgs = [];

    if (txids != null && txids.isNotEmpty) {
      final placeholders = List.filled(txids.length, '?').join(',');
      whereClause = 'WHERE txid IN ($placeholders)';
      whereArgs = txids;
    }

    final results = await db.rawQuery('''
      SELECT * FROM message_labels
      $whereClause
      ORDER BY txid, created_at ASC
    ''', whereArgs);

    final Map<String, List<MessageLabel>> labelsMap = {};
    for (final row in results) {
      final label = _mapToMessageLabel(row);
      labelsMap.putIfAbsent(label.txid, () => []).add(label);
    }

    return labelsMap;
  }

  // Transaction Category CRUD operations
  Future<void> insertTransactionCategory({
    required String txid,
    required String categoryType,
    required String categoryName,
    required double confidenceScore,
    bool isManual = false,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.insert(
      'transaction_categories',
      {
        'txid': txid,
        'category_type': categoryType,
        'category_name': categoryName,
        'confidence_score': confidenceScore,
        'is_manual': isManual ? 1 : 0,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getTransactionCategory(String txid) async {
    final db = await database;
    final results = await db.query(
      'transaction_categories',
      where: 'txid = ?',
      whereArgs: [txid],
    );

    return results.isNotEmpty ? results.first : null;
  }

  Future<Map<String, Map<String, dynamic>>> getTransactionCategoriesMap({
    List<String>? txids,
  }) async {
    final db = await database;

    String whereClause = '';
    List<Object?> whereArgs = [];

    if (txids != null && txids.isNotEmpty) {
      final placeholders = List.filled(txids.length, '?').join(',');
      whereClause = 'WHERE txid IN ($placeholders)';
      whereArgs = txids;
    }

    final results = await db.rawQuery('''
      SELECT * FROM transaction_categories
      $whereClause
      ORDER BY created_at DESC
    ''', whereArgs);

    final Map<String, Map<String, dynamic>> categoriesMap = {};
    for (final row in results) {
      categoriesMap[row['txid'] as String] = row;
    }

    return categoriesMap;
  }

  Future<void> updateTransactionCategory({
    required String txid,
    required String categoryType,
    required String categoryName,
    required double confidenceScore,
    bool isManual = false,
  }) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'transaction_categories',
      {
        'category_type': categoryType,
        'category_name': categoryName,
        'confidence_score': confidenceScore,
        'is_manual': isManual ? 1 : 0,
        'updated_at': now,
      },
      where: 'txid = ?',
      whereArgs: [txid],
    );
  }

  Future<void> deleteTransactionCategory(String txid) async {
    final db = await database;
    await db.delete(
      'transaction_categories',
      where: 'txid = ?',
      whereArgs: [txid],
    );
  }

  /// Get transaction count by category type
  Future<Map<String, int>> getCategoryTypeCounts() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT category_type, COUNT(*) as count
      FROM transaction_categories
      GROUP BY category_type
      ORDER BY count DESC
    ''');

    final Map<String, int> counts = {};
    for (final row in results) {
      counts[row['category_type'] as String] = row['count'] as int;
    }

    return counts;
  }

  // Address Label CRUD operations

  /// Insert a new address label
  Future<int> insertAddressLabel(AddressLabel label) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    return await db.insert(
      'address_labels',
      {
        'address': label.address,
        'label_name': label.labelName,
        'category': label.category.toString().split('.').last,
        'type': label.type.toString().split('.').last,
        'description': label.description,
        'color': label.color,
        'is_owned': label.isOwned ? 1 : 0,
        'is_active': label.isActive ? 1 : 0,
        'created_at': now,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get address label by ID
  Future<AddressLabel?> getAddressLabel(int id) async {
    final db = await database;
    final results = await db.query(
      'address_labels',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (results.isNotEmpty) {
      return _addressLabelFromMap(results.first);
    }
    return null;
  }

  /// Get all labels for a specific address
  Future<List<AddressLabel>> getAddressLabels(String address) async {
    final db = await database;
    final results = await db.query(
      'address_labels',
      where: 'address = ? AND is_active = 1',
      whereArgs: [address],
      orderBy: 'created_at DESC',
    );

    return results.map((row) => _addressLabelFromMap(row)).toList();
  }

  /// Get all address labels with optional filters
  Future<List<AddressLabel>> getAllAddressLabels({
    AddressLabelCategory? category,
    bool? isOwned,
    bool activeOnly = true,
  }) async {
    final db = await database;

    String whereClause = '';
    List<Object?> whereArgs = [];

    List<String> conditions = [];

    if (activeOnly) {
      conditions.add('is_active = 1');
    }

    if (category != null) {
      conditions.add('category = ?');
      whereArgs.add(category.toString().split('.').last);
    }

    if (isOwned != null) {
      conditions.add('is_owned = ?');
      whereArgs.add(isOwned ? 1 : 0);
    }

    if (conditions.isNotEmpty) {
      whereClause = 'WHERE ${conditions.join(' AND ')}';
    }

    final results = await db.rawQuery('''
      SELECT * FROM address_labels
      $whereClause
      ORDER BY created_at DESC
    ''', whereArgs);

    return results.map((row) => _addressLabelFromMap(row)).toList();
  }

  /// Update an address label
  Future<void> updateAddressLabel(AddressLabel label) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'address_labels',
      {
        'label_name': label.labelName,
        'category': label.category.toString().split('.').last,
        'type': label.type.toString().split('.').last,
        'description': label.description,
        'color': label.color,
        'is_owned': label.isOwned ? 1 : 0,
        'is_active': label.isActive ? 1 : 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [label.id],
    );
  }

  /// Delete an address label (soft delete by setting is_active = 0)
  Future<void> deleteAddressLabel(int id) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'address_labels',
      {
        'is_active': 0,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Hard delete an address label
  Future<void> hardDeleteAddressLabel(int id) async {
    final db = await database;
    await db.delete(
      'address_labels',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get address labels grouped by category
  Future<Map<AddressLabelCategory, List<AddressLabel>>> getAddressLabelsByCategory({
    bool? isOwned,
    bool activeOnly = true,
  }) async {
    final labels = await getAllAddressLabels(isOwned: isOwned, activeOnly: activeOnly);
    final Map<AddressLabelCategory, List<AddressLabel>> grouped = {};

    for (final label in labels) {
      if (!grouped.containsKey(label.category)) {
        grouped[label.category] = [];
      }
      grouped[label.category]!.add(label);
    }

    return grouped;
  }

  /// Get statistics about address labels
  Future<Map<String, int>> getAddressLabelStats() async {
    final db = await database;
    final results = await db.rawQuery('''
      SELECT
        category,
        is_owned,
        COUNT(*) as count
      FROM address_labels
      WHERE is_active = 1
      GROUP BY category, is_owned
      ORDER BY category, is_owned
    ''');

    final Map<String, int> stats = {};
    for (final row in results) {
      final category = row['category'] as String;
      final isOwned = (row['is_owned'] as int) == 1;
      final count = row['count'] as int;

      final key = '${category}_${isOwned ? 'owned' : 'external'}';
      stats[key] = count;
    }

    return stats;
  }

  /// Helper method to convert database row to AddressLabel
  AddressLabel _addressLabelFromMap(Map<String, dynamic> map) {
    return AddressLabel(
      id: map['id'] as int,
      address: map['address'] as String,
      labelName: map['label_name'] as String,
      category: AddressLabelCategory.values.firstWhere(
        (e) => e.toString().split('.').last == map['category'],
        orElse: () => AddressLabelCategory.other,
      ),
      type: AddressLabelType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => AddressLabelType.custom,
      ),
      description: map['description'] as String?,
      color: map['color'] as String,
      isOwned: (map['is_owned'] as int) == 1,
      isActive: (map['is_active'] as int) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
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

  Map<String, dynamic> _contactToMap(ContactModel contact) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': contact.id,
      'name': contact.name,
      'address': contact.address,
      'type': contact.type,
      'description': contact.description,
      'picture_base64': contact.pictureBase64,
      'is_favorite': contact.isFavorite ? 1 : 0,
      'created_at': contact.createdAt.millisecondsSinceEpoch,
      'updated_at': contact.updatedAt.millisecondsSinceEpoch,
    };
  }

  ContactModel _mapToContact(Map<String, dynamic> map) {
    return ContactModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      address: map['address'] as String,
      type: map['type'] as String,
      description: map['description'] as String?,
      pictureBase64: map['picture_base64'] as String?,
      isFavorite: (map['is_favorite'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  Map<String, dynamic> _messageLabelToMap(MessageLabel label) {
    return {
      if (label.id != null) 'id': label.id,
      'txid': label.txid,
      'label_name': label.labelName,
      'label_color': label.labelColor,
      'is_auto_generated': label.isAutoGenerated ? 1 : 0,
      'created_at': label.createdAt.millisecondsSinceEpoch,
      'updated_at': label.updatedAt.millisecondsSinceEpoch,
    };
  }

  MessageLabel _mapToMessageLabel(Map<String, dynamic> map) {
    return MessageLabel(
      id: map['id'] as int?,
      txid: map['txid'] as String,
      labelName: map['label_name'] as String,
      labelColor: map['label_color'] as String? ?? '#2196F3',
      isAutoGenerated: (map['is_auto_generated'] as int? ?? 0) == 1,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updated_at'] as int),
    );
  }

  // Notification CRUD operations
  Future<void> insertNotification(Map<String, dynamic> notification) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    notification['created_at'] = now;
    notification['updated_at'] = now;

    await db.insert(
      'notifications',
      notification,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getNotifications({
    int? limit,
    int? offset,
    String? type,
    String? category,
    bool? isRead,
  }) async {
    final db = await database;
    String whereClause = '';
    List<dynamic> whereArgs = [];

    if (type != null) {
      whereClause += 'type = ?';
      whereArgs.add(type);
    }

    if (category != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'category = ?';
      whereArgs.add(category);
    }

    if (isRead != null) {
      if (whereClause.isNotEmpty) whereClause += ' AND ';
      whereClause += 'is_read = ?';
      whereArgs.add(isRead ? 1 : 0);
    }

    return await db.query(
      'notifications',
      where: whereClause.isNotEmpty ? whereClause : null,
      whereArgs: whereArgs.isNotEmpty ? whereArgs : null,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<int> getUnreadNotificationCount() async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notifications WHERE is_read = 0'
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    final db = await database;
    await db.update(
      'notifications',
      {
        'is_read': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  Future<void> markAllNotificationsAsRead() async {
    final db = await database;
    await db.update(
      'notifications',
      {
        'is_read': 1,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'is_read = 0',
    );
  }

  Future<void> deleteNotification(String notificationId) async {
    final db = await database;
    await db.delete(
      'notifications',
      where: 'id = ?',
      whereArgs: [notificationId],
    );
  }

  Future<void> deleteAllNotifications() async {
    final db = await database;
    await db.delete('notifications');
  }

  Future<void> cleanupOldNotifications({int daysToKeep = 30}) async {
    final db = await database;
    final cutoffTime = DateTime.now()
        .subtract(Duration(days: daysToKeep))
        .millisecondsSinceEpoch;

    await db.delete(
      'notifications',
      where: 'timestamp < ?',
      whereArgs: [cutoffTime],
    );
  }
}