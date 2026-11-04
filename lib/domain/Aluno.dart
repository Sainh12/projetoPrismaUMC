import 'User.dart';

class Aluno extends User {
  final String _serie;
    Aluno({
  super.id,
  required super.nome, 
  required super.email,
  required super.cpf, 
  required super.senha, 
  required super.escola,
  required String serie,
  }):
  _serie = serie;

  String get serie => _serie;

  factory Aluno.fromJson(Map<String,dynamic> json){
    return Aluno(
      nome: json['nome'] as String,
      email : json ['email'] as String,
      senha : json ['senha'] as String,
      cpf: json ['cpf'] as String,
      escola : json ['escola'] as String,
      serie : json ['serie'] as String,
    );
  }

  factory Aluno.fromMap(Map<String, dynamic> map) =>
  Aluno(
    id: map['id'] as String,
    nome: map['nome'] as String,
    email: map['email'] as String,
    cpf: map['cpf'] as String,
    senha: map['senha'] as String,
    escola: map ['escola'] as String,
    serie: map['serie'] as String
  );

  Map<String, dynamic> toMap()=>{
    'id' : id,
    'nome' : nome,
    'email' : email,
    'cpf' : cpf,
    'senha' : senha,
    'escola' : escola,
    'serie' : serie,
  };
}
