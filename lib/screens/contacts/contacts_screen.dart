import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/contact_provider.dart';
import '../../models/contact_model.dart';
import '../../services/image_helper_service.dart';
import 'contact_form_screen.dart';
import 'contact_detail_screen.dart';
import '../main_screen.dart';

class ContactsScreen extends StatefulWidget {
  final Function(String address, String contactName, String? photo)? onSendToContact;

  const ContactsScreen({
    super.key,
    this.onSendToContact,
  });

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchController = TextEditingController();
  bool _showFavoritesOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadContacts();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    await contactProvider.loadContacts();
  }

  void _onSearchChanged(String query) {
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    contactProvider.searchContacts(query);
  }

  void _clearSearch() {
    _searchController.clear();
    final contactProvider = Provider.of<ContactProvider>(context, listen: false);
    contactProvider.clearSearch();
  }

  void _toggleFavoritesFilter() {
    setState(() {
      _showFavoritesOnly = !_showFavoritesOnly;
    });
  }

  Future<void> _addContact() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ContactFormScreen(),
      ),
    );

    if (result == true) {
      // Contact was added successfully, refresh list
      await _loadContacts();
    }
  }

  Future<void> _editContact(ContactModel contact) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactFormScreen(contact: contact),
      ),
    );

    if (result == true) {
      // Contact was updated successfully, refresh list
      await _loadContacts();
    }
  }

  Future<void> _viewContact(ContactModel contact) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContactDetailScreen(contact: contact),
      ),
    );

    // Handle send to contact navigation
    if (result != null && result is Map<String, dynamic>) {
      final action = result['action'] as String?;
      if (action == 'send_to_contact') {
        final address = result['address'] as String;
        final name = result['name'] as String;
        final photo = result['photo'] as String?;

        print('🎯 ContactsScreen: Received send_to_contact action');
        print('🎯 ContactsScreen: Address: $address');
        print('🎯 ContactsScreen: Name: $name');
        print('🎯 ContactsScreen: Photo: ${photo != null ? 'provided' : 'null'}');
        print('🎯 ContactsScreen: Callback available: ${widget.onSendToContact != null}');

        // Try multiple approaches
        bool success = false;

        // Approach 1: Use callback if available
        if (widget.onSendToContact != null) {
          print('🎯 ContactsScreen: Calling callback');
          widget.onSendToContact!(address, name, photo);
          success = true;
        } else {
          print('🎯 ContactsScreen: No callback available');
        }

        // Approach 2: Use static method
        if (!success) {
          print('🎯 ContactsScreen: Trying static method');
          MainScreen.navigateToSendWithContact(address, name, photo);
          success = true;
        }

        // Approach 3: Fallback to context search
        if (!success) {
          print('🎯 ContactsScreen: Trying MainScreen.of()');
          final mainScreenState = MainScreen.of(context);
          if (mainScreenState != null) {
            mainScreenState.navigateToSendWithContact(address, name, photo);
            success = true;
          }
        }

        // Show error if all approaches failed
        if (!success) {
          print('🎯 ContactsScreen: ERROR - All approaches failed!');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Unable to navigate to send screen'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 48.0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(
              _showFavoritesOnly ? Icons.star : Icons.star_border,
              color: _showFavoritesOnly 
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
            ),
            onPressed: _toggleFavoritesFilter,
            tooltip: _showFavoritesOnly ? 'Show all contacts' : 'Show favorites only',
          ),
        ],
      ),
      body: Consumer<ContactProvider>(
        builder: (context, contactProvider, child) {
          if (contactProvider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (contactProvider.errorMessage != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red.withOpacity(0.6),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading contacts',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    contactProvider.errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.red.withOpacity(0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _loadContacts,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final contacts = _showFavoritesOnly 
              ? contactProvider.favoriteContacts
              : contactProvider.contacts;

          return Column(
            children: [
              // Search bar
              Container(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search contacts...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.outline.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).colorScheme.surface.withOpacity(0.1),
                  ),
                ),
              ),
              
              // Contacts list
              Expanded(
                child: contacts.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: _loadContacts,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: contacts.length,
                          itemBuilder: (context, index) {
                            final contact = contacts[index];
                            return _buildContactCard(contact);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addContact,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white, // high-contrast icon
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isSearching = _searchController.text.isNotEmpty || _showFavoritesOnly;
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSearching ? Icons.search_off : Icons.contacts,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 24),
          Text(
            isSearching ? 'No contacts found' : 'No contacts yet',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isSearching
                ? 'Try a different search term or clear filters'
                : 'Add your first contact to get started',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          if (!isSearching) ...[
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _addContact,
              icon: const Icon(Icons.person_add),
              label: const Text('Add Contact'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildContactCard(ContactModel contact) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
          backgroundImage: ImageHelperService.getMemoryImage(contact.pictureBase64),
          child: contact.pictureBase64 == null
              ? Text(
                  contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                contact.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (contact.isFavorite)
              Icon(
                Icons.star,
                color: Colors.amber,
                size: 18,
              ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: contact.isTransparent
                    ? Colors.blue.withOpacity(0.2)
                    : const Color(0xFFFFB800).withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                contact.isTransparent ? 'T' : 'S',
                style: TextStyle(
                  color: contact.isTransparent ? Colors.blue : const Color(0xFFFFB800),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              contact.address.length > 20 
                  ? '${contact.address.substring(0, 16)}...${contact.address.substring(contact.address.length - 8)}'
                  : contact.address,
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
            if (contact.description?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text(
                contact.description!,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.6),
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'view':
                _viewContact(contact);
                break;
              case 'edit':
                _editContact(contact);
                break;
              case 'favorite':
                final contactProvider = Provider.of<ContactProvider>(context, listen: false);
                await contactProvider.toggleFavorite(contact);
                break;
              case 'delete':
                _showDeleteConfirmation(contact);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: ListTile(
                leading: Icon(Icons.visibility),
                title: Text('View'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'favorite',
              child: ListTile(
                leading: Icon(contact.isFavorite ? Icons.star_border : Icons.star),
                title: Text(contact.isFavorite ? 'Remove from favorites' : 'Add to favorites'),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                dense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          icon: const Icon(Icons.more_vert),
        ),
        onTap: () => _viewContact(contact),
      ),
    );
  }

  void _showDeleteConfirmation(ContactModel contact) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to delete "${contact.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final contactProvider = Provider.of<ContactProvider>(context, listen: false);
              final success = await contactProvider.deleteContact(contact);
              
              if (mounted && success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted "${contact.name}"'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}