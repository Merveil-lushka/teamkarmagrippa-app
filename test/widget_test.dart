// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:teamkarmagrippa_cloud/main.dart';
import 'package:teamkarmagrippa_cloud/providers/auth_provider.dart';
import 'package:teamkarmagrippa_cloud/providers/theme_provider.dart';

class _TestAuthProvider extends AuthProvider {
  @override
  Future<bool> autoLogin() async => false;
}

void main() {
  testWidgets('Application starts', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
          ChangeNotifierProvider<AuthProvider>(create: (_) => _TestAuthProvider()),
        ],
        child: const TeamKarmagrippaApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(TeamKarmagrippaApp), findsOneWidget);
  });
}
