import 'User.dart';

class Professor extends User {
  final String _materia;

  Professor(super.nome, super.email, super.senha, super.escola,this._materia);

  String get materia => _materia;
}