import 'package:path/path.dart';
import 'package:projeto_base_prisma/infraestructure/repository/app_database_factory.dart';
import 'package:sqflite_common/sqlite_api.dart';

class DatabaseHelperQuiz {
  DatabaseHelperQuiz._privateConstructor();

  static final DatabaseHelperQuiz instance =
      DatabaseHelperQuiz._privateConstructor();

  static Database? _database;

  Future<Database> get database async => _database ??= await _conexao();

  Future<Database> _conexao() async {
    final path = join(await appDatabaseFactory.getDatabasesPath(), 'quiz.db');
    return appDatabaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 4,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await _criarTabelaQuizzes(db);
          await _criarTabelaPerguntas(db);
          await _criarTabelaTentativas(db);
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _criarTabelaPerguntasLegada(db);
          if (oldVersion < 3) await _migrarParaQuizzes(db);
          if (oldVersion < 4) await _criarTabelaTentativas(db);
        },
      ),
    );
  }

  Future<void> _criarTabelaQuizzes(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Quizzes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        professor_id TEXT NOT NULL,
        video_id TEXT NOT NULL,
        titulo TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft'
          CHECK (status IN ('draft', 'published')),
        data_criacao TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        data_atualizacao TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        UNIQUE (professor_id, video_id)
      )
    ''');
  }

  Future<void> _criarTabelaPerguntas(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Perguntas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        professor_id TEXT NOT NULL,
        quiz_id INTEGER NOT NULL,
        enunciado TEXT NOT NULL,
        alternativas_json TEXT NOT NULL DEFAULT '[]',
        resposta_correta TEXT NOT NULL,
        data_criacao TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
        FOREIGN KEY (quiz_id) REFERENCES Quizzes(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_perguntas_quiz ON Perguntas(quiz_id)',
    );
  }

  Future<void> _criarTabelaTentativas(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS TentativasQuiz (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quiz_id INTEGER NOT NULL,
        aluno_id TEXT NOT NULL,
        acertos INTEGER NOT NULL,
        total_questoes INTEGER NOT NULL,
        nota REAL NOT NULL,
        realizada_em TEXT NOT NULL,
        FOREIGN KEY (quiz_id) REFERENCES Quizzes(id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_tentativas_quiz_aluno '
      'ON TentativasQuiz(quiz_id, aluno_id, id)',
    );
  }

  Future<void> _criarTabelaPerguntasLegada(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Perguntas (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        professor_id TEXT NOT NULL,
        enunciado TEXT NOT NULL,
        resposta_correta TEXT NOT NULL,
        data_criacao TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }

  Future<void> _migrarParaQuizzes(DatabaseExecutor db) async {
    await _criarTabelaQuizzes(db);
    await db.execute(
      "ALTER TABLE Perguntas ADD COLUMN quiz_id INTEGER REFERENCES Quizzes(id) ON DELETE CASCADE",
    );
    await db.execute(
      "ALTER TABLE Perguntas ADD COLUMN alternativas_json TEXT NOT NULL DEFAULT '[]'",
    );
    final owners = await db.rawQuery(
      'SELECT DISTINCT professor_id FROM Perguntas',
    );
    for (final row in owners) {
      final professorId = row['professor_id'] as String;
      final quizId = await db.insert('Quizzes', {
        'professor_id': professorId,
        'video_id': 'legado:$professorId',
        'titulo': '',
        'status': 'draft',
      });
      await db.update(
        'Perguntas',
        {'quiz_id': quizId},
        where: 'professor_id = ?',
        whereArgs: [professorId],
      );
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_perguntas_quiz ON Perguntas(quiz_id)',
    );
  }
}
