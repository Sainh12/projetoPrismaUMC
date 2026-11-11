import 'package:path/path.dart';
import 'package:projeto_base_prisma/infraestructure/repository/app_database_factory.dart';
import 'package:sqflite_common/sqlite_api.dart';

class DatabaseHelperUsers {
  DatabaseHelperUsers._privateConstructor();

  static final DatabaseHelperUsers instance =
      DatabaseHelperUsers._privateConstructor();

  static Database? _database;

  Future<Database> get database async =>
      _database ??= await _conexao('usuarios.db');

  Future<Database> _conexao(String nome) async {
    final path = join(await appDatabaseFactory.getDatabasesPath(), nome);
    return appDatabaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onConfigure: (db) async {
          await db.rawQuery('PRAGMA foreign_keys = ON');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              "ALTER TABLE Professores ADD COLUMN cndb TEXT NOT NULL DEFAULT ''",
            );
          }
          if (oldVersion < 3) {
            await db.execute('''
            CREATE TABLE Professores_nova (
              id TEXT PRIMARY KEY,
              materia VARCHAR(150) NOT NULL,
              cndb TEXT NOT NULL DEFAULT '',
              CONSTRAINT fk_professores_usuario
                FOREIGN KEY (id)
                REFERENCES Usuarios(usuario_id)
                ON UPDATE CASCADE
                ON DELETE CASCADE
            )
            ''');
            await db.execute('''
            INSERT INTO Professores_nova (id, materia, cndb)
            SELECT id, materia, cndb FROM Professores
            ''');
            await db.execute('DROP TABLE Professores');
            await db.execute(
              'ALTER TABLE Professores_nova RENAME TO Professores',
            );
          }
        },
        onCreate: (db, version) async {
          await db.execute('''
-- =========================================================
-- TABELA DE USUÁRIOS
-- =========================================================

CREATE TABLE Usuarios (
    usuario_id TEXT PRIMARY KEY,
    nome_completo VARCHAR(150) NOT NULL,
    cpf CHAR(11) NOT NULL UNIQUE,
    email VARCHAR(254) NOT NULL UNIQUE,
    senha VARCHAR(255) NOT NULL,
    escola VARCHAR (255) NOT NULL,
    tipo_usuario TEXT NOT NULL
      CHECK (tipo_usuario IN ('professor', 'aluno'))
    )              ''');

          await db.execute('''
-- =========================================================
-- TABELA DE PROFESSORES
-- =========================================================

CREATE TABLE Professores (
    id TEXT PRIMARY KEY,
    materia VARCHAR (150) NOT NULL,
    cndb TEXT NOT NULL DEFAULT '',

    CONSTRAINT fk_professores_usuario
        FOREIGN KEY (id)
        REFERENCES usuarios(usuario_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);''');

          await db.execute('''
-- =========================================================
-- TABELA DE ALUNOS
-- =========================================================

CREATE TABLE Aluno (
    id TEXT PRIMARY KEY,
    serie VARCHAR(10) NOT NULL,

    CONSTRAINT fk_aluno_usuario
        FOREIGN KEY (id)
        REFERENCES usuarios(usuario_id)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);
          ''');
        },
      ),
    );
  }
}
