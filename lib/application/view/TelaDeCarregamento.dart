import 'package:flutter/material.dart';

class TelaDeCarregamento extends StatefulWidget {
  const TelaDeCarregamento({super.key, required this.nextPageBuilder});

  final WidgetBuilder nextPageBuilder;

  @override
  State<TelaDeCarregamento> createState() => _TelaDeCarregamentoState();
}

class _TelaDeCarregamentoState extends State<TelaDeCarregamento> {
  @override
  void initState() {
    super.initState();
    _openNextPage();
  }

  Future<void> _openNextPage() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    await Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute<void>(builder: widget.nextPageBuilder));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F43),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scale = (constraints.maxWidth / 412).clamp(0.7, 1.2);
            final iconSize = (constraints.maxHeight * 0.29)
                .clamp(110.0, 224.0)
                .toDouble();

            return SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                children: [
                  const Spacer(flex: 4),
                  Icon(
                    Icons.school_rounded,
                    color: Colors.white,
                    size: iconSize,
                  ),
                  const Spacer(flex: 1),
                  Text(
                    'PRISMA',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 64 * scale,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 10 * scale,
                    ),
                  ),
                  SizedBox(height: 44 * scale),
                  Text(
                    'TODAS AS MATÉRIAS.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF01D0AF),
                      fontSize: 26 * scale,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 5 * scale,
                    ),
                  ),
                  SizedBox(height: 44 * scale),
                  Text(
                    'UM SÓ LUGAR.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xFF01D0AF),
                      fontSize: 26 * scale,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 5 * scale,
                    ),
                  ),
                  const Spacer(flex: 5),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
