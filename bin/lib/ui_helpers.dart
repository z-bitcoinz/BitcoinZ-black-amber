import 'dart:io';
import 'dart:math';
import 'dart:async';
import 'package:chalkdart/chalkdart.dart';
import 'package:mason_logger/mason_logger.dart';

/// UI helpers for the interactive CLI
class UIHelpers {
  final _logger = Logger();
  /// Show a progress bar
  void showProgress(String label, double progress, {int width = 40}) {
    final completed = (progress * width).round();
    final remaining = width - completed;
    
    final bar = chalk.green('█' * completed) + chalk.gray('░' * remaining);
    final percentage = (progress * 100).toStringAsFixed(1);
    
    stdout.write('\r$label [$bar] $percentage%');
    if (progress >= 1.0) {
      stdout.write('\n');
    }
  }
  
  /// Show spinner animation
  void showSpinner(String message, {int frame = 0}) {
    const frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];
    final spinner = frames[frame % frames.length];
    stdout.write('\r${chalk.blue(spinner)} $message');
  }
  
  /// Clear current line
  void clearLine() {
    stdout.write('\r${' ' * 80}\r');
  }
  
  /// Format BitcoinZ amount
  String formatBTCZ(int zatoshis) {
    final btcz = zatoshis / 100000000.0;
    return btcz.toStringAsFixed(8);
  }
  
  /// Format file size
  String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  
  /// Format duration
  String formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      return '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    } else {
      return '${duration.inSeconds}s';
    }
  }
  
  /// Show a table
  void showTable(List<List<String>> rows, {List<String>? headers}) {
    if (rows.isEmpty) return;
    
    // Calculate column widths
    final colCount = rows.first.length;
    final widths = List.filled(colCount, 0);
    
    // Include headers in width calculation
    if (headers != null) {
      for (int i = 0; i < headers.length && i < colCount; i++) {
        widths[i] = max(widths[i], headers[i].length);
      }
    }
    
    // Calculate widths from data
    for (final row in rows) {
      for (int i = 0; i < row.length && i < colCount; i++) {
        widths[i] = max(widths[i], row[i].length);
      }
    }
    
    // Print headers
    if (headers != null) {
      final headerRow = <String>[];
      for (int i = 0; i < headers.length && i < colCount; i++) {
        headerRow.add(headers[i].padRight(widths[i]));
      }
      print(chalk.cyan.bold(headerRow.join(' │ ')));
      print(chalk.gray('─' * headerRow.join(' │ ').length));
    }
    
    // Print data rows
    for (final row in rows) {
      final formattedRow = <String>[];
      for (int i = 0; i < row.length && i < colCount; i++) {
        formattedRow.add(row[i].padRight(widths[i]));
      }
      print(formattedRow.join(' │ '));
    }
  }
  
  /// Show a box with title and content
  void showBox(String title, String content, {String? footer}) {
    final lines = content.split('\n');
    final maxWidth = lines.map((l) => l.length).reduce(max);
    final boxWidth = max(maxWidth, title.length) + 4;
    
    // Top border
    print('┌─ ${chalk.bold(title)} ${'─' * (boxWidth - title.length - 3)}┐');
    
    // Content
    for (final line in lines) {
      print('│ ${line.padRight(boxWidth - 3)} │');
    }
    
    // Footer
    if (footer != null) {
      print('├─${'─' * (boxWidth - 2)}┤');
      print('│ ${chalk.gray(footer).padRight(boxWidth - 3)} │');
    }
    
    // Bottom border
    print('└─${'─' * (boxWidth - 2)}┘');
  }
  
  /// Get terminal width
  int get terminalWidth {
    try {
      return stdout.terminalColumns;
    } catch (e) {
      return 80; // Default width
    }
  }
  
  /// Get terminal height
  int get terminalHeight {
    try {
      return stdout.terminalLines;
    } catch (e) {
      return 24; // Default height
    }
  }
  
  /// Center text in terminal
  String centerText(String text) {
    final padding = ((terminalWidth - text.length) / 2).floor();
    return ' ' * padding + text;
  }
  
  /// Truncate text to fit width
  String truncateText(String text, int maxWidth) {
    if (text.length <= maxWidth) return text;
    return '${text.substring(0, maxWidth - 3)}...';
  }
  
  /// Prompt user for input with validation
  String? promptInput(String message, {bool required = false, String? defaultValue}) {
    while (true) {
      if (defaultValue != null) {
        stdout.write('$message [${chalk.gray(defaultValue)}]: ');
      } else {
        stdout.write('$message: ');
      }
      
      final input = stdin.readLineSync()?.trim();
      
      if (input == null || input.isEmpty) {
        if (defaultValue != null) {
          return defaultValue;
        } else if (required) {
          print(chalk.red('This field is required'));
          continue;
        } else {
          return null;
        }
      }
      
      return input;
    }
  }
  
  /// Prompt user for yes/no confirmation
  bool promptConfirm(String message, {bool defaultValue = false}) {
    final defaultText = defaultValue ? 'Y/n' : 'y/N';
    stdout.write('$message [$defaultText]: ');
    
    final input = stdin.readLineSync()?.trim().toLowerCase();
    
    if (input == null || input.isEmpty) {
      return defaultValue;
    }
    
    return input.startsWith('y');
  }
  
  /// Create a spinner that tracks progress with mason_logger
  Progress spinner(String message) {
    return _logger.progress(message);
  }
  
  /// Print a styled box (simpler version for wallet commands)
  void printBox({required String title, required String content, String color = 'blue'}) {
    final colorFn = color == 'cyan' ? chalk.cyan :
                    color == 'green' ? chalk.green :
                    color == 'yellow' ? chalk.yellow :
                    chalk.blue;
    
    print('');
    print(colorFn.bold('╭─ $title ──────────────────────────────────╮'));
    print('│                                            │');
    
    // Wrap content if too long
    final lines = <String>[];
    final words = content.split(' ');
    String currentLine = '';
    
    for (final word in words) {
      if ((currentLine + ' ' + word).length > 40) {
        if (currentLine.isNotEmpty) lines.add(currentLine);
        currentLine = word;
      } else {
        currentLine = currentLine.isEmpty ? word : '$currentLine $word';
      }
    }
    if (currentLine.isNotEmpty) lines.add(currentLine);
    
    for (final line in lines) {
      print('│ ${line.padRight(42)} │');
    }
    
    print('│                                            │');
    print('╰────────────────────────────────────────────╯');
    print('');
  }
}