import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelperUsers{

  DatabaseHelperUsers._privateConstructor();

  static final DatabaseHelperUsers instance = DatabaseHelperUsers._privateConstructor();

  static Database? _database;

  Future<Database> get database async => _database ??= await _conexao('usuarios.db');

  Future<Database> _conexao(String nome) async {
    final path = join(await getDatabasesPath(), nome);
    return openDatabase(
      path,
      version:1,
      onConfigure: (db) async {
        await db.rawQuery('PRAGMA foreign_keys = ON');
      },
      onCreate: (db,version) async {
        return db.execute('''
-- =========================================================
-- TABELA DE USUÁRIOS
-- =========================================================

CREATE TABLE Usuarios (
    usuario_id BIGINT UNSIGNED PRIMARY KEY,
    nome_completo VARCHAR(150) NOT NULL,
    cpf CHAR(11) NOT NULL UNIQUE,
    email VARCHAR(254) NOT NULL UNIQUE,
    senha VARCHAR(255) NOT NULL,
    tipo_usuario ENUM('professor', 'aluno') NOT NULL
);
-- =========================================================
-- TABELA DE PROFESSORES
-- =========================================================

CREATE TABLE Professores (
    id BIGINT UNSIGNED PRIMARY KEY,
    licenciatura VARCHAR(150) NOT NULL,
    materia VARCHAR (150) NOT NULL,

    CONSTRAINT fk_professores_usuario
        FOREIGN KEY (id)
        REFERENCES usuarios(usuario_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);
-- =========================================================
-- TABELA DE ALUNOS
-- =========================================================

CREATE TABLE Aluno (
    id BIGINT UNSIGNED PRIMARY KEY,
    serie INT NOT NULL,

    CONSTRAINT fk_aluno_usuario
        FOREIGN KEY (id)
        REFERENCES usuarios(usuario_id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);
''');
      }
    );
  }
}