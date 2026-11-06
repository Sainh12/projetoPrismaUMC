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
  required super.tipoUsuario,
  required String serie,
  }):
  _serie = serie;

  String get serie => _serie;

  factory Aluno.fromJson(Map<String,dynamic> json){
    return Aluno(
      id : json ['usuario_id'] as String?,
      nome: json['nome'] as String,
      email : json ['email'] as String,
      senha : json ['senha'] as String,
      cpf: json ['cpf'] as String,
      escola : json ['escola'] as String,
      serie : json ['serie'] as String,
      tipoUsuario: json ['tipo_usuario'] as String,
    );
  }


  
  factory Aluno.fromMap(Map<String, Object?> map) =>
  Aluno(
    id: map['usuario_id'] as String,
    nome: map['nome_completo'] as String,
    email: map['email'] as String,
    cpf: map['cpf'] as String,
    senha: map['senha'] as String,
    escola: map ['escola'] as String,
    serie: map['serie'] as String,
    tipoUsuario: map['tipo_usuario'] as String,
  );

  @override
  Map<String, Map<String, dynamic>> toMap()=>{
    'Usuarios' : {
    'usuario_id' : id,
    'nome_completo' : nome,
    'cpf' : cpf,
    'email' : email,
    'senha' : senha,
    'escola' : escola,
    'tipo_usuario' : 'aluno'
    },
    'Aluno' : {
      'id' : id,
      'serie' : serie
    },
  };
}
