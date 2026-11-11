import 'dart:convert';
import 'dart:io';

import 'package:projeto_base_prisma/domain/Aluno.dart';
import 'package:projeto_base_prisma/domain/Professor.dart';
import 'package:projeto_base_prisma/domain/User.dart';
import 'package:projeto_base_prisma/infraestructure/repository/user_repository.dart';
import 'package:projeto_base_prisma/infraestructure/security/password_hasher.dart';
import 'package:projeto_base_prisma/infraestructure/security/session_store.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

class LoginApi {
  LoginApi({
    required this.repository,
    this.passwordHasher = const PasswordHasher(),
    SessionStore? sessions,
    this.onUserDeleted,
  }) : sessions = sessions ?? SessionStore() {
    router.get('/api/test', _getTest);
    router.get('/api/users/info', _getUser);
    router.get('/api/users/id', _getId);
    router.post('/api/users/cadastrar', _registerUser);
    router.post('/api/users/acesso', _login);
    router.post('/api/users/logout', _logout);
    router.patch('/api/users/<id>', _updateUser);
    router.delete('/api/users/<id>', _deleteUser);
  }

  final UserRepository repository;
  final PasswordHasher passwordHasher;
  final SessionStore sessions;
  final Future<void> Function(String userId)? onUserDeleted;
  final Router router = Router();

  Handler get handler => const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(
        createMiddleware(
          errorHandler: (error, stackTrace) {
            if (error is _RequestException) {
              return _json(error.statusCode, {'message': error.message});
            }
            stderr.writeln('Erro na API de usuários: $error\n$stackTrace');
            return _json(500, {'message': 'Erro interno do servidor'});
          },
        ),
      )
      .addHandler(router.call);

  Future<HttpServer> start({InternetAddress? address, int port = 8080}) =>
      shelf_io.serve(handler, address ?? InternetAddress.anyIPv4, port);

  Future<Response> _registerUser(Request request) async {
    final data = await _decodeObject(request);
    final type = _requiredString(data, 'tipo_usuario');
    final name = _requiredString(data, 'nome');
    final email = _requiredString(data, 'email');
    final cpf = _requiredString(data, 'cpf');
    final school = _requiredString(data, 'escola');
    final password = _passwordValue(data, 'senha');

    if (type == null ||
        name == null ||
        email == null ||
        cpf == null ||
        school == null ||
        password == null) {
      throw const _RequestException(
        400,
        'tipo_usuario, nome, email, cpf, escola e senha são obrigatórios',
      );
    }
    if (type != 'aluno' && type != 'professor') {
      throw const _RequestException(400, 'tipo_usuario inválido');
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw const _RequestException(400, 'Email inválido');
    }
    if (!RegExp(r'^\d{11}$').hasMatch(cpf)) {
      throw const _RequestException(400, 'CPF deve conter 11 dígitos');
    }
    if (password.length < 8) {
      throw const _RequestException(
        400,
        'A senha deve conter pelo menos 8 caracteres',
      );
    }

    late final User user;
    if (type == 'aluno') {
      final serie = _requiredString(data, 'serie');
      if (serie == null) {
        throw const _RequestException(
          400,
          'serie é obrigatória',
        );
      }
      user = Aluno.fromJson(null, {
        ...data,
        'tipo_usuario': type,
        'nome': name,
        'email': email.toLowerCase(),
        'cpf': cpf,
        'escola': school,
        'serie': serie,
      });
    } else {
      final materia = _requiredString(data, 'materia');
      final licenciatura = _requiredString(data, 'licenciatura');
      if (materia == null || licenciatura == null) {
        throw const _RequestException(
          400,
          'materia e licenciatura são obrigatórias para professor',
        );
      }
      user = Professor.fromJson(null, {
        ...data,
        'tipo_usuario': type,
        'nome': name,
        'email': email.toLowerCase(),
        'cpf': cpf,
        'escola': school,
        'materia': materia,
        'licenciatura': licenciatura,
      });
    }

    final passwordHash = await passwordHasher.hash(password);
    final inserted = await repository.insertUser(
      user,
      passwordHash: passwordHash,
    );
    if (inserted == 0) {
      return _json(409, {'message': 'Email ou CPF já cadastrado'});
    }
    return _json(201, {'message': 'Usuário criado'});
  }

  Future<Response> _login(Request request) async {
    final data = await _decodeObject(request);
    final rawEmail = _requiredString(data, 'email');
    final password = _passwordValue(data, 'senha');
    if (rawEmail == null || password == null) {
      throw const _RequestException(400, 'email e senha são obrigatórios');
    }
    final email = rawEmail.toLowerCase();

    final storedCredential = await repository.getPasswordCredentialByEmail(
      email,
    );
    if (storedCredential == null) {
      return _json(401, {'message': 'Email ou senha inválidos'});
    }

    bool validPassword;
    if (passwordHasher.isBcryptHash(storedCredential)) {
      validPassword = await passwordHasher.verify(password, storedCredential);
    } else {
      validPassword = password == storedCredential;
      if (validPassword) {
        final upgradedHash = await passwordHasher.hash(password);
        await repository.updatePasswordHash(email, upgradedHash);
      }
    }

    if (!validPassword) {
      return _json(401, {'message': 'Email ou senha inválidos'});
    }

    final user = await repository.getUserByEmail(email);
    if (user == null) {
      return _json(401, {'message': 'Email ou senha inválidos'});
    }
    final token = sessions.create(user.id);
    return _json(200, {
      'message': 'Login realizado com sucesso',
      'access_token': token,
      'token_type': 'Bearer',
      'expires_in': sessions.lifetime.inSeconds,
      'profile': _loginProfile(user),
    });
  }

  Future<Response> _logout(Request request) async {
    if (!sessions.revoke(request)) return _unauthorized();
    return _json(200, {'message': 'Sessão encerrada'});
  }

  Future<Response> _getUser(Request request) async {
    final userId = _authenticatedUserId(request);
    if (userId == null) return _unauthorized();

    final rawEmail = request.url.queryParameters['email'];
    if (rawEmail == null || rawEmail.trim().isEmpty) {
      throw const _RequestException(400, 'email obrigatório');
    }
    final email = rawEmail.trim().toLowerCase();
    final user = await repository.getUserByEmail(email);
    if (user == null) return _json(404, {'message': 'Usuário não encontrado'});
    if (user.id != userId) return _forbidden();
    return _json(200, _userResponse(user));
  }

  Future<Response> _getId(Request request) async {
    final userId = _authenticatedUserId(request);
    if (userId == null) return _unauthorized();

    final rawEmail = request.url.queryParameters['email'];
    if (rawEmail == null || rawEmail.trim().isEmpty) {
      throw const _RequestException(400, 'email obrigatório');
    }
    final email = rawEmail.trim().toLowerCase();
    final user = await repository.getUserByEmail(email);
    if (user == null) return _json(404, {'message': 'Usuário não encontrado'});
    if (user.id != userId) return _forbidden();
    return _json(200, {'id': user.id});
  }

  Future<Response> _updateUser(Request request, String id) async {
    final userId = _authenticatedUserId(request);
    if (userId == null) return _unauthorized();
    if (id != userId) return _forbidden();

    final data = await _decodeObject(request);
    final type = _requiredString(data, 'tipo_usuario');
    final name = _requiredString(data, 'nome');
    final email = _requiredString(data, 'email');
    final cpf = _requiredString(data, 'cpf');
    final school = _requiredString(data, 'escola');
    if (type == null ||
        name == null ||
        email == null ||
        cpf == null ||
        school == null) {
      throw const _RequestException(
        400,
        'tipo_usuario, nome, email, cpf e escola são obrigatórios',
      );
    }
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email) ||
        !RegExp(r'^\d{11}$').hasMatch(cpf)) {
      throw const _RequestException(400, 'Email ou CPF inválido');
    }

    late final User user;
    if (type == 'aluno') {
      final serie = _requiredString(data, 'serie');
      if (serie == null) {
        throw const _RequestException(400, 'serie inválida');
      }
      user = Aluno.fromJson(id, {
        ...data,
        'tipo_usuario': type,
        'nome': name,
        'email': email.toLowerCase(),
        'cpf': cpf,
        'escola': school,
        'serie': serie,
      });
    } else if (type == 'professor') {
      final materia = _requiredString(data, 'materia');
      final licenciatura = _requiredString(data, 'licenciatura');
      if (materia == null || licenciatura == null) {
        throw const _RequestException(400, 'Dados do professor inválidos');
      }
      user = Professor.fromJson(id, {
        ...data,
        'tipo_usuario': type,
        'nome': name,
        'email': email.toLowerCase(),
        'cpf': cpf,
        'escola': school,
        'materia': materia,
        'licenciatura': licenciatura,
      });
    } else {
      throw const _RequestException(400, 'tipo_usuario inválido');
    }

    final updated = await repository.atualizacaoUsuario(user);
    if (updated == 0) {
      return _json(404, {'message': 'Usuário não encontrado'});
    }
    return Response(204);
  }

  Future<Response> _deleteUser(Request request, String id) async {
    final userId = _authenticatedUserId(request);
    if (userId == null) return _unauthorized();
    if (id != userId) return _forbidden();

    final deleted = await repository.deletarUser(id);
    if (deleted == 0) {
      return _json(404, {'message': 'Usuário não encontrado'});
    }
    sessions.revokeUser(id);
    await onUserDeleted?.call(id);
    return Response(204);
  }

  Future<Response> _getTest(Request request) async => _json(200, [
    {'id': 1, 'name': 'Saimon'},
    {'id': 2, 'name': 'João'},
  ]);

  String? _authenticatedUserId(Request request) => sessions.userIdFor(request);

  Future<Map<String, dynamic>> _decodeObject(Request request) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(await request.readAsString());
    } on FormatException {
      throw const _RequestException(400, 'JSON inválido');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const _RequestException(400, 'Objeto JSON esperado');
    }
    return decoded;
  }

  String? _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  String? _passwordValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) return null;
    return value;
  }

  Map<String, Object?> _userResponse(User user) => {
    'id': user.id,
    'nome': user.nome,
    'email': user.email,
    'escola': user.escola,
    'tipo_usuario': user.tipoUsuario,
    if (user is Aluno) 'serie': user.serie,
    if (user is Professor) ...{
      'materia': user.materia,
      'licenciatura': user.licenciatura,
    },
  };

  Map<String, Object?> _loginProfile(User user) => {
    'id': user.id,
    'nome': user.nome,
    'email': user.email,
    'cpf': user.cpf,
    'escola': user.escola,
    'tipo_usuario': user.tipoUsuario,
    if (user is Aluno) 'serie': user.serie,
    if (user is Professor) ...{
      'cndb': user.cndb,
      'materia': user.materia,
      'licenciatura': user.licenciatura,
    },
  };

  Response _unauthorized() =>
      _json(401, {'message': 'Autenticação necessária'});

  Response _forbidden() => _json(403, {'message': 'Acesso não autorizado'});

  Response _json(int statusCode, Object body) => Response(
    statusCode,
    body: jsonEncode(body),
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

class _RequestException implements Exception {
  const _RequestException(this.statusCode, this.message);

  final int statusCode;
  final String message;
}
