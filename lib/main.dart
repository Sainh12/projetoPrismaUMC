import 'dart:io';

import 'package:flutter/material.dart';
import 'package:projeto_base_prisma/application/view/TelasTeste.dart';
import 'package:projeto_base_prisma/infraestructure/controller/http/file_controller_api.dart';
import 'package:projeto_base_prisma/infraestructure/controller/http/login_api.dart';
import 'package:projeto_base_prisma/infraestructure/repository/gerenciadoBancoDeDados.dart';
import 'package:projeto_base_prisma/infraestructure/repository/app_database_factory.dart';
import 'package:projeto_base_prisma/infraestructure/controller/http/quiz_api.dart';
import 'package:projeto_base_prisma/infraestructure/security/session_store.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

final List<HttpServer> _servers = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  configureDatabaseFactory(sqflite.databaseFactory);
  final sessions = SessionStore();
  final userRepository = GerenciadorBancoDeDados();
  final fileApi = FileController(
    sessions: sessions,
    isProfessor: userRepository.isProfessorById,
  );
  final loginApi = LoginApi(
    repository: userRepository,
    sessions: sessions,
    onUserDeleted: fileApi.deleteUserFiles,
  );
  final quizApi = QuizApi(sessions: sessions);
  loginApi.router.mount('/api/quiz/', quizApi.handler);
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
