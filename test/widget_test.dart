import 'package:flutter_test/flutter_test.dart';
import 'package:al_ijadah_pickup/main.dart';

void main() {
  testWidgets('App loads RoleSelectionScreen successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const AlIjadahApp());
    await tester.pump();

    expect(find.text('Al Ijadah Smart Pickup'), findsOneWidget);
    expect(find.text('Parent & Guardian Portal'), findsOneWidget);
    expect(find.text('School Security Scanner'), findsOneWidget);
  });
}
