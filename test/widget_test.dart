import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:navalgo/main.dart';
import 'package:navalgo/services/auth_service.dart';
import 'package:navalgo/viewmodels/login_view_model.dart';
import 'package:navalgo/viewmodels/session_view_model.dart';

void main() {
  testWidgets('Muestra la pantalla de acceso al arrancar', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    final session = SessionViewModel();
    await session.restoreSession();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SessionViewModel>.value(value: session),
          Provider<AuthService>(create: (_) => AuthService()),
          ChangeNotifierProvider<LoginViewModel>(
            create: (context) => LoginViewModel(
              authService: context.read<AuthService>(),
              session: context.read<SessionViewModel>(),
            ),
          ),
        ],
        child: const MyApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Acceso a NavalGO'), findsOneWidget);
    expect(find.text('Correo electrónico'), findsOneWidget);
    expect(find.text('Iniciar sesión'), findsOneWidget);
  });
}
