import 'User.dart';

class Professor extends User {
  Professor({
    super.id,
    required super.nome,
    required super.email,
    required super.cpf,
    required super.escola,
    required super.tipoUsuario,
    required this.materia,
    required this.cndb,
  });

  final String materia;
  final String cndb;

  factory Professor.fromJson(String? idJson, Map<String, dynamic> json) {
    return Professor(
      id: idJson,
      nome: json['nome'] as String,
      email: json['email'] as String,
      cpf: json['cpf'] as String,
      escola: json['escola'] as String,
      materia: json['materia'] as String,
      tipoUsuario: json['tipo_usuario'] as String,
      cndb: json['cndb'] as String,
    );
  }

  factory Professor.fromMap(Map<String, Object?> map) => Professor(
    id: map['usuario_id'] as String,
    nome: map['nome_completo'] as String,
    email: map['email'] as String,
    cpf: map['cpf'] as String,
    escola: map['escola'] as String,
    materia: map['materia'] as String,
    tipoUsuario: map['tipo_usuario'] as String,
    cndb: map['cndb'] as String,
  );

  @override
  Map<String, Map<String, dynamic>> toMap() => {
    'Usuarios': {
      'usuario_id': id,
      'nome_completo': nome,
      'cpf': cpf,
      'email': email,
      'escola': escola,
      'tipo_usuario': 'professor',
    },
    'Professores': {
      'id': id,
      'cndb': cndb,
      'materia': materia,
    },
  };
}
