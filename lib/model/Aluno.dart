import 'User.dart';

class Aluno extends User {
  String _serie;
  String _turma;
  Aluno(String nome, String email, String senha, String escola,this._serie,this._turma) 
  : super (nome,email,senha,escola);

  String get serie => _serie;
  String get turma => _turma;

}