import 'dart:convert';
import 'dart:io';

import 'package:projeto_base_prisma/domain/pergunta.dart';
import 'package:projeto_base_prisma/infraestructure/repository/quiz_repository.dart';
import 'package:projeto_base_prisma/infraestructure/security/session_store.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqflite_common/sqlite_api.dart';

class QuizApi {
  QuizApi({required this.sessions, QuizRepository? repository})
    : repository = repository ?? SqliteQuizRepository() {
    router.get('/perguntas', _listarPerguntas);
    router.post('/perguntas', _criarPergunta);
    router.get('/perguntas/<id>', _buscarPergunta);
    router.post('/perguntas/<id>/responder', _responderPergunta);
  }

  final SessionStore sessions;
  final QuizRepository repository;
  final Router router = Router();

  Handler get handler => const Pipeline()
      .addMiddleware(
        createMiddleware(
          errorHandler: (error, stackTrace) {
            if (error is _QuizRequestException) {
              return _json(error.statusCode, {'message': error.message});
            }
            if (error is DatabaseException) {
              stderr.writeln('Erro no banco do quiz: $error\n$stackTrace');
              return _json(500, {'message': 'Erro ao acessar as perguntas'});
            }
            stderr.writeln('Erro na API do quiz: $error\n$stackTrace');
            return _json(500, {'message': 'Erro interno do servidor'});
          },
        ),
      )
      .addHandler(router.call);

  Future<Response> _listarPerguntas(Request request) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();

    final role = await repository.tipoUsuario(userId);
    if (role == null) return _unauthorized();
    final questions = await repository.listarPerguntas();
    return _json(200, [
      for (final question in questions)
        _questionResponse(question, includeAnswer: role == 'professor'),
    ]);
  }

  Future<Response> _criarPergunta(Request request) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();
    if (await repository.tipoUsuario(userId) != 'professor') {
      return _forbidden();
    }

    final data = await _decodeObject(request);
    final enunciado = _requiredString(data, 'enunciado');
    final respostaCorreta = _requiredString(data, 'resposta_correta');
    if (enunciado == null || respostaCorreta == null) {
      throw const _QuizRequestException(
        400,
        'enunciado e resposta_correta são obrigatórios',
      );
    }

    final id = await repository.adicionarPergunta(
      userId,
      enunciado,
      respostaCorreta,
    );
    return _json(201, {'id': id, 'message': 'Pergunta criada'});
  }

  Future<Response> _buscarPergunta(Request request, String rawId) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();
    final role = await repository.tipoUsuario(userId);
    if (role == null) return _unauthorized();

    final id = _parseId(rawId);
    final question = await repository.buscarPergunta(id);
    if (question == null) {
      return _json(404, {'message': 'Pergunta não encontrada'});
    }
    return _json(
      200,
      _questionResponse(question, includeAnswer: role == 'professor'),
    );
  }

  Future<Response> _responderPergunta(Request request, String rawId) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();
    if (await repository.tipoUsuario(userId) != 'aluno') {
      return _forbidden();
    }

    final id = _parseId(rawId);
    final question = await repository.buscarPergunta(id);
    if (question == null) {
      return _json(404, {'message': 'Pergunta não encontrada'});
    }
    final data = await _decodeObject(request);
    final answer = _requiredString(data, 'resposta');
    if (answer == null) {
      throw const _QuizRequestException(400, 'resposta é obrigatória');
    }

    final correct =
        answer.toLowerCase() == question.respostaCorreta.trim().toLowerCase();
    return _json(200, {'correta': correct});
  }

  int _parseId(String rawId) {
    final id = int.tryParse(rawId);
    if (id == null || id <= 0) {
      throw const _QuizRequestException(400, 'id da pergunta inválido');
    }
    return id;
  }

  Future<Map<String, dynamic>> _decodeObject(Request request) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(await request.readAsString());
    } on FormatException {
      throw const _QuizRequestException(400, 'JSON inválido');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const _QuizRequestException(400, 'Objeto JSON esperado');
    }
    return decoded;
  }

  String? _requiredString(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  Map<String, Object?> _questionResponse(
    Pergunta question, {
    required bool includeAnswer,
  }) => {
    'id': question.id,
    'enunciado': question.enunciado,
    if (includeAnswer) 'resposta_correta': question.respostaCorreta,
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

class _QuizRequestException implements Exception {
  const _QuizRequestException(this.statusCode, this.message);

  final int statusCode;
  final String message;
}
