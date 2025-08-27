import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:file_selector/file_selector.dart';
import '../../providers/contact_provider.dart';

class ContactsBackupScreen extends StatefulWidget {
  const ContactsBackupScreen({super.key});

  @override
  State<ContactsBackupScreen> createState() => _ContactsBackupScreenState();
}

class _ContactsBackupScreenState extends State<ContactsBackupScreen> {
  final _passwordController = TextEditingController();
  final _importPasswordController = TextEditingController();
  final _importDataController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isImportPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    _importPasswordController.dispose();
    _importDataController.dispose();
    super.dispose();
  }

  Future<void> _exportContacts() async {
    if (_passwordController.text.trim().isEmpty) {
      _showError('Please enter a password to encrypt the backup');

      // Show additional guidance
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A password is required to encrypt your contacts backup'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    if (_passwordController.text.trim().length < 6) {
      _showError('Password must be at least 6 characters long');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Use a stronger password (minimum 6 characters)'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final contactProvider = Provider.of<ContactProvider>(context, listen: false);
      final backupData = await contactProvider.exportContacts(_passwordController.text.trim());

      if (backupData != null && mounted) {
        // Save to file and share
        await _saveAndShareBackup(backupData);

        _passwordController.clear();
        _showSuccess('Contacts backup created successfully! Keep your password safe.');

        // Show additional success guidance
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.backup, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Backup created! Store both the file and password securely.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        _showError('Failed to create backup');
      }
    } catch (e) {
      _showError('Export failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveAndShareBackup(String backupData) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'bitcoinz_contacts_backup_$timestamp.txt';

      if (Platform.isMacOS || Platform.isWindows || Platform.isLinux) {
        // Use file save dialog for desktop platforms
        final FileSaveLocation? result = await getSaveLocation(
          suggestedName: fileName,
          acceptedTypeGroups: [
            const XTypeGroup(
              label: 'Text files',
              extensions: ['txt'],
            ),
          ],
        );

        if (result != null) {
          final file = File(result.path);
          await file.writeAsString(backupData);
          _showSuccess('Backup saved successfully to: ${result.path}');
        } else {
          // User cancelled the save dialog
          _showError('Save cancelled');
        }
      } else {
        // Use sharing for mobile platforms
        final directory = await getApplicationDocumentsDirectory();
        final file = File('${directory.path}/$fileName');

        await file.writeAsString(backupData);

        // Share the file
        final result = await Share.shareXFiles(
          [XFile(file.path)],
          text: 'BitcoinZ Contacts Backup',
          subject: 'BitcoinZ Contacts Backup - $fileName',
        );

        if (result.status == ShareResultStatus.success) {
          // Optionally delete the file after sharing
          // await file.delete();
        }
      }
    } catch (e) {
      _showError('Failed to save/share backup: $e');
    }
  }

  Future<void> _importContacts() async {
    // Validate password first
    if (_importPasswordController.text.trim().isEmpty) {
      _showError('Please enter the backup password to decrypt and import your contacts');

      // Show a snackbar with additional guidance
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password is required to decrypt the backup file'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Validate backup data
    if (_importDataController.text.trim().isEmpty) {
      _showError('Please paste the backup data or load it from a file');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No backup data found. Please paste or load from file'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Validate password length
    if (_importPasswordController.text.trim().length < 6) {
      _showError('Password must be at least 6 characters long');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final contactProvider = Provider.of<ContactProvider>(context, listen: false);
      final success = await contactProvider.importContacts(
        _importDataController.text.trim(),
        _importPasswordController.text.trim(),
      );

      if (success && mounted) {
        _importPasswordController.clear();
        _importDataController.clear();

        // Show success message
        _showSuccess('Contacts imported successfully! Your contacts have been restored.');

        // Show success snackbar with more details
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Contacts imported successfully! Check your contacts list.',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            margin: const EdgeInsets.all(16),
          ),
        );
      } else {
        final errorMsg = contactProvider.errorMessage ?? 'Import failed';
        _showError('Import failed: $errorMsg');

        // Show additional guidance for common errors
        if (errorMsg.toLowerCase().contains('password') ||
            errorMsg.toLowerCase().contains('decrypt')) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Incorrect password. Please check your backup password.'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      }
    } catch (e) {
      String errorMessage = 'Import failed: $e';

      // Provide more user-friendly error messages
      if (e.toString().toLowerCase().contains('password')) {
        errorMessage = 'Incorrect password. Please verify your backup password.';
      } else if (e.toString().toLowerCase().contains('format')) {
        errorMessage = 'Invalid backup format. Please check your backup data.';
      }

      _showError(errorMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    try {
      final clipboardData = await Clipboard.getData('text/plain');
      if (clipboardData?.text != null) {
        _importDataController.text = clipboardData!.text!;

        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pasted from clipboard'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      } else {
        _showError('Clipboard is empty');
      }
    } catch (e) {
      _showError('Failed to paste from clipboard: $e');
    }
  }

  Future<void> _loadFromFile() async {
    try {
      const XTypeGroup typeGroup = XTypeGroup(
        label: 'Text files',
        extensions: ['txt'],
      );

      final XFile? file = await openFile(
        acceptedTypeGroups: [typeGroup],
      );

      if (file != null) {
        final String contents = await file.readAsString();
        _importDataController.text = contents;

        HapticFeedback.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Loaded backup file: ${file.name}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to load file: $e');
    }
  }

  void _showError(String message) {
    setState(() {
      _errorMessage = message;
      _successMessage = null;
    });
  }

  void _showSuccess(String message) {
    setState(() {
      _successMessage = message;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts Backup'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      body: Consumer<ContactProvider>(
        builder: (context, contactProvider, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status messages
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (_successMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _successMessage!,
                            style: const TextStyle(color: Colors.green),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Export section
                _buildSection(
                  title: 'Export Contacts',
                  icon: Icons.upload,
                  children: [
                    Text(
                      'Create an encrypted backup of your contacts. You can share this backup file and restore it later.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Contact count
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.contacts, color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            '${contactProvider.contactsCount} contact${contactProvider.contactsCount == 1 ? '' : 's'} available to backup',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Password field
                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Backup Password',
                        hintText: 'Enter password to encrypt backup',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_isPasswordVisible ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setState(() {
                              _isPasswordVisible = !_isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),
                    
                    // Export button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: contactProvider.hasContacts && !_isLoading ? _exportContacts : null,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.upload),
                        label: Text(
                          _isLoading ? 'Creating Backup...' : 'Create Backup',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Import section
                _buildSection(
                  title: 'Import Contacts',
                  icon: Icons.download,
                  children: [
                    Text(
                      'Restore contacts from an encrypted backup. Paste the backup data below and enter the password you used to create it.',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.7),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Password field
                    TextFormField(
                      controller: _importPasswordController,
                      obscureText: !_isImportPasswordVisible,
                      decoration: InputDecoration(
                        labelText: 'Backup Password',
                        hintText: 'Enter the password used for encryption',
                        prefixIcon: const Icon(Icons.lock),
                        suffixIcon: IconButton(
                          icon: Icon(_isImportPasswordVisible ? Icons.visibility_off : Icons.visibility),
                          onPressed: () {
                            setState(() {
                              _isImportPasswordVisible = !_isImportPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),
                    
                    // Backup data field
                    TextFormField(
                      controller: _importDataController,
                      decoration: InputDecoration(
                        labelText: 'Backup Data',
                        hintText: 'Paste your backup data here or load from file',
                        prefixIcon: const Icon(Icons.data_object),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (Platform.isMacOS || Platform.isWindows || Platform.isLinux)
                              IconButton(
                                icon: const Icon(Icons.folder_open),
                                onPressed: _isLoading ? null : _loadFromFile,
                                tooltip: 'Load from file',
                              ),
                            IconButton(
                              icon: const Icon(Icons.paste),
                              onPressed: _isLoading ? null : _pasteFromClipboard,
                              tooltip: 'Paste from clipboard',
                            ),
                          ],
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        alignLabelWithHint: true,
                      ),
                      maxLines: 4,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      enabled: !_isLoading,
                    ),
                    const SizedBox(height: 16),
                    
                    // Import button
                    SizedBox(
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: !_isLoading ? _importContacts : null,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Icon(Icons.download),
                        label: Text(
                          _isLoading ? 'Importing...' : 'Import Contacts',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Important notes
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Important Notes',
                            style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '• Backups are encrypted with your chosen password\n'
                        '• Store your backup and password safely\n'
                        '• Importing will add to existing contacts (duplicates replaced)\n'
                        '• Contact pictures are included in the backup\n'
                        '• Backup files are safe to share via email or cloud storage',
                        style: TextStyle(
                          color: Colors.amber,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }
}