import 'package:flutter_driver/driver_extension.dart';
import 'package:starpage/main.dart' as app;

Future<void> main() async {
  enableFlutterDriverExtension();
  app.main();
}
