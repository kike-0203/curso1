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
  final double _paddleWidth = 90.0;
  final double _paddleHeight = 14.0;

  // Estado de animación
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;
  Size _size = Size.zero;

  // Estado de juego
  late Offset _ball; // centro de la pelota
  late Offset _vel;  // píxeles/segundo
  late Rect _paddle; // paleta (fija en este paso)

  @override
  void initState() {
    super.initState();
    // Valores por defecto; se recalibran al conocer el size
    _ball = const Offset(100, 100);
    _vel  = const Offset(180, 240); // velocidad inicial (px/s)
    _paddle = Rect.zero;

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

    // Centrar pelota y colocar paleta al fondo al conocer el tamaño
    _ball = Offset(size.width / 2, size.height / 3);
    _paddle = Rect.fromCenter(
      center: Offset(size.width / 2, size.height - 40),
      width: _paddleWidth,
      height: _paddleHeight,
    );
  }

  void _onTick(Duration now) {
    if (_lastTick == Duration.zero) {
      _lastTick = now;
      return;
    }
    final dt = (now - _lastTick).inMicroseconds / 1e6; // segundos
    _lastTick = now;

    if (_size == Size.zero) return; // aún no conocemos el layout

    // Integración: nueva posición = pos + v * dt
    double x = _ball.dx + _vel.dx * dt;
    double y = _ball.dy + _vel.dy * dt;

    // Rebotes en paredes
    // Izquierda / derecha
    if (x - _ballRadius < 0) {
      x = _ballRadius;
      _vel = Offset(-_vel.dx, _vel.dy);
    } else if (x + _ballRadius > _size.width) {
      x = _size.width - _ballRadius;
      _vel = Offset(-_vel.dx, _vel.dy);
    }

    // Techo / piso (por ahora la pelota rebota, en el siguiente paso el piso será “fallo” contra paleta)
    if (y - _ballRadius < 0) {
      y = _ballRadius;
      _vel = Offset(_vel.dx, -_vel.dy);
    } else if (y + _ballRadius > _size.height) {
      y = _size.height - _ballRadius;
      _vel = Offset(_vel.dx, -_vel.dy);
    }

    setState(() {
      _ball = Offset(x, y);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _ensureLayout(size);

        return Scaffold(
          body: SafeArea(
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
                    children: const [
                      Text("Pong del Curso",
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                      Text("Paso 04: animación + rebotes",
                          style: TextStyle(fontSize: 14, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
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

    // Borde del área
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

    // Paleta (aún estática en este paso)
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
