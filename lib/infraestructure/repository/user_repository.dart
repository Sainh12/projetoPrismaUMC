import 'package:projeto_base_prisma/domain/User.dart';

abstract interface class UserRepository {
  Future<int> insertUser(User user, {required String passwordHash});
  Future<String?> getPasswordCredentialByEmail(String email);
  Future<int> updatePasswordHash(String email, String passwordHash);
  Future<User?> getUserByEmail(String? email);
  Future<int> atualizacaoUsuario(User user);
  Future<int> deletarUser(String id);
}
