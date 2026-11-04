import 'package:sqflite/sqflite.dart';
import 'database_helper_users.dart';

import '/domain/Professor.dart';

class GerenciadorBancoDeDados {

  Future<int> insertUserProfessor(Professor professor) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    List<Professor> lista= await getUserProfessorByEmailAndPassword(professor.email, professor.senha);
    if(lista.length>=1){
      return (0);
    }
    return db.insert('professor', professor.toMap());
  }

  Future<List<Professor>> getUserProfessorByEmailAndPassword (String email, String senha) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    final professor = await db.query(
      'Professor',
      where: 'email LIKE ? AND senha LIKE ?',
      whereArgs: ['%$email%','%$senha%'],
    );

    return professor.map(Professor.fromMap).toList();
  }

  Future<int> atualizacaoProfessor(Professor professor) async {
    final id = professor.id;
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