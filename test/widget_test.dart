import 'package:flutter_test/flutter_test.dart';
import 'package:sign_talk/app/app.dart';
import 'package:flutter/material.dart';

void main() {
  testWidgets('SignTalk exposes exactly two destinations', (tester) async {
    await tester.pumpWidget(const SignTalkApp());
    expect(find.text('Text to Sign'), findsOneWidget);
    expect(find.text('Sign to Text'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
