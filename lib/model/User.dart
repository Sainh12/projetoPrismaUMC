import 'package:uuid/uuid.dart';
import 'package:uuid/v4.dart';

const uuid = Uuid();

abstract class User {
  final String _id;
  final String _nome;
  final String _email;
  final String _senha;
  final String _escola;



  User({
    required this._nome, 
    required this._email, 
    required this._senha, 
    required this._escola
  })
  : _id = uuid.v4().toString();

  String get id => _id;
  String get nome => _nome;
  String get email => _email;
  String get escola => _escola;
}