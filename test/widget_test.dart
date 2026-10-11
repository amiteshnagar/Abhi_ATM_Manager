import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:abhi_atm_manager/main.dart';
import 'package:abhi_atm_manager/providers/settings_provider.dart';

void main() {
  testWidgets('App load and splash screen title check', (WidgetTester tester) async {
    // Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final sharedPreferences = await SharedPreferences.getInstance();

    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
        child: const MyApp(),
      ),
    );

    // Verify that the splash screen app name is visible.
    expect(find.text('Abhi ATM Manager'), findsOneWidget);

    // Pump and settle to let the splash timer run its course and dispose the screen safely.
    await tester.pumpAndSettle(const Duration(seconds: 4));
  });
}
