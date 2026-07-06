import 'package:flutter/material.dart';
import 'app/app.dart';
import 'app/bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppServices.init();
  runApp(const WaToolkitApp());
}
