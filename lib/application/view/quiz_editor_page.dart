import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projeto_base_prisma/application/theme/app_theme.dart';
import 'package:projeto_base_prisma/application/view/api_response.dart';

class QuizEditorPage extends StatefulWidget {
  const QuizEditorPage({
    super.key,
    required this.accessToken,
    required this.quizId,
  });

  final String accessToken;
  final int quizId;

  @override
  State<QuizEditorPage> createState() => _QuizEditorPageState();
}

class _QuizEditorPageState extends State<QuizEditorPage> {
  static const _quizBaseUrl = 'http://localhost:8080/api/quiz/quizzes';

  final List<_QuestionEditor> _questions = [];
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasUnsavedChanges = false;
  String _title = 'Quiz';
  String _videoTitle = '';
  String _status = 'draft';
  String? _loadError;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${widget.accessToken}',
    'Content-Type': 'application/json',
  };

  @override
  void initState() {
    super.initState();
    unawaited(_loadQuiz());
  }

  @override
  void dispose() {
    for (final question in _questions) {
      question.dispose();
    }
    super.dispose();
  }

  Future<void> _loadQuiz() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final response = await http
          .get(Uri.parse('$_quizBaseUrl/${widget.quizId}'), headers: _headers)
          .timeout(const Duration(seconds: 20));
      final data = decodeApiResponseObject(
        response.body,
        statusCode: response.statusCode,
        fallbackMessage: 'Não foi possível carregar o quiz.',
      );
      final rawQuestions = data['questoes'];
      if (rawQuestions is! List) {
        throw Exception('A API retornou questões inválidas.');
      }

      final questions = <_QuestionEditor>[];
      for (final rawQuestion
          in rawQuestions.whereType<Map<String, dynamic>>()) {
        final rawAlternatives = rawQuestion['alternativas'];
        if (rawAlternatives is! List ||
            rawAlternatives.any((alternative) => alternative is! String)) {
          throw Exception('A API retornou alternativas inválidas.');
        }
        final storedAlternatives = rawAlternatives.cast<String>();
        final alternatives = storedAlternatives.length < 2
            ? List<String>.filled(4, '')
            : storedAlternatives;
        final correctAnswer = rawQuestion['resposta_correta'];
        final correctIndex = correctAnswer is String
            ? alternatives.indexOf(correctAnswer)
            : -1;
        questions.add(
          _QuestionEditor(
            enunciado: rawQuestion['enunciado'] as String? ?? '',
            alternativas: alternatives,
            correctIndex: correctIndex < 0 ? 0 : correctIndex,
          ),
        );
      }

      if (!mounted) return;
      setState(() {
        _title = data['titulo'] as String? ?? 'Quiz';
        _videoTitle =
            data['video_titulo'] as String? ??
            data['video_id'] as String? ??
            '';
        _status = data['status'] as String? ?? 'draft';
        _questions.addAll(questions);
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _loadError = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addQuestion() {
    setState(() {
      _questions.add(_QuestionEditor());
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _confirmRemoveQuestion(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remover questão?'),
        content: const Text(
          'A questão será removida quando você salvar o quiz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _questions.removeAt(index).dispose();
      _hasUnsavedChanges = true;
    });
  }

  Future<void> _confirmDiscardChanges() async {
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Descartar alterações?'),
        content: const Text(
          'As alterações que ainda não foram salvas serão perdidas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continuar editando'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard != true || !mounted) return;
    setState(() => _hasUnsavedChanges = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop(false);
    });
  }

  Future<bool> _saveDraft({bool showSuccess = true}) async {
    if (_isSaving) return false;
    setState(() => _isSaving = true);
    try {
      final response = await http
          .put(
            Uri.parse('$_quizBaseUrl/${widget.quizId}'),
            headers: _headers,
            body: _encodeQuestions(),
          )
          .timeout(const Duration(seconds: 20));
      decodeApiResponseObject(
        response.body,
        statusCode: response.statusCode,
        fallbackMessage: 'Não foi possível salvar o quiz.',
      );
      if (!mounted) return false;
      final wasPublished = _status == 'published';
      setState(() {
        _status = 'draft';
        _hasUnsavedChanges = false;
      });
      if (showSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              wasPublished
                  ? 'Alterações salvas como rascunho. Publique novamente para os alunos.'
                  : 'Rascunho salvo.',
            ),
          ),
        );
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível salvar: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _publish() async {
    if (!await _saveDraft(showSuccess: false) || !mounted) return;
    setState(() => _isSaving = true);
    try {
      final response = await http
          .post(
            Uri.parse('$_quizBaseUrl/${widget.quizId}/publicar'),
            headers: _headers,
          )
          .timeout(const Duration(seconds: 20));
      decodeApiResponseObject(
        response.body,
        statusCode: response.statusCode,
        fallbackMessage: 'Não foi possível publicar o quiz.',
      );
      if (!mounted) return;
      setState(() => _status = 'published');
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Quiz publicado.')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível publicar: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _encodeQuestions() {
    final questions = [
      for (final question in _questions)
        {
          'enunciado': question.enunciado.text,
          'alternativas': [
            for (final alternative in question.alternativas) alternative.text,
          ],
          'resposta_correta':
              question.alternativas.isEmpty ||
                  question.correctIndex >= question.alternativas.length
              ? ''
              : question.alternativas[question.correctIndex].text,
        },
    ];
    return jsonEncode({'questoes': questions});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _hasUnsavedChanges) {
          unawaited(_confirmDiscardChanges());
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('EDITAR QUIZ')),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.navy),
              )
            : _loadError != null
            ? _LoadError(message: _loadError!, onRetry: _loadQuiz)
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          child: ListTile(
                            title: Text(
                              _title,
                              style: const TextStyle(
                                color: AppTheme.navy,
                                fontFamily: AppTheme.displayFontFamily,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              _videoTitle.startsWith('legado:')
                                  ? 'Perguntas importadas do quiz anterior'
                                  : 'Videoaula: $_videoTitle',
                            ),
                            trailing: Chip(
                              label: Text(
                                _status == 'published'
                                    ? 'Publicado'
                                    : 'Rascunho',
                              ),
                            ),
                          ),
                        ),
                        if (_status == 'published')
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'Salvar alterações tira o quiz do ar até publicá-lo novamente.',
                              style: TextStyle(color: Colors.black87),
                            ),
                          ),
                        for (var index = 0; index < _questions.length; index++)
                          _buildQuestionCard(index),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _addQuestion,
                          icon: const Icon(Icons.add),
                          label: const Text('Adicionar questão'),
                        ),
                      ],
                    ),
                  ),
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSaving ? null : () => _saveDraft(),
                              child: const Text('Salvar rascunho'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: _isSaving ? null : _publish,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.green,
                              ),
                              child: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Publicar'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildQuestionCard(int index) {
    final question = _questions[index];
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Questão ${index + 1}',
                    style: const TextStyle(
                      color: AppTheme.navy,
                      fontFamily: AppTheme.displayFontFamily,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _isSaving
                      ? null
                      : () => _confirmRemoveQuestion(index),
                  tooltip: 'Remover questão',
                  icon: const Icon(
                    Icons.remove_circle_outline,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
            TextField(
              controller: question.enunciado,
              onChanged: (_) => setState(() => _hasUnsavedChanges = true),
              readOnly: _isSaving,
              decoration: const InputDecoration(labelText: 'Enunciado'),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            RadioGroup<int>(
              groupValue: question.correctIndex,
              onChanged: (value) {
                if (_isSaving || value == null) return;
                setState(() {
                  question.correctIndex = value;
                  _hasUnsavedChanges = true;
                });
              },
              child: Column(
                children: [
                  for (
                    var optionIndex = 0;
                    optionIndex < question.alternativas.length;
                    optionIndex++
                  ) ...[
                    if (optionIndex > 0) const SizedBox(height: 12),
                    Row(
                      children: [
                        Radio<int>(value: optionIndex),
                        Expanded(
                          child: TextField(
                            controller: question.alternativas[optionIndex],
                            onChanged: (_) =>
                                setState(() => _hasUnsavedChanges = true),
                            readOnly: _isSaving,
                            decoration: InputDecoration(
                              labelText: 'Alternativa ${optionIndex + 1}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Text(
              'Selecione o botão ao lado da resposta correta.',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuestionEditor {
  _QuestionEditor({
    String enunciado = '',
    List<String> alternativas = const ['', '', '', ''],
    this.correctIndex = 0,
  }) : enunciado = TextEditingController(text: enunciado),
       alternativas = [
         for (final alternative in alternativas)
           TextEditingController(text: alternative),
       ];

  final TextEditingController enunciado;
  final List<TextEditingController> alternativas;
  int correctIndex;

  void dispose() {
    enunciado.dispose();
    for (final alternative in alternativas) {
      alternative.dispose();
    }
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onRetry,
            child: const Text('Tentar novamente'),
          ),
        ],
      ),
    ),
  );
}
