import 'User.dart';

class Professor extends User {
  final String _materia;
  final String _licenciatura;

  Professor({
    super.id,
    required super.nome,
    required super.email,
    required super.cpf,
    required super.senha,
    required super.escola,
    super.tipoUsuario,
    required String materia,
    required String licenciatura
  }) : _materia = materia,
       _licenciatura = licenciatura;

  String get materia => _materia;
  String get licenciatura=> _licenciatura;

  factory Professor.fromJson(Map<String, dynamic> json) {
    return Professor(
      nome: json['nome'] as String,
      email: json['email'] as String,
      cpf: json['cpf'] as String,
      senha: json['senha'] as String,
      escola: json['escola'] as String,
      materia: json['materia'] as String,
      tipoUsuario: json['tipo_usuario'] as String,
      licenciatura: json ['licenciatura'] as String
    );
  }

  void printar() {
    print(id);
  }

  @override
  Map<String, Map<String, dynamic>> toMap() => {
    'Usuario': {
      'usuario_id': id,
      'nome_completo': nome,
      'cpf': cpf,
      'email': email,
      'senha': senha,
      'escola': escola,
      'tipo_usuario': 'professor',
    },
    'Professores': {
      'id': id,
      'licenciatura' : licenciatura,
      'materia': materia},
  };

  factory Professor.fromMap(Map<String, Object?> map) => Professor(
    id: map['id'] as String,
    nome: map['nome'] as String,
    email: map['email'] as String,
    cpf: map['cpf'] as String,
    senha: map['senha'] as String,
    escola: map['escola'] as String,
    materia: map['materia'] as String,
    tipoUsuario: map['tipo_usuario'] as String,
    licenciatura: map ['licenciatura'] as String,
  );
}
