import 'package:flutter/foundation.dart';

class SendPrefill {
  final String address;
  final String? name;
  final String? photo;
  const SendPrefill({required this.address, this.name, this.photo});
}

class SendPrefillBus {
  // Holds the latest requested prefill, or null when cleared
  static final ValueNotifier<SendPrefill?> current = ValueNotifier<SendPrefill?>(null);

  static void set(String address, String? name, [String? photo]) {
    if (kDebugMode) {
      // Use concise prints to avoid flooding logs
      print('🎯 SendPrefillBus.set -> address: $address, name: $name, photo: ${photo != null ? 'provided' : 'null'}');
    }
    current.value = SendPrefill(address: address, name: name, photo: photo);
  }

  static void clear() {
    if (kDebugMode) {
      print('🎯 SendPrefillBus.clear()');
      // Print a short stack trace to see where this is being called from
      try {
        throw Exception('stack');
      } catch (e, st) {
        final lines = st.toString().split('\n');
        final first = lines.take(6).join('\n');
        print('🎯 SendPrefillBus.clear() stack:\n$first');
      }
    }
    current.value = null;
  }
}

