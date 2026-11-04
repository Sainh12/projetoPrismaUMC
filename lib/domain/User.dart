import 'package:uuid/uuid.dart';

const uuid = Uuid();

abstract class User {
  final String _id;
  final String _nome;
  final String _email;
  final String _senha;
  final String _escola;

  User({
    String? id,
    required String nome,
    required String email,
    required String senha,
    required String escola,
  })  : _id = id ?? uuid.v4.toString(),
        _nome = nome,
        _email = email,
        _senha = senha,
        _escola = escola;

  String get id => _id;
  String get nome => _nome;
  String get email => _email;
  String get escola => _escola;
  String get senha => _senha;
}