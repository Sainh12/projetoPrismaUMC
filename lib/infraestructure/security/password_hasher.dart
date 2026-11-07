import 'dart:isolate';

import 'package:bcrypt/bcrypt.dart';

class PasswordHasher {
  const PasswordHasher({this.logRounds = 12});

  final int logRounds;

  Future<String> hash(String password) => Isolate.run(
    () => BCrypt.hashpw(password, BCrypt.gensalt(logRounds: logRounds)),
  );

  Future<bool> verify(String password, String hash) =>
      Isolate.run(() => BCrypt.checkpw(password, hash));

  bool isBcryptHash(String value) =>
      RegExp(r'^\$2[aby]\$\d\d\$').hasMatch(value);
}
