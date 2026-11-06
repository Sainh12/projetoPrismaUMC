import 'dart:convert';
import 'dart:io';

import 'package:projeto_base_prisma/domain/Aluno.dart';
import 'package:projeto_base_prisma/domain/Professor.dart';
import 'package:projeto_base_prisma/infraestructure/controller/http/loginAPI.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Future<Response> _send(
  loginApi api,
  String method,
  String path, {
  Object? body,
  Map<String, String> headers = const {},
}) {
  return api.router.call(
    Request(
      method,
      Uri.parse('http://localhost$path'),
      body: body,
      headers: headers,
    ),
  );
}

void main() {
  group('modelos do domínio', () {
    test('Aluno.fromJson preserva o ID e os campos de aluno', () {
      final aluno = Aluno.fromJson({
        'usuario_id': 'aluno-id-1',
        'nome': 'Aluno Teste',
        'email': 'aluno@example.test',
        'cpf': '12345678901',
        'senha': 'senha-de-teste',
        'escola': 'Escola Teste',
        'tipo_usuario': 'aluno',
        'serie': '3 ano',
      });

      expect(aluno.id, 'aluno-id-1');
      expect(aluno.nome, 'Aluno Teste');
      expect(aluno.email, 'aluno@example.test');
      expect(aluno.escola, 'Escola Teste');
      expect(aluno.serie, '3 ano');

      final map = aluno.toMap();
      expect(map['Usuarios']?['usuario_id'], 'aluno-id-1');
      expect(map['Usuarios']?['tipo_usuario'], 'aluno');
      expect(map['Aluno']?['id'], 'aluno-id-1');
      expect(map['Aluno']?['serie'], '3 ano');
    });

    test('Aluno.fromJson cria ID quando o JSON não contém usuario_id', () {
      final aluno = Aluno.fromJson({
        'nome': 'Aluno Teste',
        'email': 'aluno@example.test',
        'cpf': '12345678901',
        'senha': 'senha-de-teste',
        'escola': 'Escola Teste',
        'tipo_usuario': 'aluno',
        'serie': '3 ano',
      });

      expect(aluno.id, isNotEmpty);
    });

    test('Professor.fromJson preserva o ID e os campos de professor', () {
      final professor = Professor.fromJson({
        'usuario_id': 'professor-id-1',
        'nome': 'Professor Teste',
        'email': 'professor@example.test',
        'cpf': '10987654321',
        'senha': 'senha-de-teste',
        'escola': 'Escola Teste',
        'tipo_usuario': 'professor',
        'materia': 'Matemática',
        'licenciatura': 'Matemática',
      });

      expect(professor.id, 'professor-id-1');
      expect(professor.nome, 'Professor Teste');
      expect(professor.email, 'professor@example.test');
      expect(professor.escola, 'Escola Teste');
      expect(professor.materia, 'Matemática');
      expect(professor.licenciatura, 'Matemática');

      final map = professor.toMap();
      expect(map['Usuarios']?['usuario_id'], 'professor-id-1');
      expect(map['Usuarios']?['tipo_usuario'], 'professor');
      expect(map['Professores']?['id'], 'professor-id-1');
      expect(map['Professores']?['materia'], 'Matemática');
    });
  });

  group('rotas acessíveis sem banco de dados', () {
    late loginApi api;
    late HttpServer server;

    setUpAll(() async {
      api = loginApi();
      server = await api.startApi(
        handler: api.router.call,
        address: InternetAddress.loopbackIPv4,
        port: 0,
      );
    });

    tearDownAll(() async {
      await server.close(force: true);
    });

    test('GET /api/test retorna a lista de demonstração', () async {
      final response = await _send(api, 'GET', '/api/test');
      final body = jsonDecode(await response.readAsString()) as List<dynamic>;

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));
      expect(body, hasLength(2));
      expect((body.first as Map<String, dynamic>)['id'], '1');
    });

    test(
      'GET /api/users/info sem email retorna 400 sem consultar o banco',
      () async {
        final response = await _send(api, 'GET', '/api/users/info');

        expect(response.statusCode, 400);
        expect(jsonDecode(await response.readAsString()), {
          'message': 'email obrigatório',
        });
      },
    );

    test('GET /api/users/info com email vazio retorna 400', () async {
      final response = await _send(api, 'GET', '/api/users/info?email=%20');

      expect(response.statusCode, 400);
    });

    test('POST /api/users/cadastrar com JSON inválido retorna 400', () async {
      final response = await _send(
        api,
        'POST',
        '/api/users/cadastrar',
        body: '{',
        headers: {'content-type': 'application/json'},
      );

      expect(response.statusCode, 400);
      expect(jsonDecode(await response.readAsString()), {
        'message': 'JSON inválido',
      });
    });

    test('POST /api/users/cadastrar requer um objeto JSON', () async {
      final response = await _send(
        api,
        'POST',
        '/api/users/cadastrar',
        body: jsonEncode(['não', 'é', 'objeto']),
        headers: {'content-type': 'application/json'},
      );

      expect(response.statusCode, 400);
      expect(jsonDecode(await response.readAsString()), {
        'message': 'Objeto JSON esperado',
      });
    });

    test('rota não registrada retorna 404', () async {
      final response = await _send(api, 'GET', '/rota-inexistente');

      expect(response.statusCode, 404);
    });
  });
}
