import 'dart:convert';

class Pergunta {
  const Pergunta({
    required this.id,
    required this.quizId,
    required this.professorId,
    required this.enunciado,
    required this.alternativas,
    required this.respostaCorreta,
  });

  final int id;
  final int quizId;
  final String professorId;
  final String enunciado;
  final List<String> alternativas;
  final String respostaCorreta;

  factory Pergunta.fromMap(Map<String, Object?> map) {
    final alternatives = jsonDecode(map['alternativas_json'] as String);
    if (alternatives is! List) {
      throw const FormatException('Alternativas inválidas no banco.');
    }

    return Pergunta(
      id: map['id'] as int,
      quizId: map['quiz_id'] as int,
      professorId: map['professor_id'] as String,
      enunciado: map['enunciado'] as String,
      alternativas: alternatives.cast<String>(),
      respostaCorreta: map['resposta_correta'] as String,
    );
  }
}
