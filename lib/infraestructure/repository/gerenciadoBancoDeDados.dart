import 'package:sqflite/sqflite.dart';

import 'database_helper_users.dart';

import '/domain/User.dart';
import '/domain/Professor.dart';
import '/domain/Aluno.dart';

class GerenciadorBancoDeDados {
//====================================================================

  Future<int> insertUser(User user) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    return await db.transaction((txn) async {
      final bool existente = await getUserByEmail(user.email);
      if (existente) return 0;

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

//====================================================================

  Future<bool> getUserByEmail(
    String email
  ) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    final user = await db.query(
      'Usuarios',
      columns: ['usuario_id'],
      where: 'email LIKE ?',
      whereArgs: [email],
      limit : 1,
    );
    return user.isNotEmpty;
  }

//====================================================================

  Future<bool> getUserByEmailAndPassword(
    String email,
    String senha,
  ) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    final user = await db.query(
      'Usuarios u' ,
      where: 'email LIKE ? AND senha LIKE ?',
      whereArgs: ['%$email%', '%$senha%'],
    );
    return !user.isEmpty;
  }

//====================================================================

  Future<int> atualizacaoUsuario(User user) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    final result = await db.query(
      'Usuario',
      where: 'email LIKE ?',
      whereArgs: [user.email]
    );
    if (result.isNotEmpty){
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
    print ("valor não encontrado");
    return 0;
  }

//====================================================================

  Future<int> deletarUser(User user) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    return db.delete(
      'Usuario',
      where : 'usuario_id = ?',
      whereArgs : [user.id]
    );
  }

//====================================================================

  Future<User?> getUser(User user) async{
  
  final Database db = await DatabaseHelperUsers.instance.database;
  final List<Map<String,Object?>> result = await db.query (
    '''
    Usuarios u
    LEFT JOIN professores p ON p.id = u.usuario_id
    LEFT JOIN Aluno a ON a.id = u.usuario_id
    ''',
    columns: [
      'u.*',
      'p.licenciatura',
      'p.materia',
      'a.serie'
      ],
    where: 'u.email LIKE ?',
    whereArgs: [user.email]
  );
  if (result.isEmpty) return null;

  final verificacao = result[0]['tipo_usuario'] as String;

    if (verificacao == 'professor'){
      return Professor.fromMap(result[0]);
    }
    return Aluno.fromMap(result[0]);
  }
}

