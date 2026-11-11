import 'package:projeto_base_prisma/domain/pergunta.dart';
import 'package:projeto_base_prisma/infraestructure/repository/database_helper_quiz.dart';
import 'package:projeto_base_prisma/infraestructure/repository/database_helper_users.dart';

abstract interface class QuizRepository {
  Future<String?> tipoUsuario(String userId);
  Future<int> adicionarPergunta(
    String professorId,
    String enunciado,
    String respostaCorreta,
  );
  Future<List<Pergunta>> listarPerguntas();
  Future<Pergunta?> buscarPergunta(int id);
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
  Future<int> adicionarPergunta(
    String professorId,
    String enunciado,
    String respostaCorreta,
  ) async {
    final db = await _quizDatabase.database;
    return db.insert('Perguntas', {
      'professor_id': professorId,
      'enunciado': enunciado,
      'resposta_correta': respostaCorreta,
    });
  }

  @override
  Future<List<Pergunta>> listarPerguntas() async {
    final db = await _quizDatabase.database;
    final rows = await db.query('Perguntas', orderBy: 'id');
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
}
