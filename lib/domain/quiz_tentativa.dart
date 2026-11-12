class QuizTentativa {
  const QuizTentativa({
    required this.id,
    required this.nota,
    required this.acertos,
    required this.totalQuestoes,
    required this.realizadaEm,
    this.quizId,
    this.alunoId,
  });

  final int id;
  final int? quizId;
  final String? alunoId;
  final double nota;
  final int acertos;
  final int totalQuestoes;
  final DateTime realizadaEm;

  factory QuizTentativa.fromJson(Map<String, dynamic> json) => QuizTentativa(
    id: json['id'] as int,
    nota: (json['nota'] as num).toDouble(),
    acertos: json['acertos'] as int,
    totalQuestoes: json['total_questoes'] as int,
    realizadaEm: DateTime.parse(json['realizada_em'] as String),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'nota': nota,
    'acertos': acertos,
    'total_questoes': totalQuestoes,
    'realizada_em': realizadaEm.toIso8601String(),
  };
}
