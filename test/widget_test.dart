import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/app/ganapp.dart';

void main() {
  testWidgets('GanApp muestra pantalla de autenticacion', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const GanApp());
    await tester.pumpAndSettle();

    expect(find.text('Iniciar sesion'), findsOneWidget);
    expect(find.text('GanApp'), findsOneWidget);
  });
}
