import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:tap_attend/main.dart';
import 'package:tap_attend/providers/attendance_provider.dart';

void main() {
  testWidgets('Login screen smoke test and login navigation test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AttendanceProvider()),
        ],
        child: const TapAttendApp(),
      ),
    );

    // 1. Verify that the app starts at the login screen and displays key login elements
    expect(find.text('Lecturer Sign In'), findsOneWidget);
    expect(find.text('University Portal'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);

    // Find the text fields
    final lecturerIdField = find.widgetWithText(TextField, 'Enter your ID');
    final passwordField = find.widgetWithText(TextField, '••••••••');
    expect(lecturerIdField, findsOneWidget);
    expect(passwordField, findsOneWidget);

    // 2. Type Lecturer ID and Password
    await tester.enterText(lecturerIdField, 'L12345');
    await tester.enterText(passwordField, 'password123');
    await tester.pump();

    // 3. Tap the Sign In button
    final signInButton = find.widgetWithText(ElevatedButton, 'Sign In');
    await tester.ensureVisible(signInButton);
    await tester.tap(signInButton);
    
    // Pump frames to handle the push replacement navigation transition
    await tester.pumpAndSettle();

    // 4. Verify that we have navigated to the MainScreen (which has the DashboardScreen)
    expect(
      find.byWidgetPredicate((widget) =>
        widget is RichText &&
        widget.text.toPlainText().contains('Dr. Robert Smith')
      ),
      findsOneWidget,
    );
    expect(find.text('Academic Portal'), findsOneWidget);
    expect(find.text("Today's Schedule"), findsOneWidget);
  });
}
