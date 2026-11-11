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
        version: 2,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) => _criarTabelaPerguntas(db),
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) await _criarTabelaPerguntas(db);
        },
      ),
    );
  }

  Future<void> _criarTabelaPerguntas(DatabaseExecutor db) async {
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
}
