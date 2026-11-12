class Quiz {
  const Quiz({
    required this.id,
    required this.professorId,
    required this.videoId,
    required this.titulo,
    required this.status,
  });

  final int id;
  final String professorId;
  final String videoId;
  final String titulo;
  final String status;

  factory Quiz.fromMap(Map<String, Object?> map) => Quiz(
    id: map['id'] as int,
    professorId: map['professor_id'] as String,
    videoId: map['video_id'] as String,
    titulo: map['titulo'] as String,
    status: map['status'] as String,
  );
}
