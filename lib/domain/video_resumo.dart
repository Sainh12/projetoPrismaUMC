class VideoResumo {
  const VideoResumo({required this.nome, required this.titulo});

  final String nome;
  final String titulo;

  factory VideoResumo.fromJson(Map<String, dynamic> json) {
    final name = json['name'];
    if (name is! String || name.isEmpty) {
      throw const FormatException('Nome de vídeo inválido');
    }

    final title = json['title'];
    return VideoResumo(
      nome: name,
      titulo: title is String && title.trim().isNotEmpty ? title : name,
    );
  }
}
