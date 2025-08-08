import 'dart:io';
import 'dart:async';
import 'package:chalkdart/chalkdart.dart';
import 'package:mason_logger/mason_logger.dart';

import 'wallet_session.dart';
import 'command_parser.dart';
import 'ui_helpers.dart';
import 'wallet_commands.dart';

/// Main interactive shell for BitcoinZ wallet
class InteractiveShell {
  final WalletSession session;
  final Logger logger;
  final CommandParser _commandParser;
  final UIHelpers _ui;
  late final WalletCommands _walletCommands;
  
  bool _isRunning = true;
  List<String> _commandHistory = [];
  int _historyIndex = -1;

  InteractiveShell({required this.session, required this.logger})
      : _commandParser = CommandParser(),
        _ui = UIHelpers() {
    _walletCommands = WalletCommands(session: session, ui: _ui);
    _initializeWalletCommands();
  }
  
  Future<void> _initializeWalletCommands() async {
    try {
      await _walletCommands.initialize();
    } catch (e) {
      logger.warn('Failed to initialize wallet commands: $e');
    }
  }

  /// Main interactive loop
  Future<void> run() async {
    _printWelcome();
    await _checkWalletStatus();
    
    while (_isRunning) {
      try {
        final command = await _readCommand();
        if (command.trim().isEmpty) continue;
        
        // Add to history
        _commandHistory.add(command);
        _historyIndex = _commandHistory.length;
        
        // Process command
        await _processCommand(command.trim());
        session.incrementCommandCount();
        
      } catch (e) {
        logger.err('Command error: $e');
      }
    }
    
    _printGoodbye();
  }

  /// Print welcome message with status
  void _printWelcome() {
    print('');
    if (session.hasWallet) {
      final state = session.walletState!;
      print(chalk.green('📂 Wallet loaded: ${state.walletId.substring(0, 8)}...'));
      print(chalk.blue('   ${state.transparentAddresses.length} transparent, ${state.shieldedAddresses.length} shielded addresses'));
      print(chalk.gray('   Last sync: ${_formatRelativeTime(state.lastSync)}'));
    } else {
      print(chalk.yellow('⚠️  No wallet loaded'));
      print(chalk.gray('   Use ${chalk.cyan('create')} or ${chalk.cyan('restore')} to get started'));
    }
    
    print('');
    print(chalk.gray('💡 Type ${chalk.cyan('help')} for commands or ${chalk.cyan('tutorial')} for getting started'));
    print(chalk.gray('━' * 60));
    print('');
  }
  
  /// Check and display wallet status
  Future<void> _checkWalletStatus() async {
    // This could be expanded to do health checks
  }

  /// Read command from user with prompt
  Future<String> _readCommand() async {
    // Show status bar
    _showStatusBar();
    
    // Show prompt
    stdout.write('${chalk.blue.bold('bitcoinz')}${chalk.gray('>')} ');
    
    // Read line
    final input = stdin.readLineSync() ?? '';
    
    return input;
  }
  
  /// Show status bar with wallet info
  void _showStatusBar() {
    if (!session.hasWallet) return;
    
    final state = session.walletState!;
    final statusItems = <String>[];
    
    // Wallet ID (short)
    statusItems.add('Wallet: ${state.walletId.substring(0, 8)}...');
    
    // Balance placeholder (will be real later)
    statusItems.add('Balance: 0.00000000 BTCZ');
    
    // Sync status
    final timeSinceSync = DateTime.now().difference(state.lastSync);
    if (timeSinceSync.inMinutes < 5) {
      statusItems.add(chalk.green('Synced'));
    } else if (timeSinceSync.inHours < 1) {
      statusItems.add(chalk.yellow('${timeSinceSync.inMinutes}m ago'));
    } else {
      statusItems.add(chalk.red('${timeSinceSync.inHours}h ago'));
    }
    
    // Print compact status line without newline
    final statusLine = statusItems.join(' │ ');
    stdout.write(chalk.gray('┌─ $statusLine\n'));
  }

  /// Process user command
  Future<void> _processCommand(String commandLine) async {
    final command = _commandParser.parse(commandLine);
    
    switch (command.name.toLowerCase()) {
      case 'help':
      case 'h':
      case '?':
        _showHelp(command.args);
        break;
        
      case 'exit':
      case 'quit':
      case 'q':
        _isRunning = false;
        break;
        
      case 'clear':
      case 'cls':
        _clearScreen();
        break;
        
      case 'info':
      case 'status':
        _showWalletInfo();
        break;
        
      case 'session':
        _showSessionInfo();
        break;
        
      case 'create':
        await _createWallet(command.args);
        break;
        
      case 'restore':
        await _restoreWallet(command.args);
        break;
        
      case 'destroy':
      case 'destroy-wallet':
        _destroyWallet();
        break;
        
      case 'balance':
      case 'bal':
      case 'b':
        await _showBalance();
        break;
        
      case 'addresses':
      case 'addr':
      case 'ls':
        _showAddresses();
        break;
        
      case 'sync':
      case 's':
        await _syncWallet(command.args);
        break;
        
      case 'generate':
      case 'gen':
      case 'new':
        await _generateAddress(command.args);
        break;
        
      case 'send':
      case 'pay':
        await _sendTransaction(command.args);
        break;
        
      case 'transactions':
      case 'tx':
      case 'history':
        await _showTransactions();
        break;
        
      case 'tutorial':
        _showTutorial();
        break;
        
      default:
        logger.warn('Unknown command: ${command.name}');
        print(chalk.gray('Type ${chalk.cyan('help')} for available commands'));
        break;
    }
  }

  /// Show help information
  void _showHelp([List<String> args = const []]) {
    if (args.isEmpty) {
      _showGeneralHelp();
    } else {
      _showCommandHelp(args.first);
    }
  }
  
  void _showGeneralHelp() {
    print('');
    print(chalk.blue.bold('🔧 Available Commands:'));
    print('');
    
    final commands = [
      ['📋 Wallet Management:', ''],
      ['  create', 'Create a new wallet with seed phrase'],
      ['  restore', 'Restore wallet from seed phrase'],
      ['  info', 'Show current wallet information'],
      ['  destroy', 'Clear saved wallet state'],
      ['', ''],
      ['💰 Balance & Sync:', ''],
      ['  balance, bal, b', 'Show wallet balance'],
      ['  sync, s', 'Sync with blockchain'],
      ['', ''],
      ['📍 Address Management:', ''],
      ['  addresses, addr, ls', 'List all addresses'],
      ['  generate, gen, new', 'Generate new address'],
      ['', ''],
      ['💸 Transactions:', ''],
      ['  send, pay', 'Send BitcoinZ to address'],
      ['  transactions, tx', 'Show transaction history'],
      ['', ''],
      ['⚙️ System:', ''],
      ['  help, h, ?', 'Show this help'],
      ['  tutorial', 'Interactive tutorial'],
      ['  session', 'Show session information'],
      ['  clear, cls', 'Clear screen'],
      ['  exit, quit, q', 'Exit interactive mode'],
    ];
    
    for (final cmd in commands) {
      if (cmd[0].isEmpty) {
        print('');
      } else if (cmd[1].isEmpty) {
        print(chalk.cyan.bold(cmd[0]));
      } else {
        print('${chalk.cyan(cmd[0].padRight(20))} ${chalk.gray(cmd[1])}');
      }
    }
    
    print('');
    print(chalk.gray('💡 Use ${chalk.cyan('help <command>')} for detailed help on specific commands'));
    print('');
  }

  void _showCommandHelp(String commandName) {
    // TODO: Implement detailed help for specific commands
    print(chalk.gray('Detailed help for "$commandName" coming soon...'));
  }

  /// Clear screen
  void _clearScreen() {
    if (Platform.isWindows) {
      Process.runSync('cls', [], runInShell: true);
    } else {
      Process.runSync('clear', [], runInShell: true);
    }
    _printWelcome();
  }

  /// Show wallet information
  void _showWalletInfo() {
    if (!session.hasWallet) {
      print(chalk.yellow('⚠️  No wallet loaded'));
      print(chalk.gray('   Use ${chalk.cyan('create')} or ${chalk.cyan('restore')} to get started'));
      return;
    }
    
    final state = session.walletState!;
    print('');
    print(chalk.blue.bold('📱 Current Wallet Info:'));
    print('🆔 Wallet ID: ${state.walletId}');
    print('🎂 Birthday Height: ${state.birthdayHeight}');
    print('🌐 Server: ${state.serverUrl}');
    print('🕐 Last Sync: ${state.lastSync}');
    print('📍 Addresses:');
    print('   Transparent: ${state.transparentAddresses.length}');
    print('   Shielded: ${state.shieldedAddresses.length}');
    print('');
  }

  /// Show session information
  void _showSessionInfo() {
    final info = session.sessionInfo;
    print('');
    print(chalk.blue.bold('⚡ Session Information:'));
    print('Started: ${info['started']}');
    print('Duration: ${session.sessionDuration}');
    print('Commands: ${info['commands_executed']}');
    print('Wallet loaded: ${info['has_wallet'] ? 'Yes' : 'No'}');
    if (info['wallet_id'] != null) {
      print('Wallet ID: ${info['wallet_id']}');
    }
    print('');
  }

  /// Create wallet
  Future<void> _createWallet(List<String> args) async {
    await _walletCommands.createWallet();
  }

  /// Restore wallet
  Future<void> _restoreWallet(List<String> args) async {
    await _walletCommands.restoreWallet();
  }

  /// Destroy wallet
  void _destroyWallet() {
    if (!session.hasWallet) {
      print(chalk.yellow('⚠️  No wallet to destroy'));
      return;
    }
    
    print(chalk.red.bold('⚠️  This will permanently delete your wallet state!'));
    stdout.write('Are you sure? Type "yes" to confirm: ');
    final confirmation = stdin.readLineSync() ?? '';
    
    if (confirmation.toLowerCase() == 'yes') {
      session.clearWallet();
      print(chalk.green('✅ Wallet state cleared'));
    } else {
      print(chalk.gray('Cancelled'));
    }
  }

  /// Show balance
  Future<void> _showBalance() async {
    await _walletCommands.showBalance();
  }

  /// Show addresses
  void _showAddresses() {
    if (!session.hasWallet) {
      print(chalk.yellow('⚠️  No wallet loaded'));
      return;
    }
    
    final state = session.walletState!;
    print('');
    print(chalk.blue.bold('📍 Wallet Addresses:'));
    
    if (state.transparentAddresses.isNotEmpty) {
      print('');
      print(chalk.cyan('Transparent Addresses:'));
      for (int i = 0; i < state.transparentAddresses.length; i++) {
        print('  [$i]: ${state.transparentAddresses[i]}');
      }
    }
    
    if (state.shieldedAddresses.isNotEmpty) {
      print('');
      print(chalk.magenta('Shielded Addresses:'));
      for (int i = 0; i < state.shieldedAddresses.length; i++) {
        print('  [$i]: ${state.shieldedAddresses[i]}');
      }
    }
    
    print('');
  }

  /// Sync wallet
  Future<void> _syncWallet(List<String> args) async {
    await _walletCommands.syncWallet();
  }

  /// Generate address
  Future<void> _generateAddress(List<String> args) async {
    final type = args.isNotEmpty ? args[0] : 'transparent';
    await _walletCommands.generateAddress(type);
  }

  /// Send transaction
  Future<void> _sendTransaction(List<String> args) async {
    await _walletCommands.sendTransaction();
  }

  /// Show transactions
  Future<void> _showTransactions() async {
    await _walletCommands.showTransactionHistory();
  }

  /// Show interactive tutorial
  void _showTutorial() {
    print('');
    print(chalk.blue.bold('🎓 BitcoinZ Wallet Tutorial:'));
    print('');
    print('1. ${chalk.cyan('create')} - Create a new wallet with a seed phrase');
    print('2. ${chalk.cyan('restore')} - Restore an existing wallet');
    print('3. ${chalk.cyan('sync')} - Sync with the BitcoinZ blockchain');
    print('4. ${chalk.cyan('balance')} - Check your balance');
    print('5. ${chalk.cyan('addresses')} - View your addresses');
    print('6. ${chalk.cyan('send')} - Send BitcoinZ to others');
    print('');
    print(chalk.gray('💡 Each command has shortcuts - try ${chalk.cyan('bal')} instead of ${chalk.cyan('balance')}'));
    print('');
  }

  /// Print goodbye message
  void _printGoodbye() {
    print('');
    print(chalk.gray('━' * 60));
    print(chalk.blue('💾 Session saved'));
    print('📊 Commands executed: ${session.sessionInfo['commands_executed']}');
    print('⏱️  Session duration: ${session.sessionDuration}');
    print('');
    print(chalk.green.bold('👋 Goodbye! Your BitcoinZ wallet session has been saved.'));
    print('');
  }

  /// Format relative time
  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else {
      return 'Just now';
    }
  }
}