import 'package:flutter/material.dart';

/// Widget que anima la entrada de un elemento de lista con
/// un efecto de fade + slide desde abajo, con retraso escalonado
/// basado en el [index] del elemento.
///
/// Uso:
/// ```dart
/// _AnimatedListItem(index: i, child: MiCard())
/// ```
class AnimatedListItem extends StatelessWidget {
  const AnimatedListItem({
    super.key,
    required this.index,
    required this.child,
    this.delayMs = 60,
  });

  final int index;
  final Widget child;

  /// Milisegundos de retraso adicional por índice (default 60ms)
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final delay = Duration(milliseconds: index * delayMs);
    final duration = const Duration(milliseconds: 350);

    return TweenAnimationBuilder<double>(
      key: ValueKey(index),
      tween: Tween(begin: 0.0, end: 1.0),
      duration: duration + delay,
      curve: Curves.easeOut,
      builder: (context, value, child) {
        // value va de 0.0 a 1.0; el retraso se simula acortando el progreso
        // relativo al delay proporcional
        final progress =
            ((value -
                        (delay.inMilliseconds /
                            (duration + delay).inMilliseconds)) /
                    (duration.inMilliseconds /
                        (duration + delay).inMilliseconds))
                .clamp(0.0, 1.0);
        return Opacity(
          opacity: progress,
          child: Transform.translate(
            offset: Offset(0, 20 * (1.0 - progress)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
