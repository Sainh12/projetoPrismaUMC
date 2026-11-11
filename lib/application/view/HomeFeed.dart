import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:projeto_base_prisma/application/view/CadastroVideoPage.dart';
import 'package:projeto_base_prisma/application/view/PerfilPage.dart';
import 'package:projeto_base_prisma/application/view/video_source_stub.dart'
    if (dart.library.js_interop) 'package:projeto_base_prisma/application/view/video_source_web.dart'
    as video_source;
import 'package:projeto_base_prisma/application/view/api_response.dart';
import 'package:video_player/video_player.dart';

class HomeFeedPage extends StatefulWidget {
  const HomeFeedPage({
    super.key,
    required this.accessToken,
    required this.profile,
    required this.onLoggedOut,
  });

  final String accessToken;
  final Map<String, dynamic> profile;
  final VoidCallback onLoggedOut;

  @override
  State<HomeFeedPage> createState() => _HomeFeedPageState();
}

class _HomeFeedPageState extends State<HomeFeedPage> {
  int _selectedTab = 0;
  late Map<String, dynamic> _profile;
  List<String> _videos = [];
  List<String> _myVideos = [];
  bool _isLoadingVideos = true;
  bool _isLoadingMyVideos = false;
  bool _isRedirectingForExpiredSession = false;
  final Set<String> _deletingVideos = {};
  String? _videoLoadError;
  String? _myVideoLoadError;

  static const _videosUrl = 'http://localhost:8081/api/videos';
  static const _myVideosUrl = 'http://localhost:8081/api/my-videos';
  static const _videoUrl = 'http://localhost:8081/api/video';

  static const _titles = ['AULAS PARA VOCÊ', 'QUIZ', 'PERFIL', 'SEUS VÍDEOS'];

  @override
  void initState() {
    super.initState();
    _profile = Map<String, dynamic>.from(widget.profile);
    unawaited(_loadVideos());
    if (_isProfessor) unawaited(_loadMyVideos());
  }

  bool get _isProfessor => _profile['tipo_usuario'] == 'professor';

  void _updateProfile(Map<String, dynamic> profile) {
    setState(() => _profile = profile);
  }

  bool _handleUnauthorized(http.Response response) {
    if (response.statusCode != 401) return false;
    if (!_isRedirectingForExpiredSession) {
      _isRedirectingForExpiredSession = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sua sessão expirou. Entre novamente para continuar.'),
        ),
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onLoggedOut();
      });
    }
    return true;
  }

  Future<void> _loadVideos() async {
    setState(() {
      _isLoadingVideos = true;
      _videoLoadError = null;
    });
    try {
      final response = await http
          .get(
            Uri.parse(_videosUrl),
            headers: {'Authorization': 'Bearer ${widget.accessToken}'},
          )
          .timeout(const Duration(seconds: 20));
      if (_handleUnauthorized(response)) return;
      final data = decodeApiResponseObject(
        response.body,
        statusCode: response.statusCode,
        fallbackMessage: 'Não foi possível carregar as aulas.',
      );

      final videosData = data['videos'];
      if (videosData is! List) {
        throw Exception('A API retornou uma lista de vídeos inválida.');
      }
      final videos = videosData
          .whereType<Map<String, dynamic>>()
          .map((video) => video['name'])
          .whereType<String>()
          .toList();
      if (!mounted) return;
      setState(() => _videos = videos);
    } catch (error) {
      if (!mounted) return;
      setState(
        () =>
            _videoLoadError = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) setState(() => _isLoadingVideos = false);
    }
  }

  Future<void> _loadMyVideos() async {
    if (!_isProfessor) return;
    setState(() {
      _isLoadingMyVideos = true;
      _myVideoLoadError = null;
    });
    try {
      final response = await http
          .get(
            Uri.parse(_myVideosUrl),
            headers: {'Authorization': 'Bearer ${widget.accessToken}'},
          )
          .timeout(const Duration(seconds: 20));
      if (_handleUnauthorized(response)) return;
      final data = decodeApiResponseObject(
        response.body,
        statusCode: response.statusCode,
        fallbackMessage: 'Não foi possível carregar seus vídeos.',
      );
      final videosData = data['videos'];
      if (videosData is! List) {
        throw Exception('A API retornou uma lista de vídeos inválida.');
      }
      final videos = videosData
          .whereType<Map<String, dynamic>>()
          .map((video) => video['name'])
          .whereType<String>()
          .toList();
      if (!mounted) return;
      setState(() => _myVideos = videos);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _myVideoLoadError = error.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoadingMyVideos = false);
    }
  }

  Future<void> _deleteMyVideo(String videoName) async {
    setState(() => _deletingVideos.add(videoName));
    try {
      final response = await http
          .delete(
            Uri.parse('$_videoUrl/${Uri.encodeComponent(videoName)}'),
            headers: {'Authorization': 'Bearer ${widget.accessToken}'},
          )
          .timeout(const Duration(seconds: 20));
      if (_handleUnauthorized(response)) return;
      decodeApiResponseObject(
        response.body,
        statusCode: response.statusCode,
        fallbackMessage: 'Não foi possível excluir o vídeo.',
      );
      if (!mounted) return;
      setState(() {
        _myVideos = _myVideos.where((name) => name != videoName).toList();
        _videos = _videos.where((name) => name != videoName).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vídeo excluído com sucesso.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível excluir o vídeo: '
            '${error.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _deletingVideos.remove(videoName));
    }
  }

  Future<void> _openVideoRegistration() async {
    final uploadedName = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => CadastroVideoPage(accessToken: widget.accessToken),
      ),
    );
    if (!mounted || uploadedName == null) return;
    setState(() {
      _videos = [
        uploadedName,
        ..._videos.where((name) => name != uploadedName),
      ];
    });
    unawaited(_loadVideos());
    unawaited(_loadMyVideos());
  }

  Widget _buildContent() {
    if (_selectedTab == 0) {
      return _FeedVideo(
        key: ValueKey(_videos),
        accessToken: widget.accessToken,
        videos: _videos,
        isLoading: _isLoadingVideos,
        loadError: _videoLoadError,
        onRetry: _loadVideos,
      );
    }

    if (_selectedTab == 2) {
      return PerfilPage(
        accessToken: widget.accessToken,
        profile: _profile,
        onProfileUpdated: _updateProfile,
        onLoggedOut: widget.onLoggedOut,
      );
    }

    if (_selectedTab == 3 && _isProfessor) {
      return _MyVideosPage(
        accessToken: widget.accessToken,
        videos: _myVideos,
        isLoading: _isLoadingMyVideos,
        loadError: _myVideoLoadError,
        deletingVideos: _deletingVideos,
        onRetry: _loadMyVideos,
        onAddVideo: _openVideoRegistration,
        onDeleteVideo: _deleteMyVideo,
      );
    }

    return Container(
      width: double.infinity,
      color: const Color(0xB2D9D9D9),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.quiz_outlined, size: 56, color: const Color(0xFF0D1F43)),
          const SizedBox(height: 12),
          const Text(
            'A lista de quizzes virá em breve.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.black, fontSize: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationButton({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: IconButton(
        onPressed: () => setState(() => _selectedTab = index),
        tooltip: label,
        icon: Icon(
          icon,
          size: 30,
          color: isSelected ? const Color(0xFF01D0AF) : Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _selectedTab == 0 ? Colors.black : Colors.white,
      body: _selectedTab == 0
          ? SafeArea(
              child: Stack(
                children: [
                  Positioned.fill(child: _buildContent()),
                  Positioned(
                    top: 12,
                    left: 12,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xCC0D1F43),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: PopupMenuButton<int>(
                        tooltip: 'Abrir navegação',
                        onSelected: (index) => setState(() {
                          _selectedTab = index;
                        }),
                        color: const Color(0xFF0D1F43),
                        iconColor: Colors.white,
                        icon: const Icon(Icons.menu),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 1,
                            child: Text(
                              'Quiz',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          const PopupMenuItem(
                            value: 2,
                            child: Text(
                              'Perfil',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          if (_isProfessor)
                            const PopupMenuItem(
                              value: 3,
                              child: Text(
                                'Seus vídeos',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            )
          : SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    height: 80,
                    color: const Color(0xFF0D1F43),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _titles[_selectedTab],
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: MediaQuery.sizeOf(context).width < 340
                            ? 18
                            : 24,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(child: _buildContent()),
                  Container(
                    width: double.infinity,
                    height: 61,
                    color: const Color(0xFF0D1F43),
                    child: Row(
                      children: [
                        _buildNavigationButton(
                          index: 0,
                          icon: Icons.home_outlined,
                          label: 'Home',
                        ),
                        _buildNavigationButton(
                          index: 1,
                          icon: Icons.quiz_outlined,
                          label: 'Quiz',
                        ),
                        _buildNavigationButton(
                          index: 2,
                          icon: Icons.person_outline,
                          label: 'Perfil',
                        ),
                        if (_isProfessor)
                          _buildNavigationButton(
                            index: 3,
                            icon: Icons.video_library_outlined,
                            label: 'Seus vídeos',
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      floatingActionButton:
          _selectedTab == 0 && _profile['tipo_usuario'] == 'professor'
          ? FloatingActionButton(
              onPressed: _openVideoRegistration,
              tooltip: 'Cadastrar videoaula',
              backgroundColor: const Color(0xFF01D0AF),
              foregroundColor: Colors.white,
              child: const Icon(Icons.add, size: 32),
            )
          : null,
    );
  }
}

class _MyVideosPage extends StatelessWidget {
  const _MyVideosPage({
    required this.accessToken,
    required this.videos,
    required this.isLoading,
    required this.loadError,
    required this.deletingVideos,
    required this.onRetry,
    required this.onAddVideo,
    required this.onDeleteVideo,
  });

  final String accessToken;
  final List<String> videos;
  final bool isLoading;
  final String? loadError;
  final Set<String> deletingVideos;
  final VoidCallback onRetry;
  final VoidCallback onAddVideo;
  final Future<void> Function(String videoName) onDeleteVideo;

  Future<void> _confirmDelete(BuildContext context, String videoName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir videoaula?'),
        content: const Text(
          'Esta ação excluirá o vídeo permanentemente. Deseja continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed == true) await onDeleteVideo(videoName);
  }

  Future<void> _showPreview(BuildContext context, String videoName) {
    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Fechar pré-visualização',
                  icon: const Icon(Icons.close),
                ),
              ),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _FeedVideoCard(
                  accessToken: accessToken,
                  videoName: videoName,
                  isActive: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading && videos.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF01D0AF)),
      );
    }

    if (loadError != null && videos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(loadError!, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
              ),
            ],
          ),
        ),
      );
    }

    if (videos.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.video_library_outlined,
                size: 56,
                color: Color(0xFF0D1F43),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nenhuma aula foi adicionada',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onAddVideo,
                icon: const Icon(Icons.add),
                label: const Text('Adicionar aula'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF01D0AF),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ColoredBox(
      color: const Color(0xB2D9D9D9),
      child: Stack(
        children: [
          ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            itemCount: videos.length,
            itemBuilder: (context, index) {
              final videoName = videos[index];
              final isDeleting = deletingVideos.contains(videoName);
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: ColoredBox(
                        color: const Color(0xFF0D1F43),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.play_circle_outline,
                              color: Colors.white,
                              size: 56,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              videoName,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              videoName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF0D1F43),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _showPreview(context, videoName),
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Assistir'),
                          ),
                          IconButton(
                            onPressed: isDeleting
                                ? null
                                : () => _confirmDelete(context, videoName),
                            tooltip: 'Excluir videoaula',
                            color: Colors.red,
                            icon: isDeleting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (isLoading)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(color: Color(0xFF01D0AF)),
            ),
          if (loadError != null)
            Positioned(
              top: 8,
              left: 8,
              right: 8,
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(8),
                child: ListTile(
                  dense: true,
                  title: Text(loadError!),
                  trailing: IconButton(
                    onPressed: onRetry,
                    tooltip: 'Tentar novamente',
                    icon: const Icon(Icons.refresh),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FeedVideo extends StatefulWidget {
  const _FeedVideo({
    super.key,
    required this.accessToken,
    required this.videos,
    required this.isLoading,
    required this.loadError,
    required this.onRetry,
  });

  final String accessToken;
  final List<String> videos;
  final bool isLoading;
  final String? loadError;
  final VoidCallback onRetry;

  @override
  State<_FeedVideo> createState() => _FeedVideoState();
}

class _FeedVideoState extends State<_FeedVideo> {
  int _activeIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: widget.isLoading
              ? const CircularProgressIndicator(color: Color(0xFF01D0AF))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.loadError == null
                          ? Icons.ondemand_video_outlined
                          : Icons.error_outline,
                      color: Colors.white70,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.loadError == null
                          ? 'Ainda não há videoaulas disponíveis.'
                          : 'Não foi possível carregar as videoaulas.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white),
                    ),
                    if (widget.loadError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.loadError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      TextButton.icon(
                        onPressed: widget.onRetry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF01D0AF),
                        ),
                      ),
                    ],
                  ],
                ),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          scrollDirection: Axis.vertical,
          itemCount: widget.videos.length,
          onPageChanged: (index) => setState(() => _activeIndex = index),
          itemBuilder: (context, index) => _FeedVideoCard(
            key: ValueKey(widget.videos[index]),
            accessToken: widget.accessToken,
            videoName: widget.videos[index],
            isActive: index == _activeIndex,
          ),
        ),
        if (widget.isLoading)
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: LinearProgressIndicator(color: Color(0xFF01D0AF)),
          ),
        if (widget.loadError != null)
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: widget.onRetry,
              tooltip: 'Tentar carregar videoaulas novamente',
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh),
            ),
          ),
      ],
    );
  }
}

class _FeedVideoCard extends StatefulWidget {
  const _FeedVideoCard({
    super.key,
    required this.accessToken,
    required this.videoName,
    required this.isActive,
  });

  final String accessToken;
  final String videoName;
  final bool isActive;

  @override
  State<_FeedVideoCard> createState() => _FeedVideoCardState();
}

class _FeedVideoCardState extends State<_FeedVideoCard> {
  VideoPlayerController? _controller;
  Uri? _blobSource;
  Object? _loadError;
  bool _isMuted = true;
  bool _isInitializing = false;
  bool _showControls = false;
  Timer? _controlsVisibilityTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isActive) unawaited(_initializeVideo());
  }

  @override
  void didUpdateWidget(covariant _FeedVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      unawaited(_updatePlayback());
    }
  }

  Future<void> _updatePlayback() async {
    if (widget.isActive) {
      if (_controller == null && _loadError == null) {
        await _initializeVideo();
      } else if (_controller?.value.isInitialized == true) {
        await _controller!.play();
        _scheduleControlsHide();
      }
      return;
    }

    _controlsVisibilityTimer?.cancel();
    final controller = _controller;
    if (controller?.value.isInitialized == true &&
        controller!.value.isPlaying) {
      await controller.pause();
    }
  }

  Future<void> _initializeVideo() async {
    if (_isInitializing) return;
    _isInitializing = true;
    try {
      final source = Uri.parse(
        'http://localhost:8081/api/video/'
        '${Uri.encodeComponent(widget.videoName)}',
      );
      final playableSource = await video_source.prepareVideoSource(
        source,
        widget.accessToken,
      );
      if (!mounted) {
        if (playableSource != source) {
          video_source.releaseVideoSource(playableSource);
        }
        return;
      }
      if (playableSource != source) _blobSource = playableSource;
      final controller = VideoPlayerController.networkUrl(
        playableSource,
        httpHeaders: playableSource == source
            ? {'Authorization': 'Bearer ${widget.accessToken}'}
            : const {},
      );
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (widget.isActive) await controller.play();
      if (mounted) setState(() {});
    } catch (error) {
      final controller = _controller;
      _controller = null;
      if (controller != null) unawaited(controller.dispose());
      final blobSource = _blobSource;
      _blobSource = null;
      if (blobSource != null) video_source.releaseVideoSource(blobSource);
      if (mounted) setState(() => _loadError = error);
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _togglePlayback() async {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      await controller.pause();
      _controlsVisibilityTimer?.cancel();
      _showControls = true;
    } else {
      await controller.play();
      _showControls = true;
      _scheduleControlsHide();
    }
    if (mounted) setState(() {});
  }

  Future<void> _handleVideoTap() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    _controlsVisibilityTimer?.cancel();
    if (controller.value.isPlaying) {
      await controller.pause();
    }
    if (mounted) {
      setState(() => _showControls = true);
    }
  }

  void _scheduleControlsHide() {
    _controlsVisibilityTimer?.cancel();
    _controlsVisibilityTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _controller?.value.isPlaying == true) {
        setState(() => _showControls = false);
      }
    });
  }

  Future<void> _toggleMute() async {
    final controller = _controller;
    if (controller == null) return;
    _isMuted = !_isMuted;
    await controller.setVolume(_isMuted ? 0 : 1);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controlsVisibilityTimer?.cancel();
    _controller?.dispose();
    final blobSource = _blobSource;
    if (blobSource != null) video_source.releaseVideoSource(blobSource);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: Colors.black, child: _buildPlayer());
  }

  Widget _buildPlayer() {
    if (_loadError != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Não foi possível carregar o vídeo.',
                style: TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '$_loadError',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
              const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () {
                  setState(() => _loadError = null);
                  _initializeVideo();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Tentar novamente'),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF01D0AF)),
        ),
      );
    }

    final size = controller.value.size;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: VideoPlayer(controller),
            ),
          ),
        ),
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _handleVideoTap,
          ),
        ),
        if (_showControls) ...[
          IconButton(
            onPressed: _togglePlayback,
            iconSize: 64,
            color: Colors.white,
            icon: Icon(
              controller.value.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_filled,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: IconButton(
              onPressed: _toggleMute,
              color: Colors.white,
              icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up),
            ),
          ),
        ],
      ],
    );
  }
}
