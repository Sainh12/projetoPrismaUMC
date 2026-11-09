import 'dart:convert';
import 'dart:io';

import 'package:projeto_base_prisma/domain/Aluno.dart';
import 'package:projeto_base_prisma/domain/Professor.dart';
import 'package:projeto_base_prisma/domain/User.dart';
import 'package:projeto_base_prisma/domain/pergunta.dart';
import 'package:projeto_base_prisma/infraestructure/controller/http/file_controller_api.dart';
import 'package:projeto_base_prisma/infraestructure/controller/http/login_api.dart';
import 'package:projeto_base_prisma/infraestructure/controller/http/quiz_api.dart';
import 'package:projeto_base_prisma/infraestructure/repository/quiz_repository.dart';
import 'package:projeto_base_prisma/infraestructure/repository/user_repository.dart';
import 'package:projeto_base_prisma/infraestructure/security/password_hasher.dart';
import 'package:projeto_base_prisma/infraestructure/security/session_store.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

void main() {
  group('domain models', () {
    test('Aluno maps profile fields without exposing a password', () {
      final aluno = Aluno.fromJson(null, {
        'nome': 'Aluno Teste',
        'email': 'aluno@example.test',
        'cpf': '12345678901',
        'escola': 'Escola Teste',
        'tipo_usuario': 'aluno',
        'serie': '3 ano',
      });

      expect(aluno.id, isNotEmpty);
      expect(aluno.serie, '3 ano');
      expect(aluno.toMap()['Usuarios'], isNot(contains('senha')));
      expect(aluno.toMap()['Aluno'], {'id': aluno.id, 'serie': '3 ano'});
    });

    test('Professor maps the profile fields', () {
      final professor = Professor.fromJson('professor-1', {
        'nome': 'Professor Teste',
        'email': 'professor@example.test',
        'cpf': '10987654321',
        'escola': 'Escola Teste',
        'tipo_usuario': 'professor',
        'materia': 'Matemática',
        'licenciatura': 'Matemática',
      });

      expect(professor.id, 'professor-1');
      expect(professor.toMap()['Professores'], {
        'id': 'professor-1',
        'licenciatura': 'Matemática',
        'materia': 'Matemática',
      });
    });
  });

  group('password hashing', () {
    const hasher = PasswordHasher(logRounds: 4);

    test('produces salted bcrypt hashes and verifies the password', () async {
      final firstHash = await hasher.hash('correct horse battery');
      final secondHash = await hasher.hash('correct horse battery');

      expect(hasher.isBcryptHash(firstHash), isTrue);
      expect(firstHash, isNot(secondHash));
      expect(await hasher.verify('correct horse battery', firstHash), isTrue);
      expect(await hasher.verify('wrong password', firstHash), isFalse);
    });
  });

  group('LoginApi', () {
    late _MemoryUserRepository repository;
    late PasswordHasher hasher;
    late LoginApi api;

    setUp(() {
      repository = _MemoryUserRepository();
      hasher = const PasswordHasher(logRounds: 4);
      api = LoginApi(repository: repository, passwordHasher: hasher);
    });

    test('registers a student, stores only a hash, then logs in', () async {
      final registration = await api.handler(
        _jsonRequest(
          'POST',
          '/api/users/cadastrar',
          _studentPayload(
            email: ' Aluno@Example.Test ',
            password: ' Senha-segura-123 ',
          ),
        ),
      );
      expect(registration.statusCode, 201);
      final user = repository.users.single;
      expect(user.email, 'aluno@example.test');
      final storedHash = repository.credentials[user.email]!;
      expect(storedHash, isNot(' Senha-segura-123 '));
      expect(hasher.isBcryptHash(storedHash), isTrue);

      final invalidLogin = await api.handler(
        _jsonRequest('POST', '/api/users/acesso', {
          'email': user.email,
          'senha': 'senha errada',
        }),
      );
      expect(invalidLogin.statusCode, 401);

      final login = await api.handler(
        _jsonRequest('POST', '/api/users/acesso', {
          'email': user.email,
          'senha': ' Senha-segura-123 ',
        }),
      );
      expect(login.statusCode, 200);
      final loginData = jsonDecode(await login.readAsString());
      expect(loginData['access_token'], isNotEmpty);
      expect(loginData['token_type'], 'Bearer');
    });

    test('rejects invalid registration data and duplicate accounts', () async {
      final invalid = await api.handler(
        _jsonRequest('POST', '/api/users/cadastrar', {
          ..._studentPayload(),
          'cpf': '123',
        }),
      );
      expect(invalid.statusCode, 400);
      expect(repository.users, isEmpty);

      final payload = _studentPayload();
      expect(
        (await api.handler(
          _jsonRequest('POST', '/api/users/cadastrar', payload),
        )).statusCode,
        201,
      );
      expect(
        (await api.handler(
          _jsonRequest('POST', '/api/users/cadastrar', payload),
        )).statusCode,
        409,
      );
    });

    test(
      'protects user information and restricts access to token owner',
      () async {
        final owner = _student();
        final other = _student(email: 'outro@example.test', cpf: '12345678902');
        await repository.insertUser(
          owner,
          passwordHash: await hasher.hash('Senha-segura-123'),
        );
        await repository.insertUser(
          other,
          passwordHash: await hasher.hash('Senha-segura-456'),
        );
        final token = api.sessions.create(owner.id);

        final unauthorized = await api.handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/users/info?email=${owner.email}'),
          ),
        );
        expect(unauthorized.statusCode, 401);

        final ownProfile = await api.handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/users/info?email=${owner.email}'),
            headers: {'authorization': 'Bearer $token'},
          ),
        );
        expect(ownProfile.statusCode, 200);
        final userJson = jsonDecode(await ownProfile.readAsString());
        expect(userJson['id'], owner.id);
        expect(userJson.containsKey('cpf'), isFalse);
        expect(userJson.containsKey('senha'), isFalse);

        final otherProfile = await api.handler(
          Request(
            'GET',
            Uri.parse('http://localhost/api/users/info?email=${other.email}'),
            headers: {'authorization': 'Bearer $token'},
          ),
        );
        expect(otherProfile.statusCode, 403);
      },
    );

    test('migrates a valid legacy plaintext password after login', () async {
      final user = _student();
      repository.users.add(user);
      repository.credentials[user.email] = 'Senha-segura-123';

      final response = await api.handler(
        _jsonRequest('POST', '/api/users/acesso', {
          'email': user.email,
          'senha': 'Senha-segura-123',
        }),
      );

      expect(response.statusCode, 200);
      expect(hasher.isBcryptHash(repository.credentials[user.email]!), isTrue);
    });

    test('rejects attempts to update another user', () async {
      final owner = _student();
      final other = _student(email: 'outro@example.test', cpf: '12345678902');
      await repository.insertUser(owner, passwordHash: 'hash');
      await repository.insertUser(other, passwordHash: 'hash');
      final token = api.sessions.create(owner.id);

      final response = await api.handler(
        Request(
          'PATCH',
          Uri.parse('http://localhost/api/users/${other.id}'),
          headers: {'authorization': 'Bearer $token'},
          body: jsonEncode(_studentPayload(email: other.email, cpf: other.cpf)),
        ),
      );

      expect(response.statusCode, 403);
    });

    test(
      'deletes only the authenticated user and revokes their sessions',
      () async {
        final owner = _student();
        await repository.insertUser(owner, passwordHash: 'hash');
        final token = api.sessions.create(owner.id);

        final response = await api.handler(
          Request(
            'DELETE',
            Uri.parse('http://localhost/api/users/${owner.id}'),
            headers: {'authorization': 'Bearer $token'},
          ),
        );

        expect(response.statusCode, 204);
        expect(repository.users, isEmpty);
        expect(
          api.sessions.userIdFor(
            Request(
              'GET',
              Uri.parse('http://localhost/'),
              headers: {'authorization': 'Bearer $token'},
            ),
          ),
          isNull,
        );
      },
    );

    test('deletes stored files after removing the user', () async {
      final deletedUserIds = <String>[];
      final apiWithCleanup = LoginApi(
        repository: repository,
        passwordHasher: hasher,
        onUserDeleted: (userId) async {
          deletedUserIds.add(userId);
        },
      );
      final owner = _student();
      await repository.insertUser(owner, passwordHash: 'hash');
      final token = apiWithCleanup.sessions.create(owner.id);

      final response = await apiWithCleanup.handler(
        Request(
          'DELETE',
          Uri.parse('http://localhost/api/users/${owner.id}'),
          headers: {'authorization': 'Bearer $token'},
        ),
      );

      expect(response.statusCode, 204);
      expect(deletedUserIds, [owner.id]);
    });
  });

  test('logout invalidates the current bearer token', () async {
    final repository = _MemoryUserRepository();
    final api = LoginApi(repository: repository);
    final owner = _student();
    await repository.insertUser(owner, passwordHash: 'hash');
    final token = api.sessions.create(owner.id);

    final response = await api.handler(
      Request(
        'POST',
        Uri.parse('http://localhost/api/users/logout'),
        headers: {'authorization': 'Bearer $token'},
      ),
    );

    expect(response.statusCode, 200);
    expect(
      api.sessions.userIdFor(
        Request(
          'GET',
          Uri.parse('http://localhost/'),
          headers: {'authorization': 'Bearer $token'},
        ),
      ),
      isNull,
    );
  });

  group('QuizApi', () {
    late _MemoryQuizRepository repository;
    late SessionStore sessions;
    late QuizApi api;
    late String professorToken;
    late String studentToken;

    setUp(() {
      repository = _MemoryQuizRepository();
      sessions = SessionStore();
      professorToken = sessions.create('professor-1');
      studentToken = sessions.create('aluno-1');
      api = QuizApi(sessions: sessions, repository: repository);
    });

    test(
      'professor creates questions and students answer without seeing the key',
      () async {
        final created = await api.handler(
          _quizRequest(
            'POST',
            '/perguntas',
            token: professorToken,
            body: {'enunciado': 'Quanto é 2 + 2?', 'resposta_correta': '4'},
          ),
        );
        expect(created.statusCode, 201);
        final id = jsonDecode(await created.readAsString())['id'] as int;

        final studentQuestion = await api.handler(
          _quizRequest('GET', '/perguntas/$id', token: studentToken),
        );
        expect(studentQuestion.statusCode, 200);
        final studentData = jsonDecode(await studentQuestion.readAsString());
        expect(studentData['enunciado'], 'Quanto é 2 + 2?');
        expect(studentData.containsKey('resposta_correta'), isFalse);

        final answer = await api.handler(
          _quizRequest(
            'POST',
            '/perguntas/$id/responder',
            token: studentToken,
            body: {'resposta': ' 4 '},
          ),
        );
        expect(jsonDecode(await answer.readAsString())['correta'], isTrue);

        final teacherQuestions = await api.handler(
          _quizRequest('GET', '/perguntas', token: professorToken),
        );
        final teacherData = jsonDecode(await teacherQuestions.readAsString());
        expect(teacherData.single['resposta_correta'], '4');
      },
    );

    test(
      'only teachers create questions and only students answer them',
      () async {
        final studentCreate = await api.handler(
          _quizRequest(
            'POST',
            '/perguntas',
            token: studentToken,
            body: {'enunciado': 'Pergunta', 'resposta_correta': 'Resposta'},
          ),
        );
        expect(studentCreate.statusCode, 403);

        final professorAnswer = await api.handler(
          _quizRequest(
            'POST',
            '/perguntas/1/responder',
            token: professorToken,
            body: {'resposta': 'Resposta'},
          ),
        );
        expect(professorAnswer.statusCode, 403);

        final missingAuth = await api.handler(
          _quizRequest('GET', '/perguntas'),
        );
        expect(missingAuth.statusCode, 401);
      },
    );

    test('rejects empty question data and reports missing questions', () async {
      final invalid = await api.handler(
        _quizRequest(
          'POST',
          '/perguntas',
          token: professorToken,
          body: {'enunciado': ' ', 'resposta_correta': 'Resposta'},
        ),
      );
      expect(invalid.statusCode, 400);

      final missing = await api.handler(
        _quizRequest('GET', '/perguntas/999', token: studentToken),
      );
      expect(missing.statusCode, 404);
    });

    test('mounts quiz routes on the existing users API server', () async {
      final usersApi = LoginApi(repository: _MemoryUserRepository());
      usersApi.router.mount('/api/quiz/', api.handler);

      final response = await usersApi.handler(
        _quizRequest('GET', '/api/quiz/perguntas', token: studentToken),
      );

      expect(response.statusCode, 200);
    });
  });

  group('FileController', () {
    late Directory uploadDirectory;
    late SessionStore sessions;
    late String token;

    setUp(() async {
      uploadDirectory = await Directory.systemTemp.createTemp('prisma-test-');
      sessions = SessionStore();
      token = sessions.create('owner-id');
    });

    tearDown(() async {
      if (await uploadDirectory.exists()) {
        await uploadDirectory.delete(recursive: true);
      }
    });

    test('rejects unauthenticated uploads', () async {
      final controller = FileController(
        sessions: sessions,
        uploadDirectory: uploadDirectory,
      );
      final response = await controller.router.call(_multipartRequest(''));
      expect(response.statusCode, 401);
    });

    test('enforces the configured upload limit', () async {
      final controller = FileController(
        sessions: sessions,
        uploadDirectory: uploadDirectory,
        maxUploadBytes: 4,
      );
      final response = await controller.router.call(
        _multipartRequest('12345', token: token),
      );

      expect(response.statusCode, 413);
      expect(
        await uploadDirectory
            .list(recursive: true)
            .where((entity) => entity is File)
            .toList(),
        isEmpty,
      );
    });

    test('serves byte ranges and hides files from other users', () async {
      final controller = FileController(
        sessions: sessions,
        uploadDirectory: uploadDirectory,
      );
      final upload = await controller.router.call(
        _multipartRequest('12345', token: token),
      );
      expect(upload.statusCode, 201);
      final savedName = jsonDecode(await upload.readAsString())['name'];

      final range = await controller.router.call(
        Request(
          'GET',
          Uri.parse('http://localhost/api/video/$savedName'),
          headers: {'authorization': 'Bearer $token', 'range': 'bytes=1-2'},
        ),
      );
      expect(range.statusCode, 206);
      expect(range.headers['content-range'], 'bytes 1-2/5');
      expect(await range.readAsString(), '23');

      final otherToken = sessions.create('other-user');
      final hidden = await controller.router.call(
        Request(
          'GET',
          Uri.parse('http://localhost/api/video/$savedName'),
          headers: {'authorization': 'Bearer $otherToken'},
        ),
      );
      expect(hidden.statusCode, 404);

      await controller.deleteUserFiles('owner-id');
      expect(
        await uploadDirectory
            .list(recursive: true)
            .where((entity) => entity is File)
            .toList(),
        isEmpty,
      );
    });

    test('rejects malformed or unsatisfiable range headers', () async {
      final controller = FileController(
        sessions: sessions,
        uploadDirectory: uploadDirectory,
      );
      final upload = await controller.router.call(
        _multipartRequest('12345', token: token),
      );
      final savedName = jsonDecode(await upload.readAsString())['name'];

      for (final range in ['bytes=0-1,3-4', 'bytes=9-10', 'bytes=-0']) {
        final response = await controller.router.call(
          Request(
            'GET',
            Uri.parse('http://localhost/api/video/$savedName'),
            headers: {'authorization': 'Bearer $token', 'range': range},
          ),
        );
        expect(response.statusCode, 416, reason: range);
      }
    });
  });
}

Request _jsonRequest(String method, String path, Map<String, Object?> body) =>
    Request(
      method,
      Uri.parse('http://localhost$path'),
      headers: {'content-type': 'application/json'},
      body: jsonEncode(body),
    );

Request _quizRequest(
  String method,
  String path, {
  String? token,
  Map<String, Object?>? body,
}) => Request(
  method,
  Uri.parse('http://localhost$path'),
  headers: {
    if (body != null) 'content-type': 'application/json',
    if (token != null) 'authorization': 'Bearer $token',
  },
  body: body == null ? null : jsonEncode(body),
);

Request _multipartRequest(String content, {String? token}) => Request(
  'POST',
  Uri.parse('http://localhost/api/upload'),
  headers: {
    'content-type': 'multipart/form-data; boundary=prisma-boundary',
    if (token != null) 'authorization': 'Bearer $token',
  },
  body:
      '\r\n--prisma-boundary\r\n'
      'content-disposition: form-data; name="file"; filename="video.mp4"\r\n'
      'content-type: video/mp4\r\n\r\n'
      '$content'
      '\r\n--prisma-boundary--\r\n',
);

Map<String, Object?> _studentPayload({
  String email = 'aluno@example.test',
  String cpf = '12345678901',
  String password = 'Senha-segura-123',
}) => {
  'nome': 'Aluno Teste',
  'email': email,
  'cpf': cpf,
  'escola': 'Escola Teste',
  'tipo_usuario': 'aluno',
  'serie': '3 ano',
  'senha': password,
};

Aluno _student({
  String email = 'aluno@example.test',
  String cpf = '12345678901',
}) => Aluno.fromJson(null, _studentPayload(email: email, cpf: cpf));

class _MemoryUserRepository implements UserRepository {
  final List<User> users = [];
  final Map<String, String> credentials = {};

  @override
  Future<int> insertUser(User user, {required String passwordHash}) async {
    if (users.any(
      (existing) => existing.email == user.email || existing.cpf == user.cpf,
    )) {
      return 0;
    }
    users.add(user);
    credentials[user.email] = passwordHash;
    return 1;
  }

  @override
  Future<String?> getPasswordCredentialByEmail(String email) async =>
      credentials[email];

  @override
  Future<int> updatePasswordHash(String email, String passwordHash) async {
    if (!credentials.containsKey(email)) return 0;
    credentials[email] = passwordHash;
    return 1;
  }

  @override
  Future<User?> getUserByEmail(String? email) async {
    for (final user in users) {
      if (user.email == email) return user;
    }
    return null;
  }

  @override
  Future<int> atualizacaoUsuario(User user) async {
    final index = users.indexWhere((existing) => existing.id == user.id);
    if (index < 0) return 0;
    users[index] = user;
    return 1;
  }

  @override
  Future<int> deletarUser(String id) async {
    final index = users.indexWhere((user) => user.id == id);
    if (index < 0) return 0;
    credentials.remove(users[index].email);
    users.removeAt(index);
    return 1;
  }
}

class _MemoryQuizRepository implements QuizRepository {
  final Map<String, String> roles = {
    'professor-1': 'professor',
    'aluno-1': 'aluno',
  };
  final List<Pergunta> questions = [];
  int _nextId = 1;

  @override
  Future<String?> tipoUsuario(String userId) async => roles[userId];

  @override
  Future<int> adicionarPergunta(
    String professorId,
    String enunciado,
    String respostaCorreta,
  ) async {
    final id = _nextId++;
    questions.add(
      Pergunta(id: id, enunciado: enunciado, respostaCorreta: respostaCorreta),
    );
    return id;
  }

  @override
  Future<Pergunta?> buscarPergunta(int id) async {
    for (final question in questions) {
      if (question.id == id) return question;
    }
    return null;
  }

  @override
  Future<List<Pergunta>> listarPerguntas() async =>
      List.unmodifiable(questions);
}
