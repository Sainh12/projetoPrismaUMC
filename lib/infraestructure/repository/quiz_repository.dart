import 'dart:convert';

import 'package:projeto_base_prisma/domain/pergunta.dart';
import 'package:projeto_base_prisma/domain/pergunta_rascunho.dart';
import 'package:projeto_base_prisma/domain/quiz.dart';
import 'package:projeto_base_prisma/domain/quiz_resumo.dart';
import 'package:projeto_base_prisma/domain/quiz_tentativa.dart';
import 'package:projeto_base_prisma/infraestructure/repository/database_helper_quiz.dart';
import 'package:projeto_base_prisma/infraestructure/repository/database_helper_users.dart';

abstract interface class QuizRepository {
  Future<String?> tipoUsuario(String userId);
  Future<String?> materiaProfessor(String userId);
  Future<int> criarQuiz(String professorId, String videoId, String titulo);
  Future<List<QuizResumo>> listarQuizzes({
    String? professorId,
    required bool publicadosApenas,
  });
  Future<Quiz?> buscarQuiz(int id);
  Future<List<Pergunta>> listarPerguntas({
    int? quizId,
    String? professorId,
    bool publicadosApenas = false,
  });
  Future<Pergunta?> buscarPergunta(int id);
  Future<void> salvarPerguntas(
    int quizId,
    String professorId,
    List<PerguntaRascunho> perguntas,
  );
  Future<int> publicarQuiz(int id, String professorId);
  Future<int> excluirQuiz(int id, String professorId);
  Future<QuizTentativa> registrarTentativa({
    required int quizId,
    required String alunoId,
    required int acertos,
    required int totalQuestoes,
    required double nota,
  });
  Future<List<QuizTentativa>> listarTentativas(int quizId, String alunoId);
}

class SqliteQuizRepository implements QuizRepository {
  SqliteQuizRepository({
    DatabaseHelperQuiz? quizDatabase,
    DatabaseHelperUsers? usersDatabase,
  }) : _quizDatabase = quizDatabase ?? DatabaseHelperQuiz.instance,
       _usersDatabase = usersDatabase ?? DatabaseHelperUsers.instance;

  final DatabaseHelperQuiz _quizDatabase;
  final DatabaseHelperUsers _usersDatabase;

  @override
  Future<String?> tipoUsuario(String userId) async {
    final db = await _usersDatabase.database;
    final rows = await db.query(
      'Usuarios',
      columns: ['tipo_usuario'],
      where: 'usuario_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['tipo_usuario'] as String?;
  }

  @override
  Future<String?> materiaProfessor(String userId) async {
    final db = await _usersDatabase.database;
    final rows = await db.query(
      'Professores',
      columns: ['materia'],
      where: 'id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['materia'] as String?;
  }

  @override
  Future<int> criarQuiz(
    String professorId,
    String videoId,
    String titulo,
  ) async {
    final db = await _quizDatabase.database;
    final existing = await db.query(
      'Quizzes',
      columns: ['id'],
      where: 'professor_id = ? AND video_id = ?',
      whereArgs: [professorId, videoId],
      limit: 1,
    );
    if (existing.isNotEmpty) return existing.first['id'] as int;
    return db.insert('Quizzes', {
      'professor_id': professorId,
      'video_id': videoId,
      'titulo': titulo,
      'status': 'draft',
    });
  }

  @override
  Future<List<QuizResumo>> listarQuizzes({
    String? professorId,
    required bool publicadosApenas,
  }) async {
    final db = await _quizDatabase.database;
    final filters = <String>[];
    final arguments = <Object?>[];
    if (professorId != null) {
      filters.add('q.professor_id = ?');
      arguments.add(professorId);
    }
    if (publicadosApenas) filters.add("q.status = 'published'");

    final rows = await db.rawQuery('''
      SELECT
        q.id,
        q.professor_id,
        q.video_id,
        q.titulo,
        q.status,
        COUNT(p.id) AS quantidade_questoes
      FROM Quizzes q
      LEFT JOIN Perguntas p ON p.quiz_id = q.id
      ${filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}'}
      GROUP BY q.id
      ORDER BY q.data_criacao DESC, q.id DESC
      ''', arguments);
    if (rows.isEmpty) return [];

    final usersDb = await _usersDatabase.database;
    final teacherIds = rows
        .map((row) => row['professor_id'] as String)
        .toSet()
        .toList();
    final teachers = await usersDb.query(
      'Professores',
      columns: ['id', 'materia'],
      where: 'id IN (${List.filled(teacherIds.length, '?').join(', ')})',
      whereArgs: teacherIds,
    );
    final subjects = {
      for (final teacher in teachers)
        teacher['id'] as String: teacher['materia'] as String,
    };

    return [
      for (final row in rows)
        QuizResumo(
          id: row['id'] as int,
          videoId: row['video_id'] as String,
          titulo: (row['titulo'] as String).trim().isNotEmpty
              ? row['titulo'] as String
              : subjects[row['professor_id']] ?? 'Matéria não informada',
          status: row['status'] as String,
          quantidadeQuestoes: row['quantidade_questoes'] as int,
        ),
    ];
  }

  @override
  Future<Quiz?> buscarQuiz(int id) async {
    final db = await _quizDatabase.database;
    final rows = await db.query(
      'Quizzes',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final title = row['titulo'] as String;
    return Quiz(
      id: row['id'] as int,
      professorId: row['professor_id'] as String,
      videoId: row['video_id'] as String,
      titulo: title.trim().isNotEmpty
          ? title
          : await materiaProfessor(row['professor_id'] as String) ??
                'Matéria não informada',
      status: row['status'] as String,
    );
  }

  @override
  Future<List<Pergunta>> listarPerguntas({
    int? quizId,
    String? professorId,
    bool publicadosApenas = false,
  }) async {
    final db = await _quizDatabase.database;
    final filters = <String>[];
    final arguments = <Object?>[];
    if (quizId != null) {
      filters.add('q.id = ?');
      arguments.add(quizId);
    }
    if (professorId != null) {
      filters.add('q.professor_id = ?');
      arguments.add(professorId);
    }
    if (publicadosApenas) filters.add("q.status = 'published'");

    final rows = await db.rawQuery('''
      SELECT p.*
      FROM Perguntas p
      JOIN Quizzes q ON q.id = p.quiz_id
      ${filters.isEmpty ? '' : 'WHERE ${filters.join(' AND ')}'}
      ORDER BY p.id
      ''', arguments);
    return rows.map(Pergunta.fromMap).toList();
  }

  @override
  Future<Pergunta?> buscarPergunta(int id) async {
    final db = await _quizDatabase.database;
    final rows = await db.query(
      'Perguntas',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    return rows.isEmpty ? null : Pergunta.fromMap(rows.first);
  }

  @override
  Future<void> salvarPerguntas(
    int quizId,
    String professorId,
    List<PerguntaRascunho> perguntas,
  ) async {
    final db = await _quizDatabase.database;
    await db.transaction((transaction) async {
      final quiz = await transaction.query(
        'Quizzes',
        columns: ['id'],
        where: 'id = ? AND professor_id = ?',
        whereArgs: [quizId, professorId],
        limit: 1,
      );
      if (quiz.isEmpty) {
        throw StateError('Quiz não encontrado para o professor autenticado.');
      }

      await transaction.delete(
        'Perguntas',
        where: 'quiz_id = ?',
        whereArgs: [quizId],
      );
      for (final question in perguntas) {
        await transaction.insert('Perguntas', {
          'professor_id': professorId,
          'quiz_id': quizId,
          'enunciado': question.enunciado,
          'alternativas_json': jsonEncode(question.alternativas),
          'resposta_correta': question.respostaCorreta,
        });
      }
      await transaction.update(
        'Quizzes',
        {
          'status': 'draft',
          'data_atualizacao': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [quizId],
      );
    });
  }

  @override
  Future<int> publicarQuiz(int id, String professorId) async {
    final db = await _quizDatabase.database;
    return db.update(
      'Quizzes',
      {
        'status': 'published',
        'data_atualizacao': DateTime.now().toUtc().toIso8601String(),
      },
      where: 'id = ? AND professor_id = ?',
      whereArgs: [id, professorId],
    );
  }

  @override
  Future<int> excluirQuiz(int id, String professorId) async {
    final db = await _quizDatabase.database;
    return db.delete(
      'Quizzes',
      where: 'id = ? AND professor_id = ?',
      whereArgs: [id, professorId],
    );
  }

  @override
  Future<QuizTentativa> registrarTentativa({
    required int quizId,
    required String alunoId,
    required int acertos,
    required int totalQuestoes,
    required double nota,
  }) async {
    final db = await _quizDatabase.database;
    final realizadaEm = DateTime.now().toUtc();
    final id = await db.insert('TentativasQuiz', {
      'quiz_id': quizId,
      'aluno_id': alunoId,
      'acertos': acertos,
      'total_questoes': totalQuestoes,
      'nota': nota,
      'realizada_em': realizadaEm.toIso8601String(),
    });
    return QuizTentativa(
      id: id,
      quizId: quizId,
      alunoId: alunoId,
      nota: nota,
      acertos: acertos,
      totalQuestoes: totalQuestoes,
      realizadaEm: realizadaEm,
    );
  }

  @override
  Future<List<QuizTentativa>> listarTentativas(
    int quizId,
    String alunoId,
  ) async {
    final db = await _quizDatabase.database;
    final rows = await db.query(
      'TentativasQuiz',
      where: 'quiz_id = ? AND aluno_id = ?',
      whereArgs: [quizId, alunoId],
      orderBy: 'id DESC',
    );
    return [
      for (final row in rows)
        QuizTentativa(
          id: row['id'] as int,
          quizId: row['quiz_id'] as int,
          alunoId: row['aluno_id'] as String,
          nota: (row['nota'] as num).toDouble(),
          acertos: row['acertos'] as int,
          totalQuestoes: row['total_questoes'] as int,
          realizadaEm: DateTime.parse(row['realizada_em'] as String),
        ),
    ];
  }
}
