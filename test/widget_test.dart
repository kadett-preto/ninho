import 'package:flutter_test/flutter_test.dart';

import 'package:ninho/ui/core/app.dart';

void main() {
  testWidgets('app boots and renders placeholder', (WidgetTester tester) async {
    await tester.pumpWidget(const NinhoApp());

    expect(find.text('Ninho'), findsWidgets);
    expect(find.text('Bem-vindo ao Ninho.'), findsOneWidget);
  });
}
