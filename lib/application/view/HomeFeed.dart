import 'package:flutter/material.dart';
import 'package:projeto_base_prisma/application/view/PerfilPage.dart';
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

  static const _titles = ['AULAS PARA VOCÊ', 'QUIZ', 'PERFIL'];

  @override
  void initState() {
    super.initState();
    _profile = Map<String, dynamic>.from(widget.profile);
  }

  void _updateProfile(Map<String, dynamic> profile) {
    setState(() => _profile = profile);
  }

  Widget _buildContent() {
    if (_selectedTab == 0) {
      return const _FeedVideo();
    }

    if (_selectedTab == 2) {
      return PerfilPage(
        accessToken: widget.accessToken,
        profile: _profile,
        onProfileUpdated: _updateProfile,
        onLoggedOut: widget.onLoggedOut,
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
      backgroundColor: Colors.white,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              height: 80,
              color: const Color(0xFF0D1F43),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
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
                  if (_selectedTab == 0) ...[
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Os filtros serão habilitados quando o feed '
                              'de vídeos for integrado.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.filter_list, size: 18),
                      label: const Text('Filtrar'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF01D0AF),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ],
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedVideo extends StatefulWidget {
  const _FeedVideo();

  @override
  State<_FeedVideo> createState() => _FeedVideoState();
}

class _FeedVideoState extends State<_FeedVideo> {
  late final VideoPlayerController _controller;
  Object? _loadError;
  bool _isMuted = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(
      'lib/application/icons/firefly_video.mp4',
    );
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      await _controller.initialize();
      await _controller.setLooping(true);
      await _controller.setVolume(0);
      await _controller.play();
      if (mounted) setState(() {});
    } catch (error) {
      if (mounted) setState(() => _loadError = error);
    }
  }

  Future<void> _togglePlayback() async {
    if (_controller.value.isPlaying) {
      await _controller.pause();
    } else {
      await _controller.play();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleMute() async {
    _isMuted = !_isMuted;
    await _controller.setVolume(_isMuted ? 0 : 1);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: const Color(0xB2D9D9D9),
      alignment: Alignment.center,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth < 960
              ? constraints.maxWidth
              : 960.0;
          return SizedBox(
            width: width,
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRect(child: _buildPlayer()),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPlayer() {
    if (_loadError != null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Text(
            'Não foi possível carregar o vídeo.',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    if (!_controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF01D0AF)),
        ),
      );
    }

    final size = _controller.value.size;
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: size.width,
              height: size.height,
              child: VideoPlayer(_controller),
            ),
          ),
        ),
        IconButton(
          onPressed: _togglePlayback,
          iconSize: 56,
          color: Colors.white,
          icon: Icon(
            _controller.value.isPlaying
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
    );
  }
}
