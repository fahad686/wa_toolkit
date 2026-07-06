import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wa_toolkit/app/app.dart';
import 'package:wa_toolkit/app/bootstrap.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await Hive.initFlutter();
    await AppServices.init();
  });

  testWidgets('WA Toolkit dashboard loads', (WidgetTester tester) async {
    await tester.pumpWidget(const WaToolkitApp());
    await tester.pumpAndSettle();

    expect(find.text('WA Toolkit'), findsOneWidget);
    expect(find.text('Status Saver'), findsOneWidget);
    expect(find.text('Deleted Messages'), findsOneWidget);
    expect(find.text('Secure Vault'), findsOneWidget);
  });
}
