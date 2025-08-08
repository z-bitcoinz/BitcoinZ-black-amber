/// Simple command parser for interactive CLI
class Command {
  final String name;
  final List<String> args;
  final Map<String, String> options;

  Command({
    required this.name,
    this.args = const [],
    this.options = const {},
  });

  @override
  String toString() {
    return 'Command(name: $name, args: $args, options: $options)';
  }
}

/// Parses user input into structured commands
class CommandParser {
  /// Parse a command line into a Command object
  Command parse(String commandLine) {
    final parts = _splitCommandLine(commandLine);
    
    if (parts.isEmpty) {
      return Command(name: '');
    }
    
    final name = parts.first;
    final args = <String>[];
    final options = <String, String>{};
    
    // Parse arguments and options
    for (int i = 1; i < parts.length; i++) {
      final part = parts[i];
      
      if (part.startsWith('--')) {
        // Long option: --option=value or --option value
        final optionName = part.substring(2);
        if (optionName.contains('=')) {
          final split = optionName.split('=');
          options[split[0]] = split.sublist(1).join('=');
        } else {
          // Look for value in next part
          if (i + 1 < parts.length && !parts[i + 1].startsWith('-')) {
            i++;
            options[optionName] = parts[i];
          } else {
            options[optionName] = 'true';
          }
        }
      } else if (part.startsWith('-') && part.length > 1) {
        // Short option: -o value or -o
        final optionName = part.substring(1);
        if (i + 1 < parts.length && !parts[i + 1].startsWith('-')) {
          i++;
          options[optionName] = parts[i];
        } else {
          options[optionName] = 'true';
        }
      } else {
        // Regular argument
        args.add(part);
      }
    }
    
    return Command(
      name: name,
      args: args,
      options: options,
    );
  }
  
  /// Split command line respecting quotes
  List<String> _splitCommandLine(String commandLine) {
    final parts = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    bool inSingleQuotes = false;
    bool escaped = false;
    
    for (int i = 0; i < commandLine.length; i++) {
      final char = commandLine[i];
      
      if (escaped) {
        buffer.write(char);
        escaped = false;
        continue;
      }
      
      if (char == '\\') {
        escaped = true;
        continue;
      }
      
      if (char == '"' && !inSingleQuotes) {
        inQuotes = !inQuotes;
        continue;
      }
      
      if (char == "'" && !inQuotes) {
        inSingleQuotes = !inSingleQuotes;
        continue;
      }
      
      if (char == ' ' && !inQuotes && !inSingleQuotes) {
        if (buffer.isNotEmpty) {
          parts.add(buffer.toString());
          buffer.clear();
        }
        continue;
      }
      
      buffer.write(char);
    }
    
    if (buffer.isNotEmpty) {
      parts.add(buffer.toString());
    }
    
    return parts;
  }
  
  /// Get command suggestions for auto-completion
  List<String> getSuggestions(String partial) {
    final commands = [
      'help', 'h', '?',
      'create', 'restore', 'destroy',
      'info', 'status', 'session',
      'balance', 'bal', 'b',
      'addresses', 'addr', 'ls',
      'sync', 's',
      'generate', 'gen', 'new',
      'send', 'pay',
      'transactions', 'tx', 'history',
      'tutorial',
      'clear', 'cls',
      'exit', 'quit', 'q',
    ];
    
    return commands
        .where((cmd) => cmd.startsWith(partial.toLowerCase()))
        .toList()
        ..sort();
  }
}