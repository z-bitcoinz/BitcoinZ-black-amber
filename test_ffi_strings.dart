import 'dart:ffi';
import 'dart:io';
import 'dart:convert';
import 'package:ffi/ffi.dart';

// FFI function signature
typedef TestStringConversionC = Pointer<Utf8> Function();
typedef TestStringConversionDart = Pointer<Utf8> Function();

void main() {
  print('Testing FFI String Conversion...');
  
  try {
    // Load library
    DynamicLibrary lib;
    if (Platform.isMacOS) {
      lib = DynamicLibrary.open('./macos/Runner/Frameworks/libbitcoinz_mobile.dylib');
    } else {
      throw UnsupportedError('Platform not supported for this test');
    }
    
    // Bind function
    final testStringConversion = lib.lookupFunction<TestStringConversionC, TestStringConversionDart>('test_string_conversion');
    
    // Call function
    print('Calling Rust test_string_conversion...');
    final resultPtr = testStringConversion();
    
    if (resultPtr == nullptr) {
      print('ERROR: Received null pointer from Rust');
      return;
    }
    
    // Convert result to Dart string
    final resultStr = resultPtr.toDartString();
    print('Flutter received string (${resultStr.length} chars): $resultStr');
    
    // Parse JSON
    try {
      final json = jsonDecode(resultStr) as Map<String, dynamic>;
      print('JSON parsed successfully:');
      print('  transparent: "${json['transparent']}" (${(json['transparent'] as String).length} chars)');
      print('  shielded: "${json['shielded']}" (${(json['shielded'] as String).length} chars)');
      print('  Expected t_len: ${json['t_len']}');
      print('  Expected z_len: ${json['z_len']}');
      print('  Actual t_len: ${(json['transparent'] as String).length}');
      print('  Actual z_len: ${(json['shielded'] as String).length}');
      
      if ((json['transparent'] as String).length != json['t_len'] ||
          (json['shielded'] as String).length != json['z_len']) {
        print('🚨 STRING TRUNCATION DETECTED!');
      } else {
        print('✅ String conversion working correctly');
      }
    } catch (e) {
      print('ERROR parsing JSON: $e');
    }
    
    // Free the string
    calloc.free(resultPtr);
    
  } catch (e) {
    print('ERROR: $e');
  }
}