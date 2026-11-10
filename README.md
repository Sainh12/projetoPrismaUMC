# Projeto Prisma

Aplicativo Flutter com APIs Shelf locais para usuários e arquivos.

## Executar

Na raiz deste pacote, execute:

```shell
flutter pub get
flutter run
```

O entrypoint `lib/main.dart` inicia a API de usuários na porta `8080`, a API de arquivos na porta `8081` e a tela Flutter de teste. A API usa SQLite por `sqflite`; execute-a como aplicativo Flutter, não como servidor Dart CLI independente.

### Testar a tela Web com as APIs

Para desenvolvimento no Chrome, abra dois terminais na raiz do projeto. O servidor abaixo usa armazenamento em memória e uma conta demonstrativa; os dados são apagados ao encerrá-lo.

Terminal 1, iniciar as APIs locais com CORS de desenvolvimento:

```shell
dart run bin/dev_api.dart
```

Terminal 2, iniciar a tela no Chrome:

```shell
flutter run -d chrome -t lib/main_web.dart --web-port 5000
```

Acesse `http://localhost:5000` e entre com `aluno@prisma.test` / `Prisma123!`. As APIs ficam em `http://localhost:8080` e `http://localhost:8081`. Esse servidor de demonstração usa armazenamento em memória; para testar o banco SQLite real, execute o entrypoint nativo `lib/main.dart`.

## Testes e análise

```shell
flutter test
flutter analyze
```

## API de questões

A API de questões usa o mesmo servidor e autenticação da API de usuários (porta `8080`). Todas as rotas exigem o token Bearer recebido no login:

- `POST /api/quiz/perguntas` — apenas professores; JSON: `{"enunciado":"...","resposta_correta":"..."}`
- `GET /api/quiz/perguntas` e `GET /api/quiz/perguntas/<id>` — alunos recebem apenas o enunciado; professores também recebem a resposta correta.
- `POST /api/quiz/perguntas/<id>/responder` — apenas alunos; JSON: `{"resposta":"..."}`. Retorna `{"correta":true}` ou `{"correta":false}`.

## APIs

- Cadastro: `POST /api/users/cadastrar`
- Login: `POST /api/users/acesso`
- Logout: `POST /api/users/logout`
- Consulta, atualização e exclusão de usuário: `/api/users/...` (exigem `Authorization: Bearer <access_token>`)
- Upload: `POST /api/upload` com `multipart/form-data` e token Bearer
- Leitura em streaming: `GET /api/video/<nome>` com token Bearer e suporte a `Range`
- Exclusão de arquivo: `DELETE /api/video/<nome>` com token Bearer

Os detalhes de payloads, validação, limites, armazenamento e pendências para implantação estão em [test/analise_apis_e_persistencia.md](test/analise_apis_e_persistencia.md).
