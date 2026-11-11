import 'package:flutter_test/flutter_test.dart';
import 'package:uppi/main.dart';

void main() {
  testWidgets('Uppi smoke test - loads auth screen', (WidgetTester tester) async {
    await tester.pumpWidget(const UppiApp());
    expect(find.text('UPPI'), findsOneWidget);
    expect(find.text('Passageiro'), findsOneWidget);
    expect(find.text('Motorista'), findsOneWidget);
  });
}
