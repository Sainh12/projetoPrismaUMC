import 'dart:io';

import 'package:projeto_base_prisma/domain/Aluno.dart';
import 'package:projeto_base_prisma/domain/User.dart';
import 'package:projeto_base_prisma/infraestructure/controller/http/file_controller_api.dart';
import 'package:projeto_base_prisma/infraestructure/controller/http/login_api.dart';
import 'package:projeto_base_prisma/infraestructure/repository/user_repository.dart';
import 'package:projeto_base_prisma/infraestructure/security/password_hasher.dart';
import 'package:projeto_base_prisma/infraestructure/security/session_store.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

const _demoEmail = 'aluno@prisma.test';
const _demoPassword = 'Prisma123!';

Future<void> main() async {
  final repository = _MemoryUserRepository();
  const passwordHasher = PasswordHasher(logRounds: 4);
  await repository.addDemoUser(passwordHasher);

  final sessions = SessionStore();
  final fileApi = FileController(sessions: sessions);
  final loginApi = LoginApi(
    repository: repository,
    passwordHasher: passwordHasher,
    sessions: sessions,
    onUserDeleted: fileApi.deleteUserFiles,
  );

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
    stdout.writeln('Conta demonstrativa: $_demoEmail / $_demoPassword');
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

class _MemoryUserRepository implements UserRepository {
  final Map<String, User> _usersById = {};
  final Map<String, String> _passwordsByEmail = {};

  Future<void> addDemoUser(PasswordHasher passwordHasher) async {
    final user = Aluno.fromJson(null, {
      'nome': 'Aluno de demonstração',
      'email': _demoEmail,
      'cpf': '12345678901',
      'escola': 'Escola Prisma',
      'tipo_usuario': 'aluno',
      'serie': '3 ano',
    });
    await insertUser(user, passwordHash: await passwordHasher.hash(_demoPassword));
  }

  @override
  Future<int> insertUser(User user, {required String passwordHash}) async {
    if (_usersById.values.any(
      (existing) => existing.email == user.email || existing.cpf == user.cpf,
    )) {
      return 0;
    }
    _usersById[user.id] = user;
    _passwordsByEmail[user.email] = passwordHash;
    return 1;
  }

  @override
  Future<String?> getPasswordCredentialByEmail(String email) async =>
      _passwordsByEmail[email];

  @override
  Future<int> updatePasswordHash(String email, String passwordHash) async {
    if (!_passwordsByEmail.containsKey(email)) return 0;
    _passwordsByEmail[email] = passwordHash;
    return 1;
  }

  @override
  Future<User?> getUserByEmail(String? email) async {
    if (email == null) return null;
    for (final user in _usersById.values) {
      if (user.email == email) return user;
    }
    return null;
  }

  @override
  Future<int> atualizacaoUsuario(User user) async {
    final current = _usersById[user.id];
    if (current == null ||
        _usersById.values.any(
          (existing) =>
              existing.id != user.id &&
              (existing.email == user.email || existing.cpf == user.cpf),
        )) {
      return 0;
    }
    final passwordHash = _passwordsByEmail.remove(current.email);
    _usersById[user.id] = user;
    if (passwordHash != null) _passwordsByEmail[user.email] = passwordHash;
    return 1;
  }

  @override
  Future<int> deletarUser(String id) async {
    final user = _usersById.remove(id);
    if (user == null) return 0;
    _passwordsByEmail.remove(user.email);
    return 1;
  }
}