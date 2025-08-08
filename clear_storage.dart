import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  print('Clearing Flutter storage...');
  
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    print('✅ Storage cleared successfully!');
    print('✅ Next app launch will create fresh wallet with correct addresses');
  } catch (e) {
    print('❌ Error clearing storage: $e');
  }
}