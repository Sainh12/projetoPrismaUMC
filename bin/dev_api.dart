import 'dart:io';

import 'package:projeto_base_prisma/infraestructure/controller/http/file_controller_api.dart';
import 'package:projeto_base_prisma/infraestructure/controller/http/login_api.dart';
import 'package:projeto_base_prisma/infraestructure/controller/http/quiz_api.dart';
import 'package:projeto_base_prisma/infraestructure/repository/app_database_factory.dart';
import 'package:projeto_base_prisma/infraestructure/repository/gerenciadoBancoDeDados.dart';
import 'package:projeto_base_prisma/infraestructure/security/session_store.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<void> main() async {
  sqfliteFfiInit();
  final sqliteFactory = databaseFactoryFfi;
  configureDatabaseFactory(sqliteFactory);
  final dataDirectory = Directory(
    Platform.environment['PRISMA_DATA_DIR'] ?? 'data',
  ).absolute;
  final databaseDirectory = Directory(p.join(dataDirectory.path, 'databases'));
  await databaseDirectory.create(recursive: true);
  await Directory(p.join(dataDirectory.path, 'uploads'))
      .create(recursive: true);
  await sqliteFactory.setDatabasesPath(databaseDirectory.path);

  final repository = GerenciadorBancoDeDados();
  final sessions = SessionStore();
  final fileApi = FileController(
    sessions: sessions,
    isProfessor: repository.isProfessorById,
    uploadDirectory: Directory(p.join(dataDirectory.path, 'uploads')),
  );
  final loginApi = LoginApi(
    repository: repository,
    sessions: sessions,
    onUserDeleted: fileApi.deleteUserFiles,
  );
  final quizApi = QuizApi(sessions: sessions);
  loginApi.router.mount('/api/quiz/', quizApi.handler);

  final loginServer = await shelf_io.serve(
    _withDevelopmentCors(loginApi.handler),
    InternetAddress.loopbackIPv4,
    8080,
  );
  try {
    final fileServer = await shelf_io.serve(
      _withDevelopmentCors(fileApi.handler),
      InternetAddress.loopbackIPv4,
      8081,
    );
    stdout.writeln('API de usuários: http://localhost:${loginServer.port}');
    stdout.writeln('API de arquivos: http://localhost:${fileServer.port}');
    stdout.writeln('Banco SQLite: ${await sqliteFactory.getDatabasesPath()}');
    stdout.writeln(
      'Arquivos de vídeo: ${p.join(dataDirectory.path, 'uploads')}',
    );
    stdout.writeln('Cadastre uma conta pela tela do aplicativo.');
    stdout.writeln('Pressione Ctrl+C para encerrar.');
  } catch (_) {
    await loginServer.close(force: true);
    rethrow;
  }
}

Handler _withDevelopmentCors(Handler inner) {
  const corsHeaders = {
    'access-control-allow-origin': '*',
    'access-control-allow-methods': 'GET, POST, PATCH, DELETE, OPTIONS',
    'access-control-allow-headers': 'Origin, Content-Type, Authorization',
    'access-control-max-age': '600',
  };

  return (request) async {
    if (request.method == 'OPTIONS') {
      return Response(204, headers: corsHeaders);
    }
    final response = await inner(request);
    return response.change(headers: {...response.headers, ...corsHeaders});
  };
}
