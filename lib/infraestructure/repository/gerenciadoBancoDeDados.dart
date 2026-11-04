import 'package:sqflite/sqflite.dart';

import 'database_helper_users.dart';

import '/domain/User.dart';
import '/domain/Professor.dart';
import '/domain/Aluno.dart';

class GerenciadorBancoDeDados {
  Future<int> insertUser(User user) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    List<User> lista = await getUserByEmailAndPassword(
      user.email,
      user.senha,
    );
    if (lista.isNotEmpty) {
      return (0);
    }

    return await db.transaction((txn) async {
      try {
        for (final e in user.toMap().entries) {
          await txn.insert(e.key, e.value);
        }
        return (1);
      } catch (e) {
        print("valores invalidos");
        return (0);
      }
    });
  }

  Future<List<User>> getUserByEmailAndPassword(
    String email,
    String senha,
  ) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    final user = await db.query(
      '''
      Usuarios u 
      LEFT JOIN Professores p ON p.id = u.usuario_id
      LEFT JOIN Alunos a ON a.id = u.usuario_id
      ''',
      columns: [
      'u*', 
      'p.licenciatura', 'p.materia', 
      'a.serie'],
      where: 'email LIKE ? AND senha LIKE ?',
      whereArgs: ['%$email%', '%$senha%'],
    );
    if (user.isEmpty) return [];

    final verificacao = user[0]['tipo_usuario'] as String;

    if (verificacao == 'professor'){
      return user.map(Professor.fromMap).toList();
    }
    return user.map(Aluno.fromMap).toList();
  }

  Future<int> atualizacaoUsuario(User user) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    return await db.transaction((txn) async {
      try {
        for (final e in user.toMap().entries) {
          await txn.update(e.key, e.value);
        }
        return (1);
      } catch (e) {
        print("valores invalidos");
        return (0);
      }
      });
  }


  Future<int> deletarUser(int id) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    return db.delete(
      'Usuario',
      where : 'id = ?',
      whereArgs : [id]
    );
  }
}

