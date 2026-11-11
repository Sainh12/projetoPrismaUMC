import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelperUsers {
  DatabaseHelperUsers._privateConstructor();

  static final DatabaseHelperUsers instance =
      DatabaseHelperUsers._privateConstructor();

  static Database? _database;

  Future<Database> get database async =>
      _database ??= await _conexao('usuarios.db');

  Future<Database> _conexao(String nome) async {
    final path = join(await getDatabasesPath(), nome);
    return openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA foreign_keys = ON');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE Professores ADD COLUMN cndb TEXT NOT NULL DEFAULT ''",
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
    )''');

        await db.execute('''
-- =========================================================
-- TABELA DE PROFESSORES
-- =========================================================

CREATE TABLE Professores (
    id TEXT PRIMARY KEY,
    licenciatura VARCHAR(150) NOT NULL,
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
    );
  }
}
