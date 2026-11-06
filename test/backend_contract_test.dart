import 'dart:convert';

import 'package:projeto_base_prisma/domain/Aluno.dart';
import 'package:projeto_base_prisma/domain/Professor.dart';
import 'package:projeto_base_prisma/infraestructure/controller/http/loginAPI.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

Future<Response> _send(
  ApiServer api,
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
  final api = ApiServer();

  setUpAll(api.start);

  group('modelos do domínio', () {
    test('Aluno.fromJson cria aluno com os campos recebidos', () {
      final aluno = Aluno.fromJson({
        'nome': 'Aluno Teste',
        'email': 'aluno@example.test',
        'cpf': '12345678901',
        'senha': 'senha-de-teste',
        'escola': 'Escola Teste',
        'tipo_usuario': 'aluno',
        'serie': '3º ano',
      });

      expect(aluno.id, isNotEmpty);
      expect(aluno.nome, 'Aluno Teste');
      expect(aluno.email, 'aluno@example.test');
      expect(aluno.senha, 'senha-de-teste');
      expect(aluno.escola, 'Escola Teste');
      expect(aluno.serie, '3º ano');
    });

    test('Professor.fromJson cria professor com os campos recebidos', () {
      final professor = Professor.fromJson({
        'nome': 'Professor Teste',
        'email': 'professor@example.test',
        'cpf': '10987654321',
        'senha': 'senha-de-teste',
        'escola': 'Escola Teste',
        'tipo_usuario': 'professor',
        'materia': 'Matemática',
        'licenciatura': 'Matemática',
      });

      expect(professor.id, isNotEmpty);
      expect(professor.nome, 'Professor Teste');
      expect(professor.email, 'professor@example.test');
      expect(professor.senha, 'senha-de-teste');
      expect(professor.escola, 'Escola Teste');
      expect(professor.materia, 'Matemática');
    });
  });

  group('API HTTP de usuários', () {
    test('GET /api/test retorna a lista de usuários de demonstração', () async {
      final response = await _send(api, 'GET', '/api/test');
      final users = jsonDecode(await response.readAsString()) as List<dynamic>;

      expect(response.statusCode, 200);
      expect(response.headers['content-type'], contains('application/json'));
      expect(users, hasLength(2));
      expect((users.first as Map<String, dynamic>)['id'], '1');
    });

    test('GET /api/users retorna a mensagem de confirmação', () async {
      final response = await _send(api, 'GET', '/api/users');
      final body = jsonDecode(await response.readAsString());

      expect(response.statusCode, 200);
      expect(body, {'message': 'Requisição GET recebida com sucesso'});
    });

    test(
      'POST /api/users aceita o formato de usuário usado pela API',
      () async {
        final response = await _send(
          api,
          'POST',
          '/api/users',
          body: jsonEncode({
            'nome': 'Usuário Teste',
            'email': 'usuario@example.test',
            'senha': 'senha-de-teste',
            'escola': 'Escola Teste',
          }),
          headers: {'content-type': 'application/json'},
        );
        final body = jsonDecode(await response.readAsString());

        expect(response.statusCode, 201);
        expect(body, {'message': 'Usuário recebido com sucesso'});
      },
    );

    test('POST /api/users/professor aceita os campos específicos', () async {
      final response = await _send(
        api,
        'POST',
        '/api/users/professor',
        body: jsonEncode({
          'nome': 'Professor Teste',
          'email': 'professor@example.test',
          'senha': 'senha-de-teste',
          'escola': 'Escola Teste',
          'materia': 'Matemática',
        }),
        headers: {'content-type': 'application/json'},
      );

      expect(response.statusCode, 201);
      expect(jsonDecode(await response.readAsString()), {
        'message': 'Usuário recebido com sucesso',
      });
    });

    test('POST /api/users/aluno aceita os campos específicos', () async {
      final response = await _send(
        api,
        'POST',
        '/api/users/aluno',
        body: jsonEncode({
          'nome': 'Aluno Teste',
          'email': 'aluno@example.test',
          'senha': 'senha-de-teste',
          'escola': 'Escola Teste',
          'serie': '3º ano',
          'turma': 'A',
        }),
        headers: {'content-type': 'application/json'},
      );

      expect(response.statusCode, 201);
      expect(jsonDecode(await response.readAsString()), {
        'message': 'Usuário recebido com sucesso',
      });
    });

    test('rota não registrada retorna 404', () async {
      final response = await _send(api, 'GET', '/rota-inexistente');

      expect(response.statusCode, 404);
    });
  });
}
