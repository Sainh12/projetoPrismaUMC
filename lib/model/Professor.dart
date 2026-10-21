import 'User.dart';

class Professor extends User {
  String _materia;

  Professor(String nome, String email, String senha, String escola,this._materia) 
  : super (nome,email,senha,escola);

  String get materia => _materia;
}