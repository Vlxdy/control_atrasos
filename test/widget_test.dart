import 'package:control_atrasos/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('muestra la pantalla principal de control de atrasos', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('Control de Atrasos'), findsOneWidget);
    expect(find.textContaining('Atraso total'), findsOneWidget);
    expect(find.text('Registrar entrada (hoy)'), findsOneWidget);
    expect(find.textContaining('Registrar otro día'), findsOneWidget);
  });
}
