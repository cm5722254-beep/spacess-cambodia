import 'package:flutter_test/flutter_test.dart';
import 'package:spaces_mobile/app.dart';

void main() {
  testWidgets('SpacesApp smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const SpacesApp());
    expect(find.byType(SpacesApp), findsOneWidget);
  });
}
