class Pergunta {
  const Pergunta({
    required this.id,
    required this.enunciado,
    required this.respostaCorreta,
  });

  final int id;
  final String enunciado;
  final String respostaCorreta;

  factory Pergunta.fromMap(Map<String, Object?> map) => Pergunta(
    id: map['id'] as int,
    enunciado: map['enunciado'] as String,
    respostaCorreta: map['resposta_correta'] as String,
  );
}
