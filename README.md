# Projeto Prisma

Aplicação Flutter Web com uma API local em Dart/Shelf e persistência SQLite.

## Capturas de tela

<table>
  <tr>
    <td align="center"><strong>Login</strong><br><img src="telas/Captura%20de%20tela%202026-11-16%20152105.png" alt="Tela de login" width="300"></td>
    <td align="center"><strong>Cadastro de videoaula</strong><br><img src="telas/Captura%20de%20tela%202026-11-16%20160249.png" alt="Tela para anexar uma videoaula" width="300"></td>
  </tr>
  <tr>
    <td align="center"><strong>Edição de quiz</strong><br><img src="telas/Captura%20de%20tela%202026-11-16%20160639.png" alt="Tela de edição de quiz" width="300"></td>
    <td align="center"><strong>Feed de videoaulas</strong><br><img src="telas/Captura%20de%20tela%202026-11-16%20160701.png" alt="Feed com uma videoaula" width="300"></td>
  </tr>
  <tr>
    <td align="center"><strong>Perfil do professor</strong><br><img src="telas/Captura%20de%20tela%202026-11-16%20160732.png" alt="Perfil de professor" width="300"></td>
    <td align="center"><strong>Quiz em rascunho</strong><br><img src="telas/Captura%20de%20tela%202026-11-16%20160745.png" alt="Lista de quizzes com um rascunho" width="300"></td>
  </tr>
  <tr>
    <td align="center"><strong>Quiz publicado</strong><br><img src="telas/Captura%20de%20tela%202026-11-16%20161539.png" alt="Lista de quizzes publicados" width="300"></td>
    <td align="center"><strong>Seus vídeos</strong><br><img src="telas/Captura%20de%20tela%202026-11-16%20161604.png" alt="Lista de videoaulas do professor" width="300"></td>
  </tr>
  <tr>
    <td align="center"><strong>Quizzes disponíveis</strong><br><img src="telas/Captura%20de%20tela%202026-11-16%20161725.png" alt="Lista de quizzes para o aluno" width="300"></td>
    <td align="center"><strong>Responder quiz</strong><br><img src="telas/Captura%20de%20tela%202026-11-16%20161750.png" alt="Tela de resposta de quiz" width="300"></td>
  </tr>
  <tr>
    <td align="center"><strong>Resultado e tentativas</strong><br><img src="telas/Captura%20de%20tela%202026-11-16%20161820.png" alt="Histórico de tentativas e respostas do quiz" width="300"></td>
    <td></td>
  </tr>
</table>

## Requisitos

- Flutter e Dart instalados e disponíveis no terminal.
- Google Chrome.

## Executar localmente

Se as dependências ainda não estiverem instaladas, execute uma vez:

```shell
flutter pub get
```

Abra dois terminais na pasta do projeto.

**Terminal 1 — API e banco de dados**

```shell
dart run bin/dev_api.dart
```

**Terminal 2 — aplicação Web**

```shell
flutter run -d chrome -t lib/main_web.dart
```

O Chrome abrirá automaticamente, cadastre uma conta pela tela e faça login. Não há
conta demonstrativa pré-criada.

## Persistência e sessões

- Usuários, credenciais com hash, perguntas, tentativas e notas são armazenados
  em SQLite.
- Vídeos são armazenados como arquivos em `data/uploads/`, organizados por
  professor; os bytes não ficam dentro do SQLite.
- O feed geral mostra vídeos compartilhados. A aba “Seus vídeos” lista apenas
  os vídeos do professor autenticado.
- Login cria um token Bearer compartilhado pelas APIs de usuários, quizzes e
  vídeos. As sessões ficam na memória do processo, expiram após duas horas e
  são invalidadas quando a API é reiniciada. Após reiniciar o servidor, basta
  entrar novamente; as contas, perguntas e vídeos continuam persistidos.
- Excluir uma conta pela API também remove a pasta de vídeos associada a ela.

Este fluxo é para desenvolvimento e demonstração local. A API escuta apenas na
interface de loopback e não fica hospedada na Internet.

## Entry point Flutter nativo

`lib/main.dart` também conecta as APIs ao SQLite usando o plugin `sqflite`.
Esse entry point depende de uma plataforma Flutter nativa com o plugin SQLite
configurado. Para a demonstração Web descrita acima, use `bin/dev_api.dart` e
`lib/main_web.dart`.

## Testes e análise

```shell
flutter test
flutter analyze
```

## Principais rotas da API

As rotas protegidas exigem `Authorization: Bearer <token>` obtido no login.

- `POST /api/users/cadastrar` — cria uma conta de aluno ou professor.
- `POST /api/users/acesso` — autentica e cria uma sessão.
- `POST /api/users/logout` — encerra a sessão atual.
- `DELETE /api/users/<id>` — exclui a conta autenticada, revoga suas sessões e
  remove seus vídeos, quizzes e tentativas.
- `/api/users/...` — consulta, atualiza ou exclui a conta autenticada.
- `POST /api/upload` — envia os campos multipart `video` e `title` (obrigatório,
  até 120 caracteres); apenas professores.
- `GET /api/videos` — lista vídeos publicados para o feed compartilhado,
  incluindo nome técnico, título e data de envio.
- `GET /api/my-videos` — lista os vídeos do professor autenticado, incluindo
  título.
- `GET /api/video/<nome>` — transmite um vídeo, com suporte a `Range`.
- `DELETE /api/video/<nome>` — exclui um vídeo do professor autenticado.
- `GET /api/quiz/quizzes` — lista quizzes próprios para professores e quizzes
  publicados para alunos, com o título da videoaula.
- `POST /api/quiz/quizzes` — cria um rascunho vinculado a uma videoaula própria;
  apenas professores.
- `GET`, `PUT` e `DELETE /api/quiz/quizzes/<id>` — consulta, salva ou exclui
  quizzes próprios; apenas professores para alterações.
- `POST /api/quiz/quizzes/<id>/publicar` — publica um quiz próprio; apenas
  professores.
- `GET /api/quiz/quizzes/<id>/tentativas` — consulta o histórico e a nota mais
  recente do aluno autenticado.
- `POST /api/quiz/quizzes/<id>/tentativas` — envia uma tentativa completa; cada
  questão vale a mesma parte de uma nota de 0 a 10. Novas tentativas são
  permitidas, mantêm o histórico e atualizam a nota mais recente.
- `POST /api/quiz/perguntas/<id>/responder` — responde uma questão; apenas
  alunos.

Detalhes adicionais sobre validação, limites, armazenamento e pendências estão
em [test/analise_apis_e_persistencia.md](test/analise_apis_e_persistencia.md).

# Integrantes do Grupo 

- Emilly Naiara da Silva
- Giovanna Velloni Vieira
- Sabrina Vilela Raimundo
- Saimon Farias dos Passos Rosa
