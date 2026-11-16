import 'package:uuid/uuid.dart';

const uuid = Uuid();

abstract class User {
  final String id;
  final String nome;
  final String email;
  final String escola;
  final String cpf;
  final String? tipoUsuario;

  User({
    String? id,
    required this.nome,
    required this.email,
    required this.cpf,
    required this.escola,
    this.tipoUsuario,
  }) : id = id ?? uuid.v4();

  Map<String, Map<String, dynamic>> toMap();
}
