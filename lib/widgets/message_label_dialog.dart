import 'package:flutter/material.dart';
import '../models/message_label.dart';

/// Quick and easy message label assignment dialog
/// Focuses on speed and simplicity for best user experience
class MessageLabelDialog extends StatefulWidget {
  final String txid;
  final String? currentMemo;
  final List<MessageLabel> existingLabels;
  final Function(MessageLabel) onLabelAdded;
  final Function(MessageLabel) onLabelRemoved;

  const MessageLabelDialog({
    super.key,
    required this.txid,
    this.currentMemo,
    required this.existingLabels,
    required this.onLabelAdded,
    required this.onLabelRemoved,
  });

  @override
  State<MessageLabelDialog> createState() => _MessageLabelDialogState();
}

class _MessageLabelDialogState extends State<MessageLabelDialog> {
  final TextEditingController _customLabelController = TextEditingController();
  String _selectedColor = '#2196F3';

  @override
  void dispose() {
    _customLabelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.label,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Message Labels',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Current labels
            if (widget.existingLabels.isNotEmpty) ...[
              Text(
                'Current Labels',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.existingLabels.map((label) => _buildLabelChip(label)).toList(),
              ),
              const SizedBox(height: 20),
            ],
            
            // Quick labels
            Text(
              'Quick Labels',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: MessageLabelCategories.predefined.map((category) {
                final isSelected = widget.existingLabels.any((l) => l.labelName == category['name']);
                return _buildQuickLabelChip(
                  category['name']!,
                  Color(int.parse(category['color']!.substring(1), radix: 16) + 0xFF000000),
                  isSelected,
                );
              }).toList(),
            ),
            
            const SizedBox(height: 20),
            
            // Custom label
            Text(
              'Custom Label',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customLabelController,
                    decoration: InputDecoration(
                      hintText: 'Enter custom label...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    maxLength: 20,
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
                const SizedBox(width: 12),
                _buildColorPicker(),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addCustomLabel,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  child: const Text('Add'),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Auto-generate suggestion
            if (widget.currentMemo != null && widget.currentMemo!.isNotEmpty) ...[
              const Divider(),
              const SizedBox(height: 12),
              Text(
                'Smart Suggestion',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              _buildAutoGenerateButton(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLabelChip(MessageLabel label) {
    final color = Color(int.parse(label.labelColor.substring(1), radix: 16) + 0xFF000000);
    
    return Chip(
      label: Text(
        label.labelName,
        style: TextStyle(
          color: _getContrastColor(color),
          fontWeight: FontWeight.w500,
        ),
      ),
      backgroundColor: color,
      deleteIcon: Icon(
        Icons.close,
        size: 18,
        color: _getContrastColor(color),
      ),
      onDeleted: () => widget.onLabelRemoved(label),
    );
  }

  Widget _buildQuickLabelChip(String name, Color color, bool isSelected) {
    return FilterChip(
      label: Text(
        name,
        style: TextStyle(
          color: isSelected ? _getContrastColor(color) : null,
          fontWeight: FontWeight.w500,
        ),
      ),
      selected: isSelected,
      selectedColor: color,
      onSelected: (selected) {
        if (selected) {
          _addQuickLabel(name, color);
        } else {
          final existingLabel = widget.existingLabels.firstWhere(
            (l) => l.labelName == name,
            orElse: () => throw StateError('Label not found'),
          );
          widget.onLabelRemoved(existingLabel);
        }
      },
    );
  }

  Widget _buildColorPicker() {
    final colors = ['#2196F3', '#4CAF50', '#FF9800', '#E91E63', '#9C27B0', '#00BCD4'];
    
    return PopupMenuButton<String>(
      initialValue: _selectedColor,
      onSelected: (color) => setState(() => _selectedColor = color),
      itemBuilder: (context) => colors.map((color) {
        final colorValue = Color(int.parse(color.substring(1), radix: 16) + 0xFF000000);
        return PopupMenuItem(
          value: color,
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: colorValue,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(color),
            ],
          ),
        );
      }).toList(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Color(int.parse(_selectedColor.substring(1), radix: 16) + 0xFF000000),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Icon(Icons.palette, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildAutoGenerateButton() {
    final suggestedLabel = MessageLabel.autoGenerate(
      txid: widget.txid,
      memo: widget.currentMemo!,
    );
    
    final isAlreadyAdded = widget.existingLabels.any((l) => l.labelName == suggestedLabel.labelName);
    
    return OutlinedButton.icon(
      onPressed: isAlreadyAdded ? null : () => widget.onLabelAdded(suggestedLabel),
      icon: const Icon(Icons.auto_awesome, size: 18),
      label: Text(isAlreadyAdded ? '${suggestedLabel.labelName} (already added)' : suggestedLabel.labelName),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  void _addQuickLabel(String name, Color color) {
    final label = MessageLabel.create(
      txid: widget.txid,
      labelName: name,
      labelColor: '#${color.value.toRadixString(16).substring(2)}',
    );
    widget.onLabelAdded(label);
  }

  void _addCustomLabel() {
    final text = _customLabelController.text.trim();
    if (text.isEmpty) return;
    
    // Check if label already exists
    if (widget.existingLabels.any((l) => l.labelName.toLowerCase() == text.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Label already exists')),
      );
      return;
    }
    
    final label = MessageLabel.create(
      txid: widget.txid,
      labelName: text,
      labelColor: _selectedColor,
    );
    
    widget.onLabelAdded(label);
    _customLabelController.clear();
  }

  Color _getContrastColor(Color color) {
    // Calculate luminance to determine if we need light or dark text
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
