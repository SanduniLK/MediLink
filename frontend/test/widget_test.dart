import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('Sign Up page loads correctly', (WidgetTester tester) async {
    // Build the app and trigger a frame
    await tester.pumpWidget(const MediLinkApp());

    // ✅ Check that the Sign Up title is visible
    expect(find.text('Create Account'), findsOneWidget);

    // ✅ Check that the name, email, and password fields exist
    expect(find.byType(TextFormField), findsNWidgets(3));

    // ✅ Check that the Sign Up button exists
    expect(find.byType(ElevatedButton), findsOneWidget);

    // ✅ Check that the "Already have an account? Log in" text button exists
    expect(find.text('Already have an account? Log in'), findsOneWidget);
  });
}
