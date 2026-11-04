import 'package:sqflite/sqflite.dart';
import 'database_helper_users.dart';

import '/domain/Professor.dart';

class GerenciadorBancoDeDados {

  Future<int> insertUserProfessor(Professor professor) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    return db.insert('professor', professor.toMap());
  }

  Future<Professor> getUserProfessorByEmailAndPassword (String email, String senha) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    final professor = await db.query(
      'Professor',
      where: 'email LIKE ? AND senha LIKE ?',
      whereArgs: ['%$email%','%$senha%'],
    );

    return professor.map(Professor.fromMap);
  }

  Future<int> atualizacaoProfessor(Professor professor) async {
    final id = professor.id;
    if (id == null) {
      throw ArgumentError.Value(professor.id, 'professor.id', 'Não pode ser nulo');
    }

    final Database db = await DatabaseHelperUsers.instance.database;
    return db.update(
      'Professor',
      professor.toMap(),
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletarProfessor(int id) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    return db.delete(
      'Professor',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

}