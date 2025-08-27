import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

class ImageHelperService {
  static const int maxImageSize = 300; // Maximum width/height in pixels
  static const int jpegQuality = 85; // JPEG compression quality
  static const int maxFileSizeKB = 100; // Maximum file size in KB
  
  static final ImageHelperService _instance = ImageHelperService._internal();
  factory ImageHelperService() => _instance;
  ImageHelperService._internal();
  
  final ImagePicker _imagePicker = ImagePicker();
  
  /// Pick image from camera or gallery and process it
  Future<String?> pickAndProcessImage({
    required ImageSource source,
    required String cropTitle,
  }) async {
    try {
      // Pick image
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920, // Initial max resolution before cropping
        maxHeight: 1920,
        imageQuality: 100, // Keep quality high for cropping
      );
      
      if (pickedFile == null) return null;
      
      // Process image (crop to square and compress)
      final base64String = await _processImage(pickedFile.path);
      
      // Clean up temporary files
      try {
        await File(pickedFile.path).delete();
      } catch (e) {
        // Ignore cleanup errors
      }
      
      return base64String;
      
    } catch (e) {
      if (kDebugMode) print('❌ ImageHelper: Error picking/processing image: $e');
      return null;
    }
  }
  
  /// Process image - crop to square and compress
  Future<String?> _processImage(String imagePath) async {
    try {
      // Read image file
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      
      // Decode image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;
      
      // Crop to square (center crop)
      image = _cropToSquare(image);
      
      // Compress and convert to base64
      return await _compressAndConvertToBase64Image(image);
      
    } catch (e) {
      if (kDebugMode) print('❌ ImageHelper: Error processing image: $e');
      return null;
    }
  }
  
  /// Crop image to square by center cropping
  img.Image _cropToSquare(img.Image image) {
    final int size = min(image.width, image.height);
    final int xOffset = (image.width - size) ~/ 2;
    final int yOffset = (image.height - size) ~/ 2;
    
    return img.copyCrop(
      image,
      x: xOffset,
      y: yOffset,
      width: size,
      height: size,
    );
  }
  
  /// Compress image and convert to base64
  Future<String?> _compressAndConvertToBase64Image(img.Image image) async {
    try {
      
      // Resize if needed
      if (image.width > maxImageSize || image.height > maxImageSize) {
        // Calculate new dimensions maintaining aspect ratio
        double scale = maxImageSize / (image.width > image.height ? image.width : image.height);
        int newWidth = (image.width * scale).round();
        int newHeight = (image.height * scale).round();
        
        image = img.copyResize(
          image,
          width: newWidth,
          height: newHeight,
          interpolation: img.Interpolation.linear,
        );
      }
      
      // Compress with decreasing quality until under size limit
      Uint8List? compressedBytes;
      int quality = jpegQuality;
      
      do {
        compressedBytes = Uint8List.fromList(
          img.encodeJpg(image!, quality: quality),
        );
        
        // Check size
        if (compressedBytes.length <= maxFileSizeKB * 1024) {
          break;
        }
        
        // Reduce quality
        quality -= 10;
        
        // If quality too low, resize image further
        if (quality < 50 && image!.width > 200) {
          image = img.copyResize(
            image!,
            width: (image!.width * 0.8).round(),
            height: (image!.height * 0.8).round(),
            interpolation: img.Interpolation.linear,
          );
          quality = jpegQuality; // Reset quality
        }
        
      } while (quality > 30);
      
      // Convert to base64
      final base64String = base64Encode(compressedBytes!);
      
      if (kDebugMode) {
        print('✅ ImageHelper: Image compressed - '
            'Size: ${(compressedBytes.length / 1024).toStringAsFixed(1)}KB, '
            'Dimensions: ${image!.width}x${image!.height}, '
            'Quality: $quality%');
      }
      
      return base64String;
      
    } catch (e) {
      if (kDebugMode) print('❌ ImageHelper: Error compressing image: $e');
      return null;
    }
  }
  
  /// Legacy method for backward compatibility
  Future<String?> _compressAndConvertToBase64(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final Uint8List imageBytes = await imageFile.readAsBytes();
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) return null;
      return _compressAndConvertToBase64Image(image);
    } catch (e) {
      if (kDebugMode) print('❌ ImageHelper: Error in legacy compress: $e');
      return null;
    }
  }
  
  /// Convert base64 string to image bytes for display
  static Uint8List? base64ToBytes(String? base64String) {
    if (base64String == null || base64String.isEmpty) return null;
    
    try {
      return base64Decode(base64String);
    } catch (e) {
      if (kDebugMode) print('❌ ImageHelper: Error decoding base64: $e');
      return null;
    }
  }
  
  /// Get memory image from base64 string
  static MemoryImage? getMemoryImage(String? base64String) {
    final bytes = base64ToBytes(base64String);
    if (bytes == null) return null;
    return MemoryImage(bytes);
  }
}