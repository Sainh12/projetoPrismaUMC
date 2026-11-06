import 'package:uuid/uuid.dart';

const uuid = Uuid();

abstract class User {
  final String _id;
  final String _nome;
  final String _email;
  final String _senha;
  final String _escola;
  final String _cpf;
  final String? _tipoUsuario;


  User({
    String? id,
    required String nome,
    required String email,
    required String cpf,
    required String senha,
    required String escola,
    String? tipoUsuario,
  })  : _id = id ?? uuid.v4(),
        _nome = nome,
        _email = email,
        _senha = senha,
        _escola = escola,
        _cpf = cpf,
        _tipoUsuario = tipoUsuario;


  String get id => _id;
  String get nome => _nome;
  String get email => _email;
  String get escola => _escola;
  String get senha => _senha;
  String get cpf => _cpf;
  String? get tipoUsuario => _tipoUsuario;

  Map<String, Map<String, dynamic>> toMap();

}