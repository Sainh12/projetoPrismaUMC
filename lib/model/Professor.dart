import 'User.dart';

class Professor extends User {
  final String _materia;

  Professor({
    required super.nome, 
    required super.email, 
    required super.senha, 
    required super.escola, 
    required this._materia});

  String get materia => _materia;

  factory Professor.fromJson(Map<String,dynamic> json){
    return Professor(
      nome: json['nome'] as String,
      email : json ['email'] as String,
      senha : json ['senha'] as String,
      escola : json ['escola'] as String,
      materia : json ['materia'] as String,
    );
  }

}