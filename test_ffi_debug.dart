import 'dart:ffi';
import 'dart:io';
import 'dart:convert';
import 'package:ffi/ffi.dart';

// FFI function signature for debug
typedef DebugFFIWalletCreationC = Pointer<Utf8> Function();
typedef DebugFFIWalletCreationDart = Pointer<Utf8> Function();

void main() {
  print('Testing FFI Debug Wallet Creation...');
  
  try {
    // Load library
    DynamicLibrary lib;
    if (Platform.isMacOS) {
      lib = DynamicLibrary.open('./macos/Runner/Frameworks/libbitcoinz_mobile.dylib');
    } else {
      throw UnsupportedError('Platform not supported for this test');
    }
    
    // Bind debug function
    final debugFFIWalletCreation = lib.lookupFunction<DebugFFIWalletCreationC, DebugFFIWalletCreationDart>('debug_ffi_wallet_creation');
    
    // Call function - this will print debug info on Rust side
    print('Calling Rust debug_ffi_wallet_creation...');
    final resultPtr = debugFFIWalletCreation();
    
    if (resultPtr == nullptr) {
      print('ERROR: Received null pointer from Rust debug function');
      return;
    }
    
    // Convert result to Dart string
    final resultStr = resultPtr.toDartString();
    print('\\n=== FLUTTER SIDE ===');
    print('Flutter received result string (${resultStr.length} chars)');
    
    // Parse JSON
    try {
      final json = jsonDecode(resultStr) as Map<String, dynamic>;
      
      if (json['success'] == true && json['data'] != null) {
        final data = json['data'];
        final transparentAddrs = List<String>.from(data['transparent_addresses'] ?? []);
        final shieldedAddrs = List<String>.from(data['shielded_addresses'] ?? []);
        
        print('\\n🔍 Flutter parsed addresses:');
        print('  Transparent addresses: ${transparentAddrs.length}');
        for (int i = 0; i < transparentAddrs.length; i++) {
          print('    [$i]: "${transparentAddrs[i]}" (${transparentAddrs[i].length} chars)');
        }
        
        print('  Shielded addresses: ${shieldedAddrs.length}');
        for (int i = 0; i < shieldedAddrs.length; i++) {
          print('    [$i]: "${shieldedAddrs[i]}" (${shieldedAddrs[i].length} chars)');
        }
        
        // Check if addresses are the expected lengths
        bool hasCorrectLengths = true;
        for (String addr in transparentAddrs) {
          if (addr.length != 35) {
            print('❌ INCORRECT: Transparent address length is ${addr.length}, expected 35');
            hasCorrectLengths = false;
          }
        }
        for (String addr in shieldedAddrs) {
          if (addr.length != 78) {
            print('❌ INCORRECT: Shielded address length is ${addr.length}, expected 78');
            hasCorrectLengths = false;
          }
        }
        
        if (hasCorrectLengths) {
          print('✅ All addresses have correct lengths!');
        }
        
      } else {
        print('ERROR: FFI call unsuccessful: ${json['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      print('ERROR parsing JSON: $e');
      print('Raw response: $resultStr');
    }
    
    // Free the string
    calloc.free(resultPtr);
    
  } catch (e) {
    print('ERROR: $e');
  }
}