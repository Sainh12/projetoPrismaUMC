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
    super.tipoUsuario, 
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
      tipoUsuario: json ['tipo_usuario'] as String,
    );
  }

  void printar(){
    print(id);
  }
  
  @override
  Map<String, Map<String, dynamic>> toMap() => {
    'Usuario': {'id' : id ,
    'nome' : nome,
    'email' : email,
    'senha' : senha,
    'escola' : escola,
    'tipo_usuario' : 'professor',
    },
    'Professores': {
      'id' : id,
      'licenciatura' : materia
    },
  };

  factory Professor.fromMap(Map<String, dynamic> map) => 
  Professor(
    id : map['id'] as String,
    nome: map['nome'] as String,
    email: map['email'] as String,
    cpf: map ['cpf'] as String,
    senha: map['senha'] as String,
    escola: map['escola'] as String,
    materia: map ['materia'] as String,
    tipoUsuario : map ['tipo_usuario'] as String,
  );

}