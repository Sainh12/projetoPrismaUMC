import 'User.dart';

class Aluno extends User {
  final String _serie;
  final String _turma;
  Aluno(super.nome, super.email, super.senha, super.escola,this._serie,this._turma);

  String get serie => _serie;
  String get turma => _turma;

}