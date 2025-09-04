import 'dart:math';
import 'package:flutter/material.dart';

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

class _GamePageState extends State<GamePage> {
  final _ballRadius = 10.0;
  final _paddleWidth = 90.0;
  final _paddleHeight = 14.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final ballCenter = Offset(size.width / 2, size.height / 3);
        final paddleRect = Rect.fromCenter(
          center: Offset(size.width / 2, size.height - 40),
          width: _paddleWidth,
          height: _paddleHeight,
        );

        return Scaffold(
          body: SafeArea(
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: _GamePainter(
                      ballCenter: ballCenter,
                      ballRadius: _ballRadius,
                      paddleRect: paddleRect,
                    ),
                  ),
                ),
                Positioned(
                  top: 8, left: 12, right: 12,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text("Pong del Curso",
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
                      Text("Paso 03: dibujo estático",
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

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paintLines);

    final dashWidth = 6.0, dashSpace = 8.0;
    double y = 0;
    final cx = size.width / 2;
    while (y < size.height) {
      canvas.drawLine(Offset(cx, y), Offset(cx, min(y + dashWidth, size.height)), paintLines);
      y += dashWidth + dashSpace;
    }

    canvas.drawCircle(ballCenter, ballRadius, paintBall);

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
