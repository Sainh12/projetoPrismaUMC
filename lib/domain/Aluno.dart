import 'User.dart';

class Aluno extends User {
  final String _serie;
  final String _turma;
    Aluno({
  required super.nome, 
  required super.email, 
  required super.senha, 
  required super.escola, 
  required String serie, 
  required String turma}):
  _serie = serie,
  _turma = turma;

  String get serie => _serie;
  String get turma => _turma;

  factory Aluno.fromJson(Map<String,dynamic> json){
    return Aluno(
      nome: json['nome'] as String,
      email : json ['email'] as String,
      senha : json ['senha'] as String,
      escola : json ['escola'] as String,
      serie : json ['serie'] as String,
      turma : json ['turma'] as String,
    );
  }
}