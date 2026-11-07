import 'dart:io';

import 'package:flutter/material.dart';
import 'package:projeto_base_prisma/infraestructure/controller/http/LoginAPI.dart';
import 'package:projeto_base_prisma/application/view/TelasTeste.dart';

Future<void> main() async {
  final api = loginApi();
  final server = await api.iniciando();
  stdout.writeln(
    'API ouvindo em ${server[0]}:${server[1]}',
  );
  runApp(const TelaTeste());
}

Future<void> shutdown() async{}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(body: Center(child: Text('Hello World!'))),
    );
  }
}
