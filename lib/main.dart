import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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

enum GameState { ready, playing, gameOver }

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
  late Offset _ball;      // centro de la pelota
  late Offset _vel;       // píxeles/segundo
  late double _paddleCx;  // centro X de la paleta
  int _score = 0;
  int _lives = 3;
  double _speedMultiplier = 1.0;

  Rect get _paddle => Rect.fromCenter(
        center: Offset(_paddleCx, _size.height - 40),
        width: _paddleWidth,
        height: _paddleHeight,
      );

  @override
  void initState() {
    super.initState();
    _resetScene(hard: true);
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _ensureLayout(Size size) {
    if (_size == size) return;
    _size = size;
    _centerBall(towardsDown: true);
    _paddleCx = size.width / 2;
  }

  void _resetScene({bool hard = false}) {
    // hard = true: reinicia todo (score, vidas, velocidad); false: reseteo parcial (pérdida de vida)
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
      _lastTick = Duration.zero; // resync
      setState(() {});
    }
  }

  void _onTick(Duration now) {
    if (_state != GameState.playing) {
      _lastTick = now; // mantén el reloj actualizado para evitar salto al reanudar
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

    // Rebotes laterales
    if (x - _ballRadius < 0) {
      x = _ballRadius;
      _vel = Offset(-_vel.dx, _vel.dy);
    } else if (x + _ballRadius > _size.width) {
      x = _size.width - _ballRadius;
      _vel = Offset(-_vel.dx, _vel.dy);
    }

    // Techo
    if (y - _ballRadius < 0) {
      y = _ballRadius;
      _vel = Offset(_vel.dx, -_vel.dy);
    }

    // Colisión paleta
    final paddle = _paddle;
    final hitsHorizontally = x >= paddle.left && x <= paddle.right;
    final crossedTop = (prev.dy + _ballRadius) <= paddle.top && (y + _ballRadius) >= paddle.top;
    final goingDown = _vel.dy > 0;

    if (goingDown && hitsHorizontally && crossedTop) {
      y = paddle.top - _ballRadius;

      // Inglés/ángulo según punto de impacto + subida leve de dificultad
      final offsetX = ((x - paddle.center.dx) / (paddle.width / 2)).clamp(-1.0, 1.0);
      _speedMultiplier = min(_speedMultiplier * 1.04, 2.2); // límite para que no sea imposible
      final baseBoost = 240.0 * _speedMultiplier;

      final newVx = (_vel.dx + baseBoost * offsetX).clamp(-600, 600);
      final newVy = -_vel.dy.abs() * (1.02 + 0.02 * _speedMultiplier);

      _vel = Offset(newVx.toDouble(), newVy.toDouble());
      _score += 1;
    }

    // Piso: pierdes una vida o Game Over
    if (y - _ballRadius > _size.height) {
      _lives -= 1;
      if (_lives <= 0) {
        _state = GameState.gameOver;
      } else {
        _centerBall(towardsDown: true);
        // Pequeña penalización de dificultad
        _speedMultiplier = max(1.0, _speedMultiplier * 0.95);
      }
      setState(() {});
      return;
    }

    setState(() {
      _ball = Offset(x, y);
    });
  }

  void _onDrag(DragUpdateDetails d) {
    // Permite ajustar la paleta en ready/playing para “acomodarla” antes de empezar
    if (_size == Size.zero) return;
    _paddleCx = (_paddleCx + d.delta.dx).clamp(
      _paddleWidth / 2,
      _size.width - _paddleWidth / 2,
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _ensureLayout(size);

        return Scaffold(
          body: SafeArea(
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

                  // HUD superior: título, paso, marcador y vidas
                  Positioned(
                    top: 8,
                    left: 12,
                    right: 12,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Pong del Curso",
                            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                        Row(
                          children: [
                            const Text("Paso 06: inicio + game over",
                                style: TextStyle(fontSize: 14, color: Colors.white70)),
                            const SizedBox(width: 12),
                            _Pill(text: "Puntos: $_score"),
                            const SizedBox(width: 8),
                            _Pill(text: "Vidas: $_lives"),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Overlays: Ready / Game Over
                  if (_state == GameState.ready) _overlayCenter(
                    title: "Toca para comenzar",
                    subtitle: "Arrastra para mover la paleta",
                    icon: Icons.play_arrow_rounded,
                  ),
                  if (_state == GameState.gameOver) _overlayCenter(
                    title: "Game Over",
                    subtitle: "Toca para reiniciar",
                    icon: Icons.replay_rounded,
                  ),
                ],
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
