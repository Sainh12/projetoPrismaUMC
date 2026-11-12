class PerguntaRascunho {
  const PerguntaRascunho({
    required this.enunciado,
    required this.alternativas,
    required this.respostaCorreta,
  });

  final String enunciado;
  final List<String> alternativas;
  final String respostaCorreta;
}
