# Revisão final: APIs, autenticação e persistência

## Resultado

Os defeitos funcionais encontrados na API foram corrigidos nos arquivos ativos. A suíte cobre os handlers Shelf com repositório fake, hashing, autorização, upload, limite de tamanho e `Range`; **13 testes passaram** em `flutter test`.

O snapshot da implementação anterior está em `backup/current_source_20261107_1804.zip`. Ele foi criado antes das alterações funcionais e da inclusão do pacote `bcrypt`, portanto contém os fontes e a configuração de dependências anteriores, sem misturá-los às correções.

## Correções aplicadas

| Área | Defeito | Correção feita |
|---|---|---|
| Cadastro | O resultado de `package:path.hash` era confundido com hash de senha; o objeto de usuário ficava nulo por sombreamento; o mapa persistia `senha: null`. | `PasswordHasher` usa BCrypt com salt e custo 12 em isolate. A API valida a requisição, cria o modelo uma vez e entrega o hash separadamente ao repositório. Modelos e DTOs não carregam nem serializam senha. |
| Login | A consulta tentava comparar senha literal no SQL, o que não funciona com BCrypt. | O repositório busca a credencial pelo e-mail e o serviço verifica o BCrypt. Para contas antigas com senha em texto claro, o primeiro login válido troca a senha armazenada por BCrypt. |
| Respostas HTTP | Algumas respostas passavam `Map` como `Response.body`, e o endpoint de ID podia devolver texto que não era JSON. | A API centraliza respostas JSON com `jsonEncode`, devolve códigos HTTP coerentes e trata JSON inválido/campos ausentes como 400. Exceções inesperadas são registradas e respondem 500 sem expor stack trace ao cliente. |
| Dados pessoais | Rotas de consulta, atualização e exclusão não exigiam autenticação nem limitavam a conta consultada. | Login cria token Bearer aleatório, válido por oito horas. Consulta, ID, atualização e exclusão exigem token; leitura e mutação só permitem o usuário dono do token. A resposta de perfil não expõe CPF nem credencial. Excluir a conta revoga suas sessões. |
| Atualização SQLite | A consulta usava `Usuarios.id`; atualizações de perfil filtravam pela coluna errada e podiam deixar tabelas inconsistentes. | A operação passou a ser transacional, usa `Usuarios.usuario_id` e a chave `id` da tabela de perfil, verifica as linhas necessárias antes de alterar e mantém a senha fora do mapa de atualização. |
| Upload | O controlador não era iniciado junto com a API de usuários; rotas de arquivo não tinham autenticação; uploads acima do limite podiam deixar parcial no disco. | O entrypoint Flutter inicia os servidores nas portas 8080 e 8081 com a mesma sessão. Upload, leitura e exclusão de vídeo exigem Bearer token. O limite padrão segue em 100 MiB por arquivo, com gravação em streaming e remoção do parcial ao exceder o tamanho. |
| Arquivos por usuário | Um usuário autenticado poderia tentar acessar ou excluir arquivo de outro usuário, e um mapa em memória perderia a propriedade dos arquivos ao reiniciar. | Arquivos são armazenados em diretório derivado do ID do usuário autenticado. Esse isolamento não depende de mapa em memória e persiste após reinicialização. O nome físico é UUID, não o nome fornecido pelo cliente. |
| `Range` | O parser aceitava prefixos de ranges e não tratava corretamente entradas inválidas. | A expressão valida o header completo; ranges inválidos, múltiplos ou fora do arquivo retornam 416. São tratados ranges comuns e suffix ranges. |
| Inicialização e tela de teste | O projeto não tinha `lib/main.dart`, só iniciava a API de usuário e a tela consultava `/api/users`, rota inexistente. | `lib/main.dart` inicia os dois servidores e a aplicação Flutter. A tela de teste consome o endpoint público `/api/test`, que retorna o formato de dados que ela desserializa. |

## Contratos das rotas

### Usuários — `http://<host>:8080`

| Método e rota | Acesso | Resultado |
|---|---|---|
| `GET /api/test` | Público | Lista estática usada apenas pela tela de teste. |
| `POST /api/users/cadastrar` | Público | Cadastra aluno ou professor. Exige `tipo_usuario`, `nome`, `email`, `cpf`, `escola`, `senha` e os campos de perfil. Senha mínima de 8 caracteres; CPF deve conter 11 dígitos. Retorna 201, 400 ou 409. |
| `POST /api/users/acesso` | Público | Recebe `email` e `senha`; retorna `access_token`, `token_type` e `expires_in`, ou 401 para credenciais inválidas. |
| `POST /api/users/logout` | Bearer | Revoga o token enviado. |
| `GET /api/users/info?email=...` | Bearer | Retorna os dados não secretos do usuário autenticado. Um token não pode consultar outro e-mail. |
| `GET /api/users/id?email=...` | Bearer | Retorna o ID apenas quando o e-mail pertence ao titular do token. |
| `PATCH /api/users/<id>` | Bearer | Atualiza os dados completos do titular, sem alterar a senha. |
| `DELETE /api/users/<id>` | Bearer | Exclui apenas o titular, revoga suas sessões e apaga os arquivos de vídeo associados. |

Envie JSON com `Content-Type: application/json`. Para as rotas privadas, inclua:

```http
Authorization: Bearer <access_token>
```

Exemplo de cadastro de aluno:

```json
{
  "tipo_usuario": "aluno",
  "nome": "Nome do aluno",
  "email": "aluno@example.com",
  "cpf": "12345678901",
  "escola": "Escola",
  "serie": "3 ano",
  "senha": "uma-senha-segura"
}
```

Para professor, substitua `serie` por `materia` e `licenciatura`.

### Arquivos — `http://<host>:8081`

| Método e rota | Acesso | Resultado |
|---|---|---|
| `POST /api/upload` | Bearer | Recebe `multipart/form-data`; o campo do arquivo pode chamar-se `video`, `file` ou `arquivo`. Extensões aceitas: MP4, MOV, AVI, MKV e WEBM. |
| `GET /api/video/<nome>` | Bearer do proprietário | Transmite o arquivo, inclusive com suporte a `Range: bytes=início-fim`. |
| `DELETE /api/video/<nome>` | Bearer do proprietário | Remove o arquivo. |

## Hash e transição de dados antigos

O hash BCrypt é salvo na coluna `Usuarios.senha` para manter compatibilidade com bancos locais existentes; mudar o nome/forma da coluna exigiria uma migração SQLite. O banco atual pode conter senhas antigas em texto claro se alguma instalação tiver sido preenchida manualmente. A compatibilidade converte cada credencial antiga no primeiro login bem-sucedido, mas **não protege as contas antigas que ainda não fizeram login**. Antes de distribuir uma instalação com dados existentes, faça backup e uma migração controlada de todos os registros antigos; não exporte nem registre senhas em logs.

O custo BCrypt 12 é calculado fora do isolate principal da UI. A dependência foi adicionada ao `pubspec.yaml` e resolvida pelo Pub.

## Pendências para uma implantação real

As correções tornam os fluxos locais coerentes, mas não eliminam decisões de implantação:

1. **Sessões em memória:** tokens são perdidos ao reiniciar e não funcionam entre várias instâncias. Para backend distribuído, use sessão persistente ou JWT com expiração, renovação e revogação. O token atual deve ser enviado somente por HTTPS fora de um ambiente local confiável.
2. **SQLite via `sqflite`:** o banco é local ao app Flutter; não é uma base central apropriada para vários clientes remotos. Para serviço de produção multiusuário, hospede a API e use um banco servidor com migrações e backups.
3. **Arquivos órfãos:** os arquivos ficam isolados por usuário e sobrevivem ao reinício, mas excluir a conta não apaga o diretório físico do usuário. Configure uma rotina de retenção/limpeza ou conecte exclusão de arquivos ao fluxo administrativo.
4. **Endpoint `/api/test`:** é conteúdo estático de demonstração, não uma listagem de usuários. Remova-o ou mantenha-o apenas em builds de desenvolvimento se não for mais necessário.
5. **Servidores e plataformas:** o entrypoint inicia Shelf em `anyIPv4` nas portas fixas 8080 e 8081; portas ocupadas ou bloqueios de rede precisam ser configurados no ambiente. `sqflite` também requer o plugin da plataforma Flutter; o código não é um servidor Dart CLI autônomo.
6. **Sem testes com SQLite real:** os contratos HTTP usam repositório fake para serem determinísticos e independentes do plugin nativo. A transação, constraints e migração de dados precisam também ser testadas em ambiente Flutter com o SQLite de cada plataforma antes de produção.

## Validação

- `flutter test`: **15 testes passaram**; inclui cadastro/login, hash BCrypt e rehash legado, logout, respostas, isolamento por usuário, exclusão/revogação/limpeza, upload com limite, ranges e isolamento de arquivos.
- `flutter analyze`: sem erros nem warnings; restam apenas 6 diagnósticos `info` de convenção de nomes em arquivos existentes: `Aluno.dart`, `Professor.dart`, `User.dart`, `TelasTeste.dart`, `gerenciadoBancoDeDados.dart` e `classePrincipal.dart`.
- Hot restart foi tentado, mas não havia app conectado ao Dart Tooling Daemon. A tentativa de iniciar em Windows também revelou que este pacote ainda não tem plataforma Windows configurada; não foram gerados diretórios de plataforma nem adicionadas dependências de plataforma apenas para habilitar o hot restart.
