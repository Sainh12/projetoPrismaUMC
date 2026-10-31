import 'dart:io';

class GerenciadorDeArquivos {
  
  Future<void> criarArquivo(String caminho, String conteudo) async {
    final arquivo = File(caminho);
    await arquivo.writeAsBytes(conteudo.codeUnits);
  }

}