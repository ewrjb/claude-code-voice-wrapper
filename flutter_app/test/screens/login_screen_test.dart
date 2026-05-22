import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voice_dev/screens/login_screen.dart';

Widget makeApp() => const MaterialApp(home: LoginScreen());

void main() {
  testWidgets('shows two TextFormFields and a login button', (tester) async {
    await tester.pumpWidget(makeApp());
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(find.text('로그인'), findsOneWidget);
  });

  testWidgets('shows validation error when email is empty', (tester) async {
    await tester.pumpWidget(makeApp());
    await tester.tap(find.text('로그인'));
    await tester.pump();
    expect(find.text('이메일을 입력하세요'), findsOneWidget);
  });

  testWidgets('shows validation error when password is empty', (tester) async {
    await tester.pumpWidget(makeApp());
    await tester.enterText(
        find.byKey(const Key('email_field')), 'user@test.com');
    await tester.tap(find.text('로그인'));
    await tester.pump();
    expect(find.text('비밀번호를 입력하세요'), findsOneWidget);
  });
}
