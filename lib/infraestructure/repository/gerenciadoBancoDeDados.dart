import 'package:projeto_base_prisma/domain/Aluno.dart';
import 'package:projeto_base_prisma/domain/Professor.dart';
import 'package:projeto_base_prisma/domain/User.dart';
import 'package:projeto_base_prisma/infraestructure/repository/database_helper_users.dart';
import 'package:projeto_base_prisma/infraestructure/repository/user_repository.dart';

class GerenciadorBancoDeDados implements UserRepository {
  @override
  Future<int> insertUser(User user, {required String passwordHash}) async {
    final db = await DatabaseHelperUsers.instance.database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        'Usuarios',
        columns: ['usuario_id'],
        where: 'email = ? OR cpf = ?',
        whereArgs: [user.email, user.cpf],
        limit: 1,
      );
      if (existing.isNotEmpty) return 0;

      for (final entry in user.toMap().entries) {
        final values = Map<String, Object?>.from(entry.value);
        if (entry.key == 'Usuarios') values['senha'] = passwordHash;
        await txn.insert(entry.key, values);
      }
      return 1;
    });
  }

  @override
  Future<String?> getPasswordCredentialByEmail(String email) async {
    final db = await DatabaseHelperUsers.instance.database;
    final rows = await db.query(
      'Usuarios',
      columns: ['senha'],
      where: 'email = ?',
      whereArgs: [email],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['senha'] as String?;
  }

  @override
  Future<int> updatePasswordHash(String email, String passwordHash) async {
    final db = await DatabaseHelperUsers.instance.database;
    return db.update(
      'Usuarios',
      {'senha': passwordHash},
      where: 'email = ?',
      whereArgs: [email],
    );
  }

  @override
  Future<int> atualizacaoUsuario(User user) async {
    final db = await DatabaseHelperUsers.instance.database;
    return db.transaction((txn) async {
      final existing = await txn.query(
        'Usuarios',
        columns: ['usuario_id'],
        where: 'usuario_id = ?',
        whereArgs: [user.id],
        limit: 1,
      );
      if (existing.isEmpty) return 0;

      final userMap = user.toMap();
      for (final table in userMap.keys.where((table) => table != 'Usuarios')) {
        final profile = await txn.query(
          table,
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [user.id],
          limit: 1,
        );
        if (profile.isEmpty) return 0;
      }

      for (final entry in userMap.entries) {
        final values = Map<String, Object?>.from(entry.value);
        final idColumn = entry.key == 'Usuarios' ? 'usuario_id' : 'id';
        values.remove(idColumn);
        final updated = await txn.update(
          entry.key,
          values,
          where: '$idColumn = ?',
          whereArgs: [user.id],
        );
        if (updated != 1) {
          throw StateError('Não foi possível atualizar a tabela ${entry.key}.');
        }
      }
      return 1;
    });
  }

  @override
  Future<int> deletarUser(String id) async {
    final db = await DatabaseHelperUsers.instance.database;
    return db.delete('Usuarios', where: 'usuario_id = ?', whereArgs: [id]);
  }

  @override
  Future<User?> getUserByEmail(String? email) async {
    if (email == null || email.trim().isEmpty) return null;

    final db = await DatabaseHelperUsers.instance.database;
    final rows = await db.rawQuery(
      '''
      SELECT
        u.usuario_id,
        u.nome_completo,
        u.cpf,
        u.email,
        u.escola,
        u.tipo_usuario,
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
    if (rows.isEmpty) return null;

    return switch (rows.first['tipo_usuario']) {
      'professor' => Professor.fromMap(rows.first),
      'aluno' => Aluno.fromMap(rows.first),
      _ => throw StateError('Tipo de usuário inválido no banco.'),
    };
  }
}
