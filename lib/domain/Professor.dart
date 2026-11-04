import 'User.dart';

class Professor extends User {
  final String _materia;
  Professor({
    super.id,
    required super.nome, 
    required super.email,
    required super.cpf, 
    required super.senha, 
    required super.escola, 
    required String materia,  
    }):_materia = materia;

  String get materia => _materia;

  factory Professor.fromJson(Map<String,dynamic> json){
    return Professor(
      nome: json['nome'] as String,
      email : json ['email'] as String,
      cpf : json ['cpf'] as String,
      senha : json ['senha'] as String,
      escola : json ['escola'] as String,
      materia : json ['materia'] as String,
    );
  }

  void printar(){
    print(id);
  }
  
  Map<String, Object?> toMap() => {
    'id' : id ,
    'nome' : nome,
    'email' : email,
    'senha' : senha,
    'escola' : escola,
    'materia' : materia,
  };

  factory Professor.fromMap(Map<String, dynamic> map) => 
  Professor(
    id : map['id'] as String,
    nome: map['nome'] as String,
    email: map['email'] as String,
    cpf: map ['cpf'] as String,
    senha: map['senha'] as String,
    escola: map['escola'] as String,
    materia: map ['materia'] as String
  );

}