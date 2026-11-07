import 'dart:io';

import 'package:flutter/material.dart';
import 'package:projeto_base_prisma/application/view/TelasTeste.dart';
import 'package:projeto_base_prisma/infraestructure/controller/http/file_controller_api.dart';
import 'package:projeto_base_prisma/infraestructure/controller/http/login_api.dart';
import 'package:projeto_base_prisma/infraestructure/security/session_store.dart';

final List<HttpServer> _servers = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final sessions = SessionStore();
  final fileApi = FileController(sessions: sessions);
  final loginApi = LoginApi(
    sessions: sessions,
    onUserDeleted: fileApi.deleteUserFiles,
  );
  final loginServer = await loginApi.start();

  try {
    final fileServer = await fileApi.start();
    _servers
      ..add(loginServer)
      ..add(fileServer);
    stdout.writeln(
      'API de usuários ouvindo em ${loginServer.address.host}:${loginServer.port}',
    );
    stdout.writeln(
      'API de arquivos ouvindo em ${fileServer.address.host}:${fileServer.port}',
    );
  } catch (_) {
    await loginServer.close(force: true);
    rethrow;
  }

  runApp(const TelaTeste());
}
