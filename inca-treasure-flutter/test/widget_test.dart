import 'package:flutter_test/flutter_test.dart';

import 'package:inca_treasure_flutter/main.dart';

void main() {
  testWidgets('renders room entry actions', (WidgetTester tester) async {
    await tester.pumpWidget(const IncaTreasureApp());
    await tester.pump();

    expect(find.text('创建房间'), findsOneWidget);
    expect(find.text('加入房间'), findsOneWidget);
  });
}
