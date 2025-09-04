import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PongApp());
}

class PongApp extends StatelessWidget {
  const PongApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pong del Curso',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F111A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.greenAccent,
          brightness: Brightness.dark,
        ),
      ),
      home: const GamePage(),
    );
  }
}

enum GameState { ready, playing, paused, gameOver }

class GamePage extends StatefulWidget {
  const GamePage({super.key});
  @override
  State<GamePage> createState() => _GamePageState();
}

class _GamePageState extends State<GamePage> with SingleTickerProviderStateMixin {
  // Parámetros de escena
  final double _ballRadius = 10.0;
  final double _paddleWidth = 100.0;
  final double _paddleHeight = 14.0;

  // Animación
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Size _size = Size.zero;

  // Juego
  GameState _state = GameState.ready;
  late Offset _ball;      // centro
  late Offset _vel;       // px/s
  late double _paddleCx;  // centro X paleta
  int _score = 0;
  int _lives = 3;
  double _speedMultiplier = 1.0;

  // Récord (persistente)
  int _best = 0;

  // Audio
  final _bounceSfx = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
  final _gameOverSfx = AudioPlayer()..setReleaseMode(ReleaseMode.stop);

  Rect get _paddle => Rect.fromCenter(
        center: Offset(_paddleCx, _size.height - 40),
        width: _paddleWidth,
        height: _paddleHeight,
      );

  // Teclado
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _resetScene(hard: true);
    _ticker = createTicker(_onTick)..start();
    _preloadSounds();
    _loadBestScore(); // <<-- Cargar récord guardado
  }

  Future<void> _preloadSounds() async {
    try { await _bounceSfx.setSourceAsset('assets/sounds/bounce.mp3'); } catch (_) {}
    try { await _gameOverSfx.setSourceAsset('assets/sounds/game_over.mp3'); } catch (_) {}
  }

  Future<void> _loadBestScore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _best = prefs.getInt('best_score') ?? 0;
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _maybeSaveBest() async {
    if (_score > _best) {
      _best = _score;
      setState(() {});
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('best_score', _best);
      } catch (_) {}
    }
  }

  Future<void> _playBounce() async {
    try { await _bounceSfx.stop(); await _bounceSfx.play(AssetSource('assets/sounds/bounce.mp3')); } catch (_) {}
  }

  Future<void> _playGameOver() async {
    try { await _gameOverSfx.stop(); await _gameOverSfx.play(AssetSource('assets/sounds/game_over.mp3')); } catch (_) {}
  }

  @override
  void dispose() {
    _ticker.dispose();
    _bounceSfx.dispose();
    _gameOverSfx.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _ensureLayout(Size size) {
    if (_size == size) return;
    _size = size;
    _centerBall(towardsDown: true);
    _paddleCx = size.width / 2;
  }

  void _resetScene({bool hard = false}) {
    if (hard) {
      _score = 0;
      _lives = 3;
      _speedMultiplier = 1.0;
    }
    _centerBall(towardsDown: true);
    _paddleCx = _size == Size.zero ? 150 : _size.width / 2;
    _state = GameState.ready;
  }

  void _centerBall({required bool towardsDown}) {
    final rand = Random();
    final baseX = (rand.nextBool() ? 1 : -1) * (160 + rand.nextInt(120));
    final baseY = (towardsDown ? 1 : -1) * (220 + rand.nextInt(160));
    if (_size == Size.zero) {
      _ball = const Offset(120, 120);
    } else {
      _ball = Offset(_size.width / 2, _size.height / 3);
    }
    _vel = Offset(baseX.toDouble(), baseY.toDouble()) * _speedMultiplier;
  }

  void _startGame() {
    if (_state == GameState.ready || _state == GameState.gameOver) {
      _state = GameState.playing;
      _lastTick = Duration.zero;
      setState(() {});
    }
  }

  void _togglePause() {
    if (_state == GameState.playing) {
      _state = GameState.paused;
    } else if (_state == GameState.paused) {
      _state = GameState.playing;
      _lastTick = Duration.zero;
    }
    setState(() {});
  }

  void _onTick(Duration now) {
    if (_state != GameState.playing) {
      _lastTick = now;
      return;
    }
    if (_lastTick == Duration.zero) {
      _lastTick = now;
      return;
    }
    final dt = (now - _lastTick).inMicroseconds / 1e6;
    _lastTick = now;
    if (_size == Size.zero) return;

    // Integración
    final prev = _ball;
    double x = _ball.dx + _vel.dx * dt;
    double y = _ball.dy + _vel.dy * dt;

    // Paredes
    if (x - _ballRadius < 0) { x = _ballRadius; _vel = Offset(-_vel.dx, _vel.dy); _playBounce(); }
    else if (x + _ballRadius > _size.width) { x = _size.width - _ballRadius; _vel = Offset(-_vel.dx, _vel.dy); _playBounce(); }
    if (y - _ballRadius < 0) { y = _ballRadius; _vel = Offset(_vel.dx, -_vel.dy); _playBounce(); }

    // Paleta
    final paddle = _paddle;
    final hitsHorizontally = x >= paddle.left && x <= paddle.right;
    final crossedTop = (prev.dy + _ballRadius) <= paddle.top && (y + _ballRadius) >= paddle.top;
    final goingDown = _vel.dy > 0;

    if (goingDown && hitsHorizontally && crossedTop) {
      y = paddle.top - _ballRadius;
      final offsetX = ((x - paddle.center.dx) / (paddle.width / 2)).clamp(-1.0, 1.0);
      _speedMultiplier = min(_speedMultiplier * 1.04, 2.2);
      final baseBoost = 240.0 * _speedMultiplier;
      final newVx = (_vel.dx + baseBoost * offsetX).clamp(-600, 600);
      final newVy = -_vel.dy.abs() * (1.02 + 0.02 * _speedMultiplier);
      _vel = Offset(newVx.toDouble(), newVy.toDouble());
      _score += 1;
      _playBounce();
      _maybeSaveBest(); // <<-- actualiza récord si corresponde
    }

    // Piso
    if (y - _ballRadius > _size.height) {
      _lives -= 1;
      if (_lives <= 0) {
        _state = GameState.gameOver;
        _playGameOver();
        _maybeSaveBest(); // <<-- también al terminar la partida
      } else {
        _centerBall(towardsDown: true);
        _speedMultiplier = max(1.0, _speedMultiplier * 0.95);
      }
      setState(() {});
      return;
    }

    setState(() { _ball = Offset(x, y); });
  }

  void _onDrag(DragUpdateDetails d) {
    if (_size == Size.zero) return;
    _paddleCx = (_paddleCx + d.delta.dx).clamp(
      _paddleWidth / 2,
      _size.width - _paddleWidth / 2,
    );
    setState(() {});
  }

  KeyEventResult _onKey(FocusNode node, RawKeyEvent evt) {
    if (evt is RawKeyDownEvent) {
      final key = evt.logicalKey;
      if (key.keyLabel.toLowerCase() == 'p') { _togglePause(); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.arrowLeft)  { _paddleCx = max(_paddleWidth / 2, _paddleCx - 24); setState(() {}); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.arrowRight) { _paddleCx = min(_size.width - _paddleWidth / 2, _paddleCx + 24); setState(() {}); return KeyEventResult.handled; }
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
        if (_state == GameState.ready) _startGame();
        else if (_state == GameState.gameOver) { _resetScene(hard: true); setState(() {}); }
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _ensureLayout(size);

        return Scaffold(
          body: SafeArea(
            child: Focus(
              autofocus: true,
              focusNode: _focus,
              onKey: _onKey,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: _onDrag,
                onTap: () {
                  if (_state == GameState.ready) {
                    _startGame();
                  } else if (_state == GameState.gameOver) {
                    _resetScene(hard: true);
                    setState(() {});
                  }
                },
                child: Stack(
                  children: [
                    // Juego
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GamePainter(
                          ballCenter: _ball,
                          ballRadius: _ballRadius,
                          paddleRect: _paddle,
                        ),
                      ),
                    ),

                    // HUD superior
                    Positioned(
                      top: 8,
                      left: 12,
                      right: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Pong del Curso",
                              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            children: [
                              const Text("Paso 08: récord guardado",
                                  style: TextStyle(fontSize: 14, color: Colors.white70)),
                              _Pill(text: "Puntos: $_score"),
                              _Pill(text: "Vidas: $_lives"),
                              _Pill(text: "Best: $_best"),
                              _PauseButton(
                                isPaused: _state == GameState.paused,
                                onToggle: _togglePause,
                                enabled: _state == GameState.playing || _state == GameState.paused,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Overlays
                    if (_state == GameState.ready) _overlayCenter(
                      title: "Toca para comenzar",
                      subtitle: "Arrastra para mover la paleta\nTecla P: Pausa/Continuar",
                      icon: Icons.play_arrow_rounded,
                    ),
                    if (_state == GameState.paused) _overlayCenter(
                      title: "Pausa",
                      subtitle: "Toca el botón ▷ o presiona P para continuar",
                      icon: Icons.pause_rounded,
                    ),
                    if (_state == GameState.gameOver) _overlayCenter(
                      title: "Game Over",
                      subtitle: "Toca para reiniciar (o Enter/Espacio)",
                      icon: Icons.replay_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _overlayCenter({required String title, required String subtitle, required IconData icon}) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.35),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0F111A).withOpacity(0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 56, color: Colors.greenAccent),
                  const SizedBox(height: 12),
                  Text(title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GamePainter extends CustomPainter {
  _GamePainter({
    required this.ballCenter,
    required this.ballRadius,
    required this.paddleRect,
  });

  final Offset ballCenter;
  final double ballRadius;
  final Rect paddleRect;

  @override
  void paint(Canvas canvas, Size size) {
    final paintLines = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final paintBall = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final paintPaddle = Paint()
      ..shader = const LinearGradient(
        colors: [Colors.greenAccent, Colors.white],
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
      ).createShader(Rect.fromLTWH(0, 0, paddleRect.width, paddleRect.height));

    // Borde
    canvas.drawRect(Offset.zero & size, paintLines);

    // Línea central punteada
    const dashWidth = 6.0, dashSpace = 8.0;
    double y = 0;
    final cx = size.width / 2;
    while (y < size.height) {
      canvas.drawLine(Offset(cx, y), Offset(cx, min(y + dashWidth, size.height)), paintLines);
      y += dashWidth + dashSpace;
    }

    // Pelota
    canvas.drawCircle(ballCenter, ballRadius, paintBall);

    // Paleta
    canvas.drawRRect(
      RRect.fromRectAndRadius(paddleRect, const Radius.circular(6)),
      paintPaddle,
    );
  }

  @override
  bool shouldRepaint(covariant _GamePainter old) {
    return old.ballCenter != ballCenter ||
        old.ballRadius != ballRadius ||
        old.paddleRect != paddleRect;
  }
}

class _Pill extends StatelessWidget {
  const _Pill({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}

class _PauseButton extends StatelessWidget {
  const _PauseButton({super.key, required this.isPaused, required this.onToggle, required this.enabled});
  final bool isPaused;
  final VoidCallback onToggle;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: IgnorePointer(
        ignoring: !enabled,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white24),
            ),
            child: Icon(
              isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
              size: 22,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
