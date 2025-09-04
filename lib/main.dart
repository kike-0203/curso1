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

  // Estado de animación
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Size _size = Size.zero;

  // Estado de juego
  late Offset _ball;      // centro de la pelota
  late Offset _vel;       // píxeles/segundo
  late double _paddleCx;  // centro X de la paleta
  Rect get _paddle => Rect.fromCenter(
        center: Offset(_paddleCx, _size.height - 40),
        width: _paddleWidth,
        height: _paddleHeight,
      );

  int _score = 0;

  @override
  void initState() {
    super.initState();
    _ball = const Offset(100, 100);
    _vel  = const Offset(180, 240);
    _paddleCx = 150;
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

    // Centrar escena al conocer el tamaño
    _ball = Offset(size.width / 2, size.height / 3);
    _paddleCx = size.width / 2;
  }

  void _resetBall({bool towardsDown = true}) {
    // Resetea pelota al centro con dirección aleatoria
    final rand = Random();
    final dirX = (rand.nextBool() ? 1 : -1) * (140 + rand.nextInt(160));
    final dirY = (towardsDown ? 1 : -1) * (180 + rand.nextInt(180));
    _ball = Offset(_size.width / 2, _size.height / 3);
    _vel = Offset(dirX.toDouble(), dirY.toDouble());
  }

  void _onTick(Duration now) {
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

    // Colisión con paleta (cuando venimos bajando y cruzamos su borde superior)
    final paddle = _paddle;
    final hitsHorizontally = x >= paddle.left && x <= paddle.right;
    final crossedTop = (prev.dy + _ballRadius) <= paddle.top && (y + _ballRadius) >= paddle.top;
    final goingDown = _vel.dy > 0;

    if (goingDown && hitsHorizontally && crossedTop) {
      // Reposicionar justo encima para evitar "pegado"
      y = paddle.top - _ballRadius;

      // "Inglés" según punto de impacto
      final offsetX = ((x - paddle.center.dx) / (paddle.width / 2)).clamp(-1.0, 1.0);
      // Aumenta ligeramente la velocidad y aplica ángulo
      final newVx = (_vel.dx + 220 * offsetX).clamp(-500, 500);
      final newVy = -_vel.dy.abs() * 1.05; // rebote hacia arriba + leve aceleración

      _vel = Offset(newVx.toDouble(), newVy.toDouble());
      _score += 1;
    }

    // Piso (fallo): reinicia pelota y marcador a cero
    if (y - _ballRadius > _size.height) {
      _score = 0;
      _resetBall(towardsDown: true);
      setState(() {}); // actualiza score y posición de reset
      return;
    }

    setState(() {
      _ball = Offset(x, y);
    });
  }

  void _onDrag(DragUpdateDetails d) {
    if (_size == Size.zero) return;
    _paddleCx = (_paddleCx + d.delta.dx).clamp(
      _paddleWidth / 2,
      _size.width - _paddleWidth / 2,
    );
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
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GamePainter(
                        ballCenter: _ball,
                        ballRadius: _ballRadius,
                        paddleRect: _paddle,
                      ),
                    ),
                  ),
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
                            const Text("Paso 05: control + colisión",
                                style: TextStyle(fontSize: 14, color: Colors.white70)),
                            const SizedBox(width: 12),
                            _ScoreBadge(score: _score),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({super.key, required this.score});
  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: Text(
        "Puntos: $score",
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }
}
