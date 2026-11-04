import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelperUsers{

  DatabaseHelperUsers._privateConstructor();

  static final DatabaseHelperUsers instance = DatabaseHelperUsers._privateConstructor();

  static Database? _database;

  Future<Database> get database async => _database ??= await _conexao();

  Future<Database> _conexao() async {
    final path = join(await getDatabasesPath(), '');
    return openDatabase(
      path,
      version:1,
      onCreate: (db,version){
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
    data_nascimento DATE NOT NULL,
    licenciatura VARCHAR(150) NOT NULL,

    CONSTRAINT fk_professores_usuario
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