import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import '../../providers/network_provider.dart';

class NetworkSettingsScreen extends StatefulWidget {
  const NetworkSettingsScreen({super.key});

  @override
  State<NetworkSettingsScreen> createState() => _NetworkSettingsScreenState();
}

class _NetworkSettingsScreenState extends State<NetworkSettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Start periodic refresh when entering network settings screen
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final networkProvider = Provider.of<NetworkProvider>(context, listen: false);
      networkProvider.startPeriodicRefresh();
    });
  }
  
  @override
  void dispose() {
    // Stop periodic refresh when leaving network settings screen
    final networkProvider = Provider.of<NetworkProvider>(context, listen: false);
    networkProvider.stopPeriodicRefresh(); // Stop only the timer
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: AppBar(
              backgroundColor: const Color(0xFF1A1A1A).withOpacity(0.8),
              elevation: 0,
              toolbarHeight: 60,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text(
                'Network Settings',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              flexibleSpace: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1F1F1F).withOpacity(0.8),
                      const Color(0xFF151515).withOpacity(0.6),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.white.withOpacity(0.05),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Consumer<NetworkProvider>(
        builder: (context, networkProvider, child) {
          return Column(
            children: [
              const SizedBox(height: 80),
              
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Current Server Status
                    _buildCurrentServerCard(networkProvider),
                    const SizedBox(height: 24),
                    
                    // Server List
                    _buildServerListSection(networkProvider),
                    const SizedBox(height: 24),
                    
                    // Add Custom Server Button
                    _buildAddCustomServerButton(networkProvider),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCurrentServerCard(NetworkProvider networkProvider) {
    final currentServer = networkProvider.getServerInfo(networkProvider.currentServerUrl);
    
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.primary.withOpacity(0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.wifi,
                color: Theme.of(context).colorScheme.primary,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Current Server',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Text(
            currentServer?.displayName ?? 'Unknown Server',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          
          Text(
            networkProvider.currentServerUrl,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 14,
            ),
          ),
          
          if (networkProvider.currentServerInfo != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    networkProvider.currentServerInfo!.statusDisplay,
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (networkProvider.currentServerInfo!.version != null)
              Text(
                'Version ${networkProvider.currentServerInfo!.version}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 11,
                ),
              ),
            if (networkProvider.currentServerInfo!.capabilities.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: networkProvider.currentServerInfo!.capabilities.map((cap) =>
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      cap,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ).toList(),
              ),
            ],
          ],
          
          if (networkProvider.connectionError != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Connection Error',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServerListSection(NetworkProvider networkProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AVAILABLE SERVERS',
          style: TextStyle(
            color: Colors.white.withOpacity(0.6),
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF2A2A2A).withOpacity(0.4),
                const Color(0xFF1F1F1F).withOpacity(0.3),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withOpacity(0.08),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Predefined Servers
              ...networkProvider.predefinedServers.map((server) => _buildServerTile(
                networkProvider, server, false,
              )).toList(),
              
              // Custom Servers
              if (networkProvider.customServers.isNotEmpty) ...[
                if (networkProvider.predefinedServers.isNotEmpty)
                  Container(
                    height: 1,
                    color: Colors.white.withOpacity(0.05),
                    margin: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                ...networkProvider.customServers.map((server) => _buildServerTile(
                  networkProvider, server, true,
                )).toList(),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildServerTile(NetworkProvider networkProvider, ServerInfo server, bool isCustom) {
    final isSelected = server.url == networkProvider.currentServerUrl;
    final isFirst = networkProvider.allServers.first == server;
    final isLast = networkProvider.allServers.last == server;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.vertical(
          top: isFirst ? const Radius.circular(16) : Radius.zero,
          bottom: isLast ? const Radius.circular(16) : Radius.zero,
        ),
        onTap: networkProvider.isTestingConnection 
            ? null 
            : () => _switchToServer(networkProvider, server.url),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected 
                ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                : null,
          ),
          child: Row(
            children: [
              // Server Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: server.isOfficial 
                      ? Theme.of(context).colorScheme.primary.withOpacity(0.1)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  server.isOfficial ? Icons.verified : Icons.dns,
                  color: server.isOfficial 
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white.withOpacity(0.6),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              
              // Server Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            server.displayName,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (server.isOfficial)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'OFFICIAL',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      server.url,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),
                    // Server status and info
                    if (server.version != null || server.latestBlockHeight != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (server.latestBlockHeight != null) ...[
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: server.isResponsive ? Colors.green : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Block ${server.latestBlockHeight}',
                              style: TextStyle(
                                color: server.isResponsive ? Colors.green : Colors.orange,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                          if (server.version != null && server.latestBlockHeight != null)
                            const SizedBox(width: 8),
                          if (server.version != null)
                            Text(
                              'v${server.version}',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.5),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ],
                    
                    // Capabilities
                    if (server.capabilities.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: server.capabilities.take(3).map((cap) =>
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: Text(
                              cap,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 8,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Actions
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: Theme.of(context).colorScheme.primary,
                      size: 20,
                    ),
                  
                  if (isCustom && !isSelected) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => _removeCustomServer(networkProvider, server),
                      icon: const Icon(Icons.delete_outline),
                      iconSize: 18,
                      color: Colors.red.withOpacity(0.7),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddCustomServerButton(NetworkProvider networkProvider) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: networkProvider.isTestingConnection 
            ? null 
            : () => _showAddServerDialog(networkProvider),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.add,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Add Custom Server',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _switchToServer(NetworkProvider networkProvider, String serverUrl) async {
    if (networkProvider.isTestingConnection) return;
    
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _ConnectionTestDialog(),
    );

    final success = await networkProvider.switchServer(serverUrl);
    
    if (mounted) {
      Navigator.of(context).pop(); // Close loading dialog
      
      if (!success) {
        _showErrorDialog('Failed to connect to server. Please check the server URL and try again.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${networkProvider.getServerInfo(serverUrl)?.displayName ?? 'server'}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _removeCustomServer(NetworkProvider networkProvider, ServerInfo server) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Remove Server',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to remove "${server.displayName}"?',
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              networkProvider.removeCustomServer(server.url);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Removed ${server.displayName}'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddServerDialog(NetworkProvider networkProvider) {
    final nameController = TextEditingController();
    final urlController = TextEditingController();
    final descriptionController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Add Custom Server',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Server Name',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Server URL',
                hintText: 'https://example.com:9067',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descriptionController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Description (Optional)',
                labelStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.white.withOpacity(0.6)),
            ),
          ),
          TextButton(
            onPressed: () async {
              if (nameController.text.isEmpty || urlController.text.isEmpty) {
                _showErrorDialog('Please fill in server name and URL');
                return;
              }
              
              Navigator.of(context).pop();
              
              // Show loading dialog
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const _ConnectionTestDialog(),
              );
              
              final success = await networkProvider.addCustomServer(
                nameController.text,
                urlController.text,
                descriptionController.text.isEmpty ? null : descriptionController.text,
              );
              
              if (mounted) {
                Navigator.of(context).pop(); // Close loading dialog
                
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added ${nameController.text}'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  _showErrorDialog(networkProvider.connectionError ?? 'Failed to add server');
                }
              }
            },
            child: Text(
              'Add Server',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text(
          'Error',
          style: TextStyle(color: Colors.red),
        ),
        content: Text(
          message,
          style: TextStyle(color: Colors.white.withOpacity(0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading dialog for connection testing
class _ConnectionTestDialog extends StatelessWidget {
  const _ConnectionTestDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF2A2A2A),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text(
              'Testing Connection...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we verify the server',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}