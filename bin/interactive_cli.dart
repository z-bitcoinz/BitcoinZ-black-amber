#!/usr/bin/env dart

import 'dart:io';
import 'dart:async';
import 'package:chalkdart/chalkdart.dart';
import 'package:mason_logger/mason_logger.dart';

import 'lib/interactive_shell.dart';
import 'lib/wallet_session.dart';

void main(List<String> arguments) async {
  // Initialize logger with colors
  final logger = Logger(
    theme: LogTheme(),
  );

  // Print welcome banner
  print('');
  print(chalk.blue.bold('🚀 BitcoinZ Interactive Wallet CLI v2.0'));
  print(chalk.gray('━' * 60));
  print('');

  // Handle command line arguments
  if (arguments.isNotEmpty) {
    if (arguments.contains('--help') || arguments.contains('-h')) {
      _printHelp();
      return;
    }
    if (arguments.contains('--version')) {
      print('BitcoinZ Interactive Wallet CLI v2.0');
      return;
    }
  }

  try {
    // Initialize wallet session
    final session = WalletSession();
    await session.initialize();

    // Create and run interactive shell
    final shell = InteractiveShell(session: session, logger: logger);
    await shell.run();

  } catch (e) {
    logger.err('Failed to initialize wallet: $e');
    exit(1);
  }
}

void _printHelp() {
  print('BitcoinZ Interactive Wallet CLI v2.0\n');
  print('Usage: dart run bin/interactive_cli.dart [options]\n');
  print('Options:');
  print('  -h, --help     Show this help message');
  print('  --version      Show version information');
  print('');
  print('Interactive Commands (once inside):');
  print('  help           Show all available commands');
  print('  create         Create a new wallet');
  print('  restore        Restore wallet from seed phrase');
  print('  balance        Show wallet balance');
  print('  sync           Sync with blockchain');
  print('  addresses      List all addresses');
  print('  send           Send BitcoinZ to an address');
  print('  exit           Exit the interactive shell');
  print('');
  print('Examples:');
  print('  dart run bin/interactive_cli.dart');
  print('  # Then in interactive mode:');
  print('  bitcoinz> help');
  print('  bitcoinz> create');
  print('  bitcoinz> balance');
  print('  bitcoinz> exit');
}