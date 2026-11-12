class QuizResumo {
  const QuizResumo({
    required this.id,
    required this.videoId,
    this.videoTitulo,
    required this.titulo,
    required this.status,
    required this.quantidadeQuestoes,
  });

  final int id;
  final String videoId;
  final String? videoTitulo;
  final String titulo;
  final String status;
  final int quantidadeQuestoes;

  factory QuizResumo.fromJson(Map<String, dynamic> json) => QuizResumo(
    id: json['id'] as int,
    videoId: json['video_id'] as String,
    videoTitulo: json['video_titulo'] as String?,
    titulo: json['titulo'] as String,
    status: json['status'] as String,
    quantidadeQuestoes: json['quantidade_questoes'] as int,
  );
}
