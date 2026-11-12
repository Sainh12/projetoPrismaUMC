import 'dart:convert';
import 'dart:io';

import 'package:projeto_base_prisma/domain/pergunta.dart';
import 'package:projeto_base_prisma/domain/pergunta_rascunho.dart';
import 'package:projeto_base_prisma/domain/quiz.dart';
import 'package:projeto_base_prisma/infraestructure/repository/quiz_repository.dart';
import 'package:projeto_base_prisma/infraestructure/security/session_store.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:sqflite_common/sqlite_api.dart';

class QuizApi {
  QuizApi({
    required this.sessions,
    required this.isVideoOwnedByUser,
    required this.titleForVideo,
    QuizRepository? repository,
  }) : repository = repository ?? SqliteQuizRepository() {
    router.get('/quizzes', _listarQuizzes);
    router.post('/quizzes', _criarQuiz);
    router.get('/quizzes/<id>', _buscarQuiz);
    router.put('/quizzes/<id>', _salvarQuiz);
    router.post('/quizzes/<id>/publicar', _publicarQuiz);
    router.delete('/quizzes/<id>', _excluirQuiz);
    router.get('/quizzes/<id>/tentativas', _listarTentativas);
    router.post('/quizzes/<id>/tentativas', _registrarTentativa);
    router.get('/perguntas', _listarPerguntas);
    router.get('/perguntas/<id>', _buscarPergunta);
    router.post('/perguntas/<id>/responder', _responderPergunta);
  }

  final SessionStore sessions;
  final QuizRepository repository;
  final Future<bool> Function(String userId, String videoName)
  isVideoOwnedByUser;
  final Future<String> Function(String videoName) titleForVideo;
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
              return _json(500, {'message': 'Erro ao acessar os quizzes'});
            }
            stderr.writeln('Erro na API do quiz: $error\n$stackTrace');
            return _json(500, {'message': 'Erro interno do servidor'});
          },
        ),
      )
      .addHandler(router.call);

  Future<Response> _listarQuizzes(Request request) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();

    final role = await repository.tipoUsuario(userId);
    if (role == null) return _unauthorized();
    final quizzes = await repository.listarQuizzes(
      professorId: role == 'professor' ? userId : null,
      publicadosApenas: role == 'aluno',
    );
    final summaries = await Future.wait(
      quizzes.map((quiz) async {
        return {
          'id': quiz.id,
          'video_id': quiz.videoId,
          'video_titulo': await titleForVideo(quiz.videoId),
          'titulo': quiz.titulo,
          'status': quiz.status,
          'quantidade_questoes': quiz.quantidadeQuestoes,
        };
      }),
    );
    return _json(200, {'quizzes': summaries});
  }

  Future<Response> _criarQuiz(Request request) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();
    if (await repository.tipoUsuario(userId) != 'professor') {
      return _forbidden();
    }

    final data = await _decodeObject(request);
    final videoId = _requiredString(data, 'video_id');
    if (videoId == null) {
      throw const _QuizRequestException(400, 'video_id é obrigatório');
    }
    if (!await isVideoOwnedByUser(userId, videoId)) {
      return _json(404, {'message': 'Videoaula não encontrada'});
    }

    final title = await repository.materiaProfessor(userId);
    if (title == null || title.trim().isEmpty) {
      throw const _QuizRequestException(
        400,
        'A matéria do professor não está cadastrada',
      );
    }
    final id = await repository.criarQuiz(userId, videoId, title.trim());
    final quiz = await repository.buscarQuiz(id);
    if (quiz == null) return _notFound();
    return _json(201, {
      'id': id,
      'video_id': quiz.videoId,
      'titulo': quiz.titulo,
      'status': quiz.status,
      'message': quiz.status == 'draft' ? 'Rascunho criado' : 'Quiz existente',
    });
  }

  Future<Response> _buscarQuiz(Request request, String rawId) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();
    final role = await repository.tipoUsuario(userId);
    if (role == null) return _unauthorized();

    final id = _parseId(rawId);
    final quiz = await repository.buscarQuiz(id);
    if (quiz == null) return _notFound();
    if (role == 'professor' && quiz.professorId != userId) {
      return _forbidden();
    }
    if (role == 'aluno' && quiz.status != 'published') return _notFound();

    final questions = await repository.listarPerguntas(quizId: id);
    return _json(
      200,
      _quizResponse(
        quiz,
        questions,
        videoTitle: await titleForVideo(quiz.videoId),
        includeAnswers: role == 'professor',
      ),
    );
  }

  Future<Response> _salvarQuiz(Request request, String rawId) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();
    if (await repository.tipoUsuario(userId) != 'professor') {
      return _forbidden();
    }

    final id = _parseId(rawId);
    final quiz = await repository.buscarQuiz(id);
    if (quiz == null) return _notFound();
    if (quiz.professorId != userId) return _forbidden();

    final data = await _decodeObject(request);
    final rawQuestions = data['questoes'];
    if (rawQuestions is! List) {
      throw const _QuizRequestException(400, 'questoes deve ser uma lista');
    }
    final questions = <PerguntaRascunho>[];
    for (final rawQuestion in rawQuestions) {
      if (rawQuestion is! Map<String, dynamic>) {
        throw const _QuizRequestException(400, 'Questão inválida');
      }
      final statement = _stringValue(rawQuestion, 'enunciado');
      final correctAnswer = _stringValue(rawQuestion, 'resposta_correta');
      final rawAlternatives = rawQuestion['alternativas'];
      if (statement == null ||
          correctAnswer == null ||
          rawAlternatives is! List ||
          rawAlternatives.any((alternative) => alternative is! String)) {
        throw const _QuizRequestException(400, 'Questão inválida');
      }
      questions.add(
        PerguntaRascunho(
          enunciado: statement.trim(),
          alternativas: [
            for (final alternative in rawAlternatives)
              (alternative as String).trim(),
          ],
          respostaCorreta: correctAnswer.trim(),
        ),
      );
    }

    await repository.salvarPerguntas(id, userId, questions);
    return _json(200, {'message': 'Rascunho salvo', 'status': 'draft'});
  }

  Future<Response> _publicarQuiz(Request request, String rawId) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();
    if (await repository.tipoUsuario(userId) != 'professor') {
      return _forbidden();
    }

    final id = _parseId(rawId);
    final quiz = await repository.buscarQuiz(id);
    if (quiz == null) return _notFound();
    if (quiz.professorId != userId) return _forbidden();

    final questions = await repository.listarPerguntas(quizId: id);
    if (questions.isEmpty) {
      throw const _QuizRequestException(
        400,
        'Adicione ao menos uma questão antes de publicar',
      );
    }
    for (final question in questions) {
      final alternatives = question.alternativas;
      if (question.enunciado.trim().isEmpty ||
          alternatives.length < 2 ||
          alternatives.any((alternative) => alternative.trim().isEmpty) ||
          alternatives.toSet().length != alternatives.length ||
          !alternatives.contains(question.respostaCorreta)) {
        throw const _QuizRequestException(
          400,
          'Complete cada questão com enunciado, alternativas únicas e resposta correta',
        );
      }
    }

    if (await repository.publicarQuiz(id, userId) != 1) return _notFound();
    return _json(200, {'message': 'Quiz publicado', 'status': 'published'});
  }

  Future<Response> _excluirQuiz(Request request, String rawId) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();
    if (await repository.tipoUsuario(userId) != 'professor') {
      return _forbidden();
    }

    final id = _parseId(rawId);
    final quiz = await repository.buscarQuiz(id);
    if (quiz == null) return _notFound();
    if (quiz.professorId != userId) return _forbidden();
    if (await repository.excluirQuiz(id, userId) != 1) return _notFound();
    return _json(200, {'message': 'Quiz excluído'});
  }

  Future<Response> _listarTentativas(Request request, String rawId) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();
    if (await repository.tipoUsuario(userId) != 'aluno') return _forbidden();

    final quizId = _parseId(rawId);
    final quiz = await repository.buscarQuiz(quizId);
    if (quiz == null || quiz.status != 'published') return _notFound();

    final attempts = await repository.listarTentativas(quizId, userId);
    return _json(200, {
      'tentativas': [for (final attempt in attempts) attempt.toJson()],
      'nota_mais_recente': attempts.isEmpty ? null : attempts.first.nota,
    });
  }

  Future<Response> _registrarTentativa(Request request, String rawId) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();
    if (await repository.tipoUsuario(userId) != 'aluno') return _forbidden();

    final quizId = _parseId(rawId);
    final quiz = await repository.buscarQuiz(quizId);
    if (quiz == null || quiz.status != 'published') return _notFound();

    final questions = await repository.listarPerguntas(quizId: quizId);
    if (questions.isEmpty) {
      throw const _QuizRequestException(400, 'O quiz não possui questões');
    }

    final data = await _decodeObject(request);
    final rawAnswers = data['respostas'];
    if (rawAnswers is! List || rawAnswers.length != questions.length) {
      throw const _QuizRequestException(
        400,
        'Envie uma resposta para cada questão do quiz',
      );
    }

    final questionsById = {
      for (final question in questions) question.id: question,
    };
    final answers = <int, String>{};
    for (final rawAnswer in rawAnswers) {
      if (rawAnswer is! Map<String, dynamic>) {
        throw const _QuizRequestException(400, 'Resposta inválida');
      }
      final questionId = rawAnswer['pergunta_id'];
      final answer = rawAnswer['resposta'];
      if (questionId is! int ||
          answer is! String ||
          answer.trim().isEmpty ||
          answers.containsKey(questionId)) {
        throw const _QuizRequestException(400, 'Resposta inválida');
      }

      final question = questionsById[questionId];
      final normalizedAnswer = answer.trim();
      if (question == null ||
          !question.alternativas.contains(normalizedAnswer)) {
        throw const _QuizRequestException(
          400,
          'A resposta não corresponde a uma alternativa da questão',
        );
      }
      answers[questionId] = normalizedAnswer;
    }

    final correctAnswers = questions
        .where(
          (question) => answers[question.id] == question.respostaCorreta.trim(),
        )
        .length;
    final grade = double.parse(
      (correctAnswers * 10 / questions.length).toStringAsFixed(2),
    );
    final attempt = await repository.registrarTentativa(
      quizId: quizId,
      alunoId: userId,
      acertos: correctAnswers,
      totalQuestoes: questions.length,
      nota: grade,
    );
    return _json(201, {
      'tentativa': attempt.toJson(),
      'nota_mais_recente': attempt.nota,
    });
  }

  Future<Response> _listarPerguntas(Request request) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();

    final role = await repository.tipoUsuario(userId);
    if (role == null) return _unauthorized();
    final questions = await repository.listarPerguntas(
      professorId: role == 'professor' ? userId : null,
      publicadosApenas: role == 'aluno',
    );
    return _json(200, [
      for (final question in questions)
        _questionResponse(question, includeAnswer: role == 'professor'),
    ]);
  }

  Future<Response> _buscarPergunta(Request request, String rawId) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();
    final role = await repository.tipoUsuario(userId);
    if (role == null) return _unauthorized();

    final id = _parseId(rawId);
    final question = await repository.buscarPergunta(id);
    if (question == null) return _notFound();
    final quiz = await repository.buscarQuiz(question.quizId);
    if (quiz == null) return _notFound();
    if (role == 'professor' && quiz.professorId != userId) {
      return _forbidden();
    }
    if (role == 'aluno' && quiz.status != 'published') return _notFound();
    return _json(
      200,
      _questionResponse(question, includeAnswer: role == 'professor'),
    );
  }

  Future<Response> _responderPergunta(Request request, String rawId) async {
    final userId = sessions.userIdFor(request);
    if (userId == null) return _unauthorized();
    if (await repository.tipoUsuario(userId) != 'aluno') return _forbidden();

    final id = _parseId(rawId);
    final question = await repository.buscarPergunta(id);
    if (question == null) return _notFound();
    final quiz = await repository.buscarQuiz(question.quizId);
    if (quiz == null || quiz.status != 'published') return _notFound();

    final data = await _decodeObject(request);
    final answer = _requiredString(data, 'resposta');
    if (answer == null) {
      throw const _QuizRequestException(400, 'resposta é obrigatória');
    }
    return _json(200, {
      'correta':
          answer.toLowerCase() == question.respostaCorreta.trim().toLowerCase(),
    });
  }

  Map<String, Object?> _quizResponse(
    Quiz quiz,
    List<Pergunta> questions, {
    required String videoTitle,
    required bool includeAnswers,
  }) => {
    'id': quiz.id,
    'video_id': quiz.videoId,
    'video_titulo': videoTitle,
    'titulo': quiz.titulo,
    'status': quiz.status,
    'questoes': [
      for (final question in questions)
        _questionResponse(question, includeAnswer: includeAnswers),
    ],
  };

  Map<String, Object?> _questionResponse(
    Pergunta question, {
    required bool includeAnswer,
  }) => {
    'id': question.id,
    'enunciado': question.enunciado,
    'alternativas': question.alternativas,
    if (includeAnswer) 'resposta_correta': question.respostaCorreta,
  };

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

  String? _stringValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String ? value : null;
  }

  String? _requiredString(Map<String, dynamic> data, String key) {
    final value = _stringValue(data, key);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  int _parseId(String rawId) {
    final id = int.tryParse(rawId);
    if (id == null || id <= 0) {
      throw const _QuizRequestException(400, 'id do quiz inválido');
    }
    return id;
  }

  Response _notFound() => _json(404, {'message': 'Quiz não encontrado'});

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
