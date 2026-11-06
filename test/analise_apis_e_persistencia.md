# Reanálise das APIs, persistência, modelos e testes

## Escopo e método

Esta revisão foi feita sobre o estado atual dos arquivos em `lib/`, `bin/`, `compose.yml` e `test/`. **Nenhum arquivo de produção foi modificado nesta atualização**; as mudanças desta tarefa ficam limitadas aos testes e a este relatório.

Os testes que dependem do SQLite não foram simulados nem declarados aprovados: `GerenciadorBancoDeDados` instancia diretamente `DatabaseHelperUsers.instance`, que usa `sqflite`, sem uma interface/injeção de dependência para substituir o banco. A suíte corrigida testa os modelos e os caminhos HTTP que não acessam o banco. A integração de persistência ainda precisa de configuração própria por plataforma ou de uma camada de repositório substituível.

## Resumo executivo

### Correções já presentes no código analisado

- O upload limita cada parte de arquivo aceita a **100 MiB**, contando bytes no stream, apagando o arquivo parcial e respondendo 413 quando excede o limite.
- A consulta de usuário lê `email` pela query string, verifica valor ausente/vazio e produz um DTO que não inclui senha.
- `Aluno.fromJson` e `Professor.fromJson` aceitam `usuario_id`, permitindo preservar um ID se o cliente o enviar.
- A inicialização da API de usuário já usa endereço opcional, evitando o valor padrão não constante de `InternetAddress.loopbackIPv4`.
- Os testes antigos que referenciavam `ApiServer` inexistente foram substituídos por casos compatíveis com o router atual.

Esses avanços não tornam todo o fluxo pronto: o servidor ainda não é iniciado por um entrypoint de backend; `PATCH`/`DELETE` não recebem o ID definido na rota; o login continua usando GET com corpo; a senha continua em texto puro; e não há conexão do repositório ao MySQL do Compose.

## Tabela atual de problemas

| # | Prioridade | Área / localização | Situação e efeito observado |
|---|---|---|---|
| 1 | Bloqueante | Inicialização: `lib/main.dart`, `bin/projeto_base_prisma.dart`, `loginAPI.dart` | Os entrypoints existentes não iniciam a API. `loginApi.main()` é método de instância, não é o `main()` global que o runtime Dart executa. |
| 2 | Alto | Inicialização: `loginAPI.dart:startApi` | O método exige receber um `Handler` de fora, embora registre as rotas em `router` próprio. Um handler diferente pode ser servido por engano; o método também não oferece um ciclo de encerramento/gerência do `HttpServer`. |
| 3 | Bloqueante | Rotas de mutação: `loginAPI.dart:router.patch`, `_atualizarUsuario`, `router.delete`, `_deletarUsuario` | As rotas contêm `<id>`, mas os handlers recebem apenas `Request` e leem JSON do corpo. O ID da URL não participa da operação; o contrato do router e a função handler não estão alinhados. |
| 4 | Alto | Login: `loginAPI.dart:/api/users/acesso`, `_enterSystem` | A operação de autenticação está registrada como GET, mas tenta ler e decodificar credenciais do corpo. Clientes HTTP e intermediários não tratam corpo de GET de forma interoperável. |
| 5 | Alto | Cadastro: `loginAPI.dart:_postLogin` | Tipo `tipo_usuario` inválido retorna 409, apesar de não ser conflito de recurso. CPF duplicado pode gerar exceção da restrição `UNIQUE`, e essa exceção não tem mapeamento claro para HTTP 409. |
| 6 | Alto | Validação de entrada: handlers de login, atualização e exclusão | Só o cadastro trata alguns erros de JSON. JSON vazio/malformado, campos ausentes, tipos incorretos e exceções do banco podem escapar como erro interno ou resposta inconsistente. |
| 7 | Alto | Autenticação: `gerenciadoBancoDeDados.dart:getUserByEmailAndPassword`, `database_helper_users.dart` | A senha é persistida em texto puro e comparada diretamente. O login responde apenas uma mensagem, sem estabelecer sessão/token que possa proteger operações seguintes. |
| 8 | Alto | Persistência/deploy: `sqflite`, `compose.yml`, entrypoints | O app abre SQLite com `sqflite`, mas o Compose configura MySQL; não há cliente MySQL no repositório. O Compose também aparenta ter `services` sob `volumes` e serviços/portas duplicados; não foi validado por `docker compose config`. |
| 9 | Alto | Atualização/exclusão: `gerenciadoBancoDeDados.dart:atualizacaoUsuario`, `deletarUser` | Os factories agora podem preservar `usuario_id`, mas as rotas ainda não usam o parâmetro `<id>`. A atualização localiza por e-mail antes de atualizar por ID; exclusão depende do ID presente no corpo. O fluxo continua frágil e não foi coberto por teste de banco. |
| 10 | Médio | Migrações: `database_helper_users.dart:version/onCreate` | Esquema na versão 1 sem `onUpgrade`. Alterações posteriores ao esquema não migram bancos instalados anteriormente. |
| 11 | Médio | Helper de arquivos: `database_helper_arquivos.dart` | Helper não referenciado no fluxo encontrado e caminho `join(getDatabasesPath(), '/var/lib/mysql')` não representa claramente um arquivo SQLite. |
| 12 | Médio | Upload: `fileControllAPI.dart:_uploadVideo` | O limite por arquivo de 100 MiB está implementado. Ainda não há limite total da requisição multipart; extensão declarada pelo cliente não comprova o conteúdo real; autenticação/autorização do upload não aparece no handler. |
| 13 | Médio | Streaming: `fileControllAPI.dart:_getVideo` | A expressão regular de Range aceita apenas parcialmente entradas e não deixa explícito o suporte a um único intervalo. Entradas malformadas, suffix ranges e limites do arquivo precisam de cobertura dedicada. |
| 14 | Alto | Testes de integração | Os testes agora compilam e passam para modelos/router sem banco. Ainda não existe teste de ponta a ponta para cadastro, login, consulta encontrada, atualização, exclusão ou migração; o repositório não é substituível nos testes atuais. |
| 15 | Baixo | Consistência e estilo | Nomes como `loginApi`/`fileControll`, caminhos de import com capitalização inconsistente e vários formatos de resposta dificultam manutenção e podem complicar portabilidade entre sistemas de arquivos. |

## Detalhamento e propostas de correção

As implementações abaixo são **sugestões para uma etapa futura**. Não foram aplicadas à produção nesta revisão.

### Problemas 1 e 2 — Inicialização explícita e handler correto

`loginApi.main()` só executa se alguém criar um objeto e invocar esse método. Não é o entrypoint global do Dart. Além disso, `startApi(handler: ...)` permite iniciar o servidor com um handler que não é `router.call`, mesmo tendo acabado de registrar rotas nesse router.

**Como corrigir:**

1. Deixar o objeto API responsável por construir seu handler e iniciar o servidor.
2. Tornar o método de inicialização retornável/aguardável e retornar o `HttpServer` ou guardar sua referência para que ele possa ser fechado.
3. Criar um `main()` de nível superior no entrypoint do backend (por exemplo, em `bin/`), instanciar a API e aguardá-la.
4. Não substituir o `main()` Flutter se o mesmo projeto também é um app Flutter; backend e aplicativo precisam de entrypoints separados.

Exemplo de estrutura:

```dart
class LoginApi {
  final Router router = Router();

  Handler buildHandler() {
    router.get('/api/test', _getTest);
    router.get('/api/users/info', _getUser);
    router.post('/api/users/cadastrar', _postCadastro);
    router.post('/api/users/acesso', _enterSystem);
    router.patch('/api/users/<id>', _atualizarUsuario);
    router.delete('/api/users/<id>', _deletarUsuario);

    return const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(router.call);
  }

  Future<HttpServer> start({
    InternetAddress? address,
    int port = 8080,
  }) {
    return shelf_io.serve(
      buildHandler(),
      address ?? InternetAddress.loopbackIPv4,
      port,
    );
  }
}
```

Entry point de backend separado:

```dart
Future<void> main() async {
  final api = LoginApi();
  final server = await api.start(
    address: InternetAddress.anyIPv4,
    port: 8080,
  );
  stdout.writeln(
    'API ouvindo em ${server.address.address}:${server.port}',
  );
}
```

Use `loopbackIPv4` se só a mesma máquina deve acessar. Use `anyIPv4` apenas quando outros dispositivos/contêineres precisam conectar; nesse caso, restrinja exposição com firewall/rede e autenticação. Para encerrar graciosamente, mantenha `server` e chame `await server.close(force: false)` no mecanismo de shutdown do processo.

### Problema 3 — Alinhar handlers de PATCH/DELETE com `<id>`

As rotas registram um parâmetro de caminho, mas os handlers atuais só aceitam `Request`. O parâmetro precisa ser recebido e usado como identidade do recurso. Não dependa de um `usuario_id` que o cliente pode esquecer ou enviar diferente no JSON.

**Como corrigir:**

1. Receber o `id` como segundo argumento do handler Shelf Router.
2. Remover a exigência de `tipo_usuario`/ID do corpo quando esses dados puderem ser obtidos do banco.
3. Criar operações de repositório explícitas por ID.
4. Fazer a atualização e o DELETE operarem com o mesmo ID que veio da URL.
5. Se o endpoint ainda precisar dos dados do tipo concreto, buscar primeiro o usuário existente e validar/mesclar os campos recebidos.

Exemplo de assinatura e chamada:

```dart
router.patch('/api/users/<id>', _atualizarUsuario);
router.delete('/api/users/<id>', _deletarUsuario);

Future<Response> _deletarUsuario(Request request, String id) async {
  final removidos = await gerenciador.deletarUserPorId(id);
  if (removidos == 0) {
    return _json(404, {'message': 'Usuário não encontrado'});
  }
  return Response(204);
}
```

Exemplo correspondente no repositório:

```dart
Future<int> deletarUserPorId(String id) async {
  final db = await DatabaseHelperUsers.instance.database;
  return db.delete(
    'Usuarios',
    where: 'usuario_id = ?',
    whereArgs: [id],
  );
}
```

Para PATCH, uma operação equivalente deve localizar primeiro o tipo e depois atualizar `Usuarios` e `Aluno`/`Professores` dentro da mesma transação. Não aceite uma troca arbitrária de tipo sem definir explicitamente como migrar a linha entre tabelas.

### Problema 4 — Enviar credenciais por POST

GET deve consultar recursos e não depender de corpo. Senha no corpo de GET também pode acabar em logs/comportamentos inesperados do cliente.

**Como corrigir:**

- Registrar `/api/users/acesso` como POST.
- Enviar JSON com `Content-Type: application/json`.
- Validar que o corpo é um objeto e contém strings não vazias para `email` e `senha`.
- Responder 401 com uma mensagem genérica para credenciais inválidas (não revelar se o e-mail existe).
- Se o login for bem-sucedido, emitir uma sessão/token com validade e usar middleware para proteger operações privadas.

Exemplo de chamada Flutter:

```dart
final response = await http.post(
  Uri.parse('$baseUrl/api/users/acesso'),
  headers: {'content-type': 'application/json'},
  body: jsonEncode({'email': email, 'senha': senha}),
);
```

E registro no router:

```dart
router.post('/api/users/acesso', _enterSystem);
```

### Problema 5 — Diferenciar erro de entrada, conflito e sucesso

`tipo_usuario` inválido não significa que o usuário já existe. E-mail duplicado e CPF duplicado são conflitos distintos da entrada inválida. A restrição do banco é a última proteção contra concorrência, então seu erro também precisa ser mapeado.

**Como corrigir:**

- 400 para JSON válido, mas campos ou tipo inválidos.
- 409 para e-mail/CPF já utilizados.
- 201 para criação.
- 500 para falha inesperada de persistência, com detalhe apenas no log interno.
- Manter `UNIQUE` no banco; não confiar apenas em consulta prévia, pois duas requisições simultâneas podem passar a consulta.

Exemplo de fluxo no handler:

```dart
final tipo = data['tipo_usuario'];
if (tipo != 'aluno' && tipo != 'professor') {
  return _json(400, {'message': 'tipo_usuario inválido'});
}

try {
  final criado = await gerenciador.insertUser(user);
  if (!criado) {
    return _json(409, {'message': 'Email ou CPF já cadastrado'});
  }
  return _json(201, {'message': 'Usuário criado'});
} on DatabaseException catch (error, stackTrace) {
  log('Falha ao cadastrar usuário', error: error, stackTrace: stackTrace);
  if (_isUniqueConstraint(error)) {
    return _json(409, {'message': 'Email ou CPF já cadastrado'});
  }
  return _json(500, {'message': 'Falha ao cadastrar usuário'});
}
```

`_isUniqueConstraint` deve ser implementado de acordo com o erro retornado pela versão/plataforma de SQLite usada; não classifique toda `DatabaseException` como duplicidade.

### Problema 6 — Centralizar validação de JSON e erros HTTP

Cadastro lida com `FormatException` e confirma que a raiz é um mapa, mas outros handlers fazem `jsonDecode(body) as Map<String, dynamic>` diretamente. Um corpo vazio, JSON malformado ou campo com tipo inesperado pode lançar exceção.

**Como corrigir:**

1. Ter um leitor comum que aceite apenas objeto JSON.
2. Verificar os campos antes de casts.
3. Diferenciar 400 de erros do banco (500).
4. Registrar exceções inesperadas internamente; nunca responder stack trace/SQL ao cliente.
5. Usar helper para todas as respostas JSON e assim padronizar o cabeçalho.

Exemplo do helper de resposta:

```dart
Response _json(int status, Object body) => Response(
  status,
  body: jsonEncode(body),
  headers: {'content-type': 'application/json; charset=utf-8'},
);
```

Exemplo de validação de campos:

```dart
String? _requiredString(Map<String, dynamic> data, String key) {
  final value = data[key];
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

final email = _requiredString(data, 'email');
final senha = _requiredString(data, 'senha');
if (email == null || senha == null) {
  return _json(400, {'message': 'email e senha são obrigatórios'});
}
```

O helper de parse pode retornar um resultado tipado (por exemplo, uma classe `JsonBodyResult`) para diferenciar JSON inválido, raiz não objeto e objeto válido sem usar exceções como fluxo normal.

### Problema 7 — Armazenar hashes de senha e autenticar operações

O banco atual armazena a senha literal. Um backup, dump, dispositivo perdido ou acesso ao arquivo SQLite expõe as senhas. Comparar `email` e `senha` diretamente não é adequado para um sistema que deveria estar em uso real.

**Como corrigir:**

1. Escolher biblioteca mantida de hashing de senha compatível com o backend e a plataforma.
2. No cadastro, gerar hash com salt e custo adequado; gravar somente o hash.
3. No login, buscar o usuário pelo e-mail e verificar a senha recebida contra o hash.
4. Remover senha/hash de DTOs, logs e respostas.
5. Depois da validação, emitir token/sessão assinado ou persistido, com expiração/revogação; proteger update/delete e dados privados com middleware.
6. Planejar migração das senhas existentes: hashes não são reversíveis, então usuários com senha em texto puro precisam redefini-la ou passar por uma migração controlada.

Pseudocódigo (API exata depende da biblioteca escolhida):

```dart
final hash = await passwordHasher.hash(senhaRecebida);
await repositorio.criarUsuario(passwordHash: hash);

final user = await repositorio.buscarPorEmail(email);
if (user == null ||
    !await passwordHasher.verify(senhaRecebida, user.passwordHash)) {
  return _json(401, {'message': 'Credenciais inválidas'});
}

final token = await tokenService.issue(user.id);
return _json(200, {'access_token': token});
```

### Problema 8 — Decidir entre SQLite local e banco servidor

`DatabaseHelperUsers` usa `sqflite`; subir o serviço MySQL no Compose não altera essa conexão. Também não há driver MySQL no `pubspec.yaml`.

**Decisão necessária antes de produção:**

- Se o backend roda dentro do app Flutter em cada dispositivo, SQLite pode ser o armazenamento local do dispositivo. O Compose MySQL não é usado nesse desenho.
- Se existe um backend Dart central que atende vários clientes, usar MySQL/PostgreSQL com driver adequado e configuração por ambiente; `sqflite` não deve ser a conexão do servidor compartilhado.

Se a decisão for MySQL, o desenho do código é:

```dart
abstract interface class UserRepository {
  Future<User?> findByEmail(String email);
  Future<int> insert(User user);
  Future<int> deleteById(String id);
}

class MysqlUserRepository implements UserRepository {
  MysqlUserRepository(this.pool);
  final ConnectionPool pool;

  // Implementar operações parametrizadas e transacionais
  // usando a biblioteca MySQL escolhida.
}
```

Injete `UserRepository` no handler, em vez de instanciar o helper diretamente. Isso permite usar implementação MySQL na aplicação e fake/in-memory nos testes de handler.

O `compose.yml` deve ter `services:` e `volumes:` no topo, configurar credenciais por secrets/variáveis de ambiente e evitar expor portas desnecessárias. Depois de ajustado, verificar com `docker compose config` e `docker compose up --wait`.

### Problema 9 — Concluir o uso consistente do ID

O `usuario_id` agora é lido pelos factories quando fornecido. Isso corrige a perda do ID na conversão JSON→modelo, mas o modelo ainda pode gerar UUID novo quando a chave não veio. A rota de mutação tem ID na URL e precisa garantir que esse ID, e não um ID opcional do corpo, é o usado na operação.

**Como corrigir:**

- Cadastro: o servidor gera ID e o frontend não escolhe.
- Consulta: responder o ID persistido junto com campos públicos.
- Atualização/exclusão: usar exclusivamente o ID da URL.
- Testes: cadastrar usuário com ID conhecido no repositório fake, atualizar e excluir esse mesmo ID; testar 404 quando ausente.

Exemplo de verificação contra discrepância:

```dart
final userId = pathId;
final existing = await repository.findById(userId);
if (existing == null) return _json(404, {'message': 'Não encontrado'});

final updated = requestData.toUpdatedUser(id: existing.id);
await repository.update(updated);
```

Assim, não é necessário confiar em `usuario_id` enviado pelo cliente em um body de atualização.

### Problema 10 — Criar migrações explícitas

Manter `version: 1` sem `onUpgrade` é aceitável apenas enquanto o esquema permanece igual. Quando houver alteração, o banco já criado não executará `onCreate` novamente.

**Como corrigir:**

1. Incrementar a versão do banco.
2. Adicionar migração incremental para cada versão anterior.
3. Fazer cada migração transacional e idempotente quando possível.
4. Testar banco vazio e upgrade de cada versão ainda suportada.

Exemplo ilustrativo:

```dart
return openDatabase(
  path,
  version: 2,
  onCreate: _createSchemaV2,
  onUpgrade: (db, oldVersion, newVersion) async {
    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE Usuarios ADD COLUMN password_hash TEXT',
      );
    }
  },
);
```

Não adicione coluna de hash sem planejar a migração/recadastro das senhas existentes.

### Problema 11 — Corrigir o helper de arquivos ou removê-lo

Nenhum consumidor do helper foi encontrado, e `'/var/lib/mysql'` parece um diretório de dados de MySQL, não o nome pretendido de um arquivo SQLite. Se essa tabela deve ser SQLite local, use um nome de arquivo:

```dart
final path = join(await getDatabasesPath(), 'arquivos.db');
```

Se pretendia armazenar metadados no MySQL, não abra `sqflite` nesse caminho: implemente a tabela no banco servidor e acesse via repositório. Remova o helper se ele não fizer parte do produto para não sugerir falsamente que uploads estão indexados no banco.

### Problema 12 — Ampliar controles de upload sem desfazer o limite existente

O limite atual conta os bytes da parte de arquivo selecionada e interrompe quando passa de 100 MiB. Isso protege o arquivo gravado, mas não estabelece sozinho um limite para o corpo multipart completo ou campos adicionais ignorados.

**Como corrigir:**

1. Manter a contagem por stream (não ler o upload inteiro para memória).
2. Configurar também um limite de tamanho da requisição no servidor/proxy, para cobrir overhead multipart e outras partes.
3. Rejeitar campos inesperados ou impor limite individual para campos de formulário.
4. Validar o conteúdo real do arquivo quando o risco justificar; extensão/MIME enviados pelo cliente são apenas declarações.
5. Aplicar autenticação/autorização se os vídeos não forem públicos; proteger também GET/DELETE.
6. Usar arquivo temporário e renomear atomicamente após upload completo, mantendo limpeza em toda falha.
7. Testar exatamente 100 MiB (aceito), 100 MiB + 1 byte (413), arquivo parcial removido e stream abortado.

O padrão de contagem incremental pode continuar assim:

```dart
Stream<List<int>> limitSize(Stream<List<int>> source, int maxBytes) async* {
  var total = 0;
  await for (final chunk in source) {
    total += chunk.length;
    if (total > maxBytes) throw UploadTooLarge();
    yield chunk;
  }
}
```

Para limitar o corpo todo, a contagem precisa envolver o stream HTTP antes do parser multipart, não apenas `formData.part`. Se houver proxy reverso, configure limite equivalente nele e mantenha validação no aplicativo.

### Problema 13 — Validar ranges HTTP completos

O streaming por intervalo é importante para reprodução/seeking, mas o parser atual usa `firstMatch`, o que pode aceitar um prefixo e ignorar lixo ou segundo intervalo. A resposta precisa ser 416 para intervalos malformados/fora do arquivo e 206 somente para intervalo válido suportado.

**Como corrigir:**

- Declarar que apenas um intervalo `bytes=start-end` ou `bytes=-suffix` é suportado.
- Usar correspondência completa (`matchAsPrefix` com validação de que consumiu o cabeçalho inteiro, ou regex ancorada).
- Rejeitar múltiplos ranges se não forem implementados.
- Cobrir arquivo vazio, `start >= tamanho`, `end < start`, `end > tamanho`, suffix maior que arquivo e suffix igual a zero.
- Não chamar `int.parse` antes de confirmar que os grupos contêm somente dígitos.

Exemplo de regra para a expressão:

```dart
final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header);
if (match == null || (match[1]!.isEmpty && match[2]!.isEmpty)) {
  return Response(416, headers: {'content-range': 'bytes */$size'});
}
```

Após parse, valide os limites antes de abrir o stream. Não transforme automaticamente `start < 0` em zero para uma entrada já considerada inválida; responda 416 conforme o formato HTTP.

### Problema 14 — Expandir testes com repositório substituível

Os testes antigos tentavam instanciar `ApiServer`, inexistente, e usavam rotas removidas. Agora a suíte testa:

- `Aluno`/`Professor` a partir de JSON, incluindo preservação do ID e estrutura de `toMap`;
- `/api/test`;
- validações de query/body que retornam antes de acessar o banco;
- rota inexistente.

Ela não prova que SQLite cria o esquema ou que cadastro/login/update/delete funcionam de ponta a ponta. Para isso, primeiro injete um repositório abstrato nos handlers:

```dart
abstract interface class UserRepository {
  Future<User?> findByEmail(String email);
  Future<User?> findById(String id);
  Future<bool> verifyCredentials(String email, String password);
  Future<int> insert(User user);
  Future<int> update(User user);
  Future<int> deleteById(String id);
}
```

No teste, um `FakeUserRepository` guarda usuários em memória. O handler recebe essa interface pelo construtor, e os testes chamam `router.call` sem abrir conexão SQLite. Depois, crie testes de integração separados para `DatabaseHelperUsers` em uma plataforma SQLite suportada, verificando:

1. criação limpa das três tabelas;
2. chave estrangeira e exclusão em cascata;
3. cadastro de aluno e professor dentro de transação;
4. duplicidade de e-mail e CPF;
5. busca de cada tipo e retorno `null`;
6. atualização e exclusão pelo ID persistido;
7. upgrade de cada versão do esquema.

Para uploads, exponha uma factory de router/handler testável com diretório temporário e injeção do limite/pasta ou extraia o limitador para uma função pública de biblioteca própria. Não teste apenas a função auxiliar: teste também o status 413 e a inexistência do arquivo parcial no endpoint.

### Problema 15 — Padronização e manutenção

Quando os fluxos funcionais estiverem cobertos, renomeie tipos/arquivos para convenção Dart (`LoginApi`, `FileController`, `login_api.dart`, `file_controller_api.dart`) e normalize imports. Faça essa alteração em uma mudança dedicada, pois afeta imports do app e testes.

Padronize respostas com `_json(status, body)`, não envie senha/CPF desnecessariamente e use códigos coerentes:

- 200 para consulta/login que retorna conteúdo;
- 201 para criação;
- 204 para update/delete sem corpo;
- 400 para entrada inválida;
- 401 para credenciais inválidas;
- 404 para recurso ausente;
- 409 para restrição/duplicidade;
- 413 para upload acima do limite;
- 415 para tipo/formato não aceito;
- 500 para falha inesperada.

## Testes atualizados

O arquivo `test/backend_contract_test.dart` foi atualizado para refletir rotas e modelos atuais e não depender de `ApiServer`. Ele sobe o router em porta efêmera e fecha o servidor ao fim. Os testes que exigiriam SQLite foram intencionalmente excluídos até existir injeção de repositório ou configuração de banco de teste.

## Verificações executadas

- `flutter test`: **9 testes passaram**.
- `flutter analyze test/backend_contract_test.dart`: **nenhum problema**.
- `flutter analyze`: **nenhum erro**, mas reporta 21 avisos/informações de estilo e convenções em arquivos existentes.
- O teste fecha o `HttpServer` ao fim, evitando deixar a porta aberta.
- Não foi feito `hot restart`: não há aplicativo Flutter conectado, e a alteração é apenas de testes/relatório.
