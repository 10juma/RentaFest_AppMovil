import 'package:flutter_test/flutter_test.dart';
import 'package:renta_fest/main.dart';

void main() {
  testWidgets('Smoke test de inicio de app', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const RentaFestApp());

    // Verificamos que al menos cargue el texto de bienvenida o el login
    expect(find.text('RentaFest'), findsOneWidget);
  });
}
