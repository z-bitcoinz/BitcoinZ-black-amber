import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';

class QRService {
  static const String _bitcoinzScheme = 'bitcoinz';
  
  /// Generate BitcoinZ payment URI following BIP-21 standard
  static String generatePaymentURI({
    required String address,
    double? amount,
    String? memo,
    String? label,
  }) {
    if (address.isEmpty) return '';
    
    String uri = '$_bitcoinzScheme:$address';
    List<String> params = [];
    
    if (amount != null && amount > 0) {
      params.add('amount=${amount.toStringAsFixed(8)}');
    }
    
    if (memo != null && memo.isNotEmpty) {
      params.add('message=${Uri.encodeComponent(memo)}');
    }
    
    if (label != null && label.isNotEmpty) {
      params.add('label=${Uri.encodeComponent(label)}');
    }
    
    if (params.isNotEmpty) {
      uri += '?${params.join('&')}';
    }
    
    return uri;
  }
  
  /// Generate QR code widget with enhanced styling
  static Widget generateQRWidget({
    required String data,
    double size = 200,
    Color backgroundColor = Colors.white,
    Color foregroundColor = Colors.black,
    bool includeMargin = true,
    Widget? embeddedImage,
  }) {
    if (data.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.qr_code_2,
              size: size * 0.3,
              color: Colors.grey.withOpacity(0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No data to display',
              style: TextStyle(
                color: Colors.grey.withOpacity(0.7),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: includeMargin ? const EdgeInsets.all(16) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: QrImageView(
        data: data,
        version: QrVersions.auto,
        size: size,
        backgroundColor: backgroundColor,
        foregroundColor: foregroundColor,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        embeddedImage: embeddedImage != null ? AssetImage('assets/images/logo.png') : null,
        embeddedImageStyle: embeddedImage != null 
            ? const QrEmbeddedImageStyle(
                size: Size(40, 40),
              )
            : null,
      ),
    );
  }
  
  /// Generate QR code as image bytes for sharing
  static Future<Uint8List?> generateQRImageBytes({
    required String data,
    double size = 512,
    Color backgroundColor = Colors.white,
    Color foregroundColor = Colors.black,
  }) async {
    try {
      final qrValidationResult = QrValidator.validate(
        data: data,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );
      
      if (qrValidationResult.status != QrValidationStatus.valid) {
        return null;
      }
      
      final qrCode = qrValidationResult.qrCode!;
      final painter = QrPainter.withQr(
        qr: qrCode,
        color: foregroundColor,
        emptyColor: backgroundColor,
        gapless: true,
      );
      
      final pictureBounds = Rect.fromLTWH(0, 0, size, size);
      final picture = painter.toPicture(size);
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error generating QR image bytes: $e');
      return null;
    }
  }
  
  /// Share QR code as text
  static Future<void> shareQRText({
    required String data,
    String? subject,
    Rect? sharePositionOrigin,
  }) async {
    try {
      await Share.share(
        data,
        subject: subject ?? 'BitcoinZ Payment Request',
        sharePositionOrigin: sharePositionOrigin,
      );
    } catch (e) {
      debugPrint('Error sharing QR text: $e');
    }
  }
  
  /// Share QR code as image file
  static Future<void> shareQRImage({
    required String data,
    String? subject,
    String? text,
    Rect? sharePositionOrigin,
    double imageSize = 512,
  }) async {
    try {
      final imageBytes = await generateQRImageBytes(
        data: data,
        size: imageSize,
      );
      
      if (imageBytes == null) {
        throw Exception('Failed to generate QR code image');
      }
      
      // Create temporary file
      final tempDir = await getTemporaryDirectory();
      final fileName = 'bitcoinz_payment_request_${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsBytes(imageBytes);
      
      // Share the file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: subject ?? 'BitcoinZ Payment Request',
        text: text,
        sharePositionOrigin: sharePositionOrigin,
      );
      
      // Clean up temporary file after a delay
      Future.delayed(const Duration(seconds: 30), () {
        if (file.existsSync()) {
          file.deleteSync();
        }
      });
    } catch (e) {
      debugPrint('Error sharing QR image: $e');
      // Fallback to text sharing
      await shareQRText(
        data: data,
        subject: subject,
        sharePositionOrigin: sharePositionOrigin,
      );
    }
  }
  
  /// Copy QR data to clipboard
  static Future<void> copyToClipboard(String data) async {
    try {
      await Clipboard.setData(ClipboardData(text: data));
    } catch (e) {
      debugPrint('Error copying to clipboard: $e');
    }
  }
  
  /// Parse BitcoinZ payment URI
  static Map<String, String> parsePaymentURI(String uri) {
    final result = <String, String>{};
    
    if (!uri.startsWith('$_bitcoinzScheme:')) {
      return result;
    }
    
    final uriParts = uri.substring(_bitcoinzScheme.length + 1).split('?');
    if (uriParts.isNotEmpty) {
      result['address'] = uriParts[0];
    }
    
    if (uriParts.length > 1) {
      final params = uriParts[1].split('&');
      for (final param in params) {
        final keyValue = param.split('=');
        if (keyValue.length == 2) {
          final key = keyValue[0];
          final value = Uri.decodeComponent(keyValue[1]);
          result[key] = value;
        }
      }
    }
    
    return result;
  }
  
  /// Validate BitcoinZ address format
  static bool isValidBitcoinZAddress(String address) {
    if (address.isEmpty) return false;

    // BitcoinZ transparent addresses start with 't1' or 't3'
    // BitcoinZ shielded addresses start with 'zc' or 'zs'
    final transparentRegex = RegExp(r'^t[13][a-km-zA-HJ-NP-Z1-9]{25,50}$');
    final shieldedRegex = RegExp(r'^z[cs][a-km-zA-HJ-NP-Z1-9]{25,95}$');

    return transparentRegex.hasMatch(address) || shieldedRegex.hasMatch(address);
  }
}
