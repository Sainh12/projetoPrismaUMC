import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projeto_base_prisma/application/theme/app_theme.dart';
import 'package:projeto_base_prisma/application/view/api_response.dart';
import 'package:projeto_base_prisma/application/view/file_picker_registration_stub.dart'
    if (dart.library.js_interop) 'package:projeto_base_prisma/application/view/file_picker_registration_web.dart'
    as file_picker_registration;
import 'package:projeto_base_prisma/domain/video_resumo.dart';

class CadastroVideoPage extends StatefulWidget {
  const CadastroVideoPage({super.key, required this.accessToken});

  final String accessToken;

  @override
  State<CadastroVideoPage> createState() => _CadastroVideoPageState();
}

class _CadastroVideoPageState extends State<CadastroVideoPage> {
  static const _uploadUrl = 'http://localhost:8081/api/upload';
  static const _maxUploadBytes = 100 * 1024 * 1024;

  final _titleController = TextEditingController();
  PlatformFile? _selectedFile;
  bool _isPicking = false;
  bool _isUploading = false;

  Future<void> _pickVideo() async {
    setState(() => _isPicking = true);
    try {
      file_picker_registration.registerFilePickerForWeb();
      final files = await FilePicker.pickFiles(type: FileType.video);
      if (files.isEmpty) return;

      final file = files.single;
      final size = await file.length();
      if (size == null || size == 0) {
        throw Exception('Não foi possível ler o arquivo selecionado.');
      }
      if (size > _maxUploadBytes) {
        throw Exception('O vídeo deve ter no máximo 100 MiB.');
      }
      if (!mounted) return;
      setState(() => _selectedFile = file);
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  Future<void> _uploadVideo() async {
    final file = _selectedFile;
    final title = _titleController.text.trim();
    if (file == null || title.isEmpty) return;

    setState(() => _isUploading = true);
    try {
      final size = await file.length();
      if (size == null || size == 0) {
        throw Exception('Não foi possível ler o arquivo selecionado.');
      }
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl))
        ..headers['Authorization'] = 'Bearer ${widget.accessToken}'
        ..fields['title'] = title
        ..files.add(
          http.MultipartFile(
            'video',
            file.readAsByteStream(),
            size,
            filename: file.name,
          ),
        );
      final streamedResponse = await request.send().timeout(
        const Duration(minutes: 5),
      );
      final body = await streamedResponse.stream.bytesToString();
      final data = decodeApiResponseObject(
        body,
        statusCode: streamedResponse.statusCode,
        fallbackMessage: 'Não foi possível publicar o vídeo.',
      );

      final video = VideoResumo.fromJson(data);
      if (!mounted) return;
      Navigator.of(context).pop(video);
    } catch (error) {
      if (!mounted) return;
      _showError(error);
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Falha ao publicar: $message')));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            Container(
              height: 80,
              width: double.infinity,
              color: AppTheme.navy,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _isUploading
                        ? null
                        : () => Navigator.of(context).pop(),
                    tooltip: 'Voltar',
                    color: Colors.white,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'NOVA AULA',
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: AppTheme.displayFontFamily,
                      fontSize: 26,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 42, 20, 32),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'ADICIONAR NOVA VIDEOAULA',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontFamily: AppTheme.displayFontFamily,
                            fontSize: 34,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 48),
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                _selectedFile == null
                                    ? Icons.video_library_outlined
                                    : Icons.check_circle_outline,
                                size: 52,
                                color: AppTheme.navy,
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _selectedFile?.name ?? 'Clique aqui para anexar uma nova videoaula',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                height: 48,
                                child: OutlinedButton.icon(
                                  onPressed: _isPicking || _isUploading
                                      ? null
                                      : _pickVideo,
                                  icon: _isPicking
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(Icons.attach_file),
                                  label: Text(
                                    _isPicking
                                        ? 'Selecionando...'
                                        : 'Escolher vídeo',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextField(
                          controller: _titleController,
                          enabled: !_isUploading,
                          maxLength: 120,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: const InputDecoration(
                            labelText: 'Título da videoaula',
                            hintText: 'Ex.: Introdução à álgebra',
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 53,
                          child: FilledButton(
                            onPressed:
                                _selectedFile == null ||
                                    _titleController.text.trim().isEmpty ||
                                    _isPicking ||
                                    _isUploading
                                ? null
                                : _uploadVideo,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.green,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: _isUploading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Anexar',
                                    style: TextStyle(fontSize: 20),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
