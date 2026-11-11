import 'package:flutter/material.dart';
import 'package:projeto_base_prisma/application/view/TelasTeste.dart';
import 'package:projeto_base_prisma/application/view/file_picker_registration_web.dart'
    as file_picker_registration;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  file_picker_registration.registerFilePickerForWeb();
  runApp(const TelaTeste());
}
