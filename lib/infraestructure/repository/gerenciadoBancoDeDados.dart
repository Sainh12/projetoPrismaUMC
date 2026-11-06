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
      final existing = await txn.query(
        'Usuarios',
        columns: ['usuario_id'],
        where: 'email=?',
        whereArgs: [user.email],
        limit: 1,
      );

      if (existing.isNotEmpty) return 0;

        for (final e in user.toMap().entries) {
          await txn.insert(e.key, e.value);
        }
        return 1;
      }); 
  }
  //====================================================================

  Future<bool> getUserByEmailAndPassword(String email, String senha) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    final user = await db.query(
      'Usuarios',
      where: 'email = ? AND senha = ?',
      whereArgs: [email, senha],
    );
    return !user.isEmpty;
  }

  //====================================================================

  Future<int> atualizacaoUsuario(User user) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    final result = await db.query(
      'Usuarios',
      where: 'email = ?',
      whereArgs: [user.email],
    );
    if (result.isNotEmpty) {
      return await db.transaction((txn) async {
        
          for (final e in user.toMap().entries) {
            final tabela = e.key;
            final dados = Map<String, Object?>.from(e.value);

            final colunaId = tabela == 'Usuarios' ? 'usuario_id' : 'id';
            dados.remove(colunaId);

            final linhasAtualizadas = await txn.update(
              tabela,
              dados,
              where: '$colunaId = ?',
              whereArgs: [user.id],
            );
            if (linhasAtualizadas == 0) {
              throw StateError('Nenhuma linha atualizada na tabela $tabela.');
            }
          }
          return (1);
        
      });
    }
    print("valor não encontrado");
    return 0;
  }

  //====================================================================

  Future<int> deletarUser(User user) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    return db.delete('Usuarios', where: 'usuario_id = ?', whereArgs: [user.id]);
  }

  //====================================================================

  Future<User?> getUserByEmail(String email) async {
    final Database db = await DatabaseHelperUsers.instance.database;
    final List<Map<String, Object?>> result = await db.rawQuery(
      '''
    SELECT
      u.*,
      p.materia,
      p.licenciatura,
      a.serie
    FROM Usuarios u
    LEFT JOIN Professores p ON p.id = u.usuario_id
    LEFT JOIN Aluno a ON a.id = u.usuario_id
    WHERE u.email = ?
    LIMIT 1
  ''',
      [email],
    );
    if (result.isEmpty) return null;

    final verificacao = result.first;
    switch (verificacao['tipo_usuario']) {
      case 'professor':
        return Professor.fromMap(result[0]);
      case 'aluno':
        return Aluno.fromMap(result[0]);
      default:
        throw StateError('Tipo de usuário inválido no banco.');
    }
  }
}
