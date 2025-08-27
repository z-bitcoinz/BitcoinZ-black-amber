import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'qr_service.dart';

class SharingService {
  /// Share payment request with multiple options
  static Future<void> sharePaymentRequest({
    required BuildContext context,
    required String address,
    double? amount,
    String? memo,
    String? fiatAmount,
    String? currency,
    bool includeQRImage = true,
    Rect? sharePositionOrigin,
  }) async {
    final paymentURI = QRService.generatePaymentURI(
      address: address,
      amount: amount,
      memo: memo,
    );
    
    final shareText = _buildShareText(
      address: address,
      amount: amount,
      memo: memo,
      fiatAmount: fiatAmount,
      currency: currency,
      paymentURI: paymentURI,
    );
    
    // Show sharing options dialog
    await _showSharingOptions(
      context: context,
      paymentURI: paymentURI,
      shareText: shareText,
      includeQRImage: includeQRImage,
      sharePositionOrigin: sharePositionOrigin,
    );
  }
  
  /// Build formatted share text
  static String _buildShareText({
    required String address,
    double? amount,
    String? memo,
    String? fiatAmount,
    String? currency,
    required String paymentURI,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('💰 BitcoinZ Payment Request');
    buffer.writeln();
    
    if (amount != null && amount > 0) {
      buffer.writeln('Amount: ${amount.toStringAsFixed(8)} BTCZ');
      if (fiatAmount != null && currency != null) {
        buffer.writeln('≈ $fiatAmount $currency');
      }
      buffer.writeln();
    }
    
    if (memo != null && memo.isNotEmpty) {
      buffer.writeln('Note: $memo');
      buffer.writeln();
    }
    
    buffer.writeln('Address: $address');
    buffer.writeln();
    buffer.writeln('Payment URI: $paymentURI');
    buffer.writeln();
    buffer.writeln('Send BitcoinZ to this address using any compatible wallet.');
    
    return buffer.toString();
  }
  
  /// Show sharing options dialog
  static Future<void> _showSharingOptions({
    required BuildContext context,
    required String paymentURI,
    required String shareText,
    bool includeQRImage = true,
    Rect? sharePositionOrigin,
  }) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Text(
                'Share Payment Request',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // Sharing options
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Column(
                children: [
                  // Quick share (system share sheet)
                  _buildShareOption(
                    context: context,
                    icon: Icons.share,
                    title: 'Share via...',
                    subtitle: 'Use system share sheet',
                    onTap: () async {
                      Navigator.pop(context);
                      if (includeQRImage) {
                        await QRService.shareQRImage(
                          data: paymentURI,
                          text: shareText,
                          sharePositionOrigin: sharePositionOrigin,
                        );
                      } else {
                        await QRService.shareQRText(
                          data: shareText,
                          sharePositionOrigin: sharePositionOrigin,
                        );
                      }
                    },
                  ),
                  
                  const Divider(),
                  
                  // Copy to clipboard
                  _buildShareOption(
                    context: context,
                    icon: Icons.copy,
                    title: 'Copy Payment URI',
                    subtitle: 'Copy to clipboard',
                    onTap: () async {
                      Navigator.pop(context);
                      await QRService.copyToClipboard(paymentURI);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment URI copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  
                  const Divider(),
                  
                  // Copy full text
                  _buildShareOption(
                    context: context,
                    icon: Icons.text_snippet,
                    title: 'Copy Full Details',
                    subtitle: 'Copy formatted text',
                    onTap: () async {
                      Navigator.pop(context);
                      await QRService.copyToClipboard(shareText);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Payment details copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  
                  if (includeQRImage) ...[
                    const Divider(),
                    
                    // Share QR image only
                    _buildShareOption(
                      context: context,
                      icon: Icons.qr_code,
                      title: 'Share QR Code',
                      subtitle: 'Share as image',
                      onTap: () async {
                        Navigator.pop(context);
                        await QRService.shareQRImage(
                          data: paymentURI,
                          subject: 'BitcoinZ Payment Request',
                          sharePositionOrigin: sharePositionOrigin,
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            // Reduced safe area padding
            SizedBox(height: MediaQuery.of(context).padding.bottom > 0
                ? MediaQuery.of(context).padding.bottom * 0.5
                : 8),
          ],
        ),
      ),
    );
  }
  
  /// Build individual share option
  static Widget _buildShareOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(subtitle),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
  
  /// Share to specific social media platforms (if apps are installed)
  static Future<void> shareToWhatsApp(String text) async {
    final url = 'whatsapp://send?text=${Uri.encodeComponent(text)}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      // Fallback to web WhatsApp
      final webUrl = 'https://wa.me/?text=${Uri.encodeComponent(text)}';
      await launchUrl(Uri.parse(webUrl));
    }
  }
  
  static Future<void> shareToTelegram(String text) async {
    final url = 'tg://msg?text=${Uri.encodeComponent(text)}';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    } else {
      // Fallback to web Telegram
      final webUrl = 'https://t.me/share/url?text=${Uri.encodeComponent(text)}';
      await launchUrl(Uri.parse(webUrl));
    }
  }
  
  static Future<void> shareToSMS(String text, {String? phoneNumber}) async {
    final url = phoneNumber != null 
        ? 'sms:$phoneNumber?body=${Uri.encodeComponent(text)}'
        : 'sms:?body=${Uri.encodeComponent(text)}';
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url));
    }
  }
  
  /// Check if specific apps are installed
  static Future<bool> isWhatsAppInstalled() async {
    return await canLaunchUrl(Uri.parse('whatsapp://'));
  }
  
  static Future<bool> isTelegramInstalled() async {
    return await canLaunchUrl(Uri.parse('tg://'));
  }
}
