import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../state/level_bus.dart';

class VolumeEqualizer extends StatelessWidget {
  const VolumeEqualizer({super.key});

  @override
  Widget build(BuildContext context) {
    final bars = 16;
    final width = MediaQuery.of(context).size.width * 0.8;
    // Each bar is wrapped with horizontal padding of 3 on both sides => 6 per bar
    final totalHorizontalPadding = bars * 6;
    final computed = (width - totalHorizontalPadding) / bars;
    final barWidth = computed.clamp(2.0, 24.0);

    return SizedBox(
      width: width,
      height: 120,
      child: ValueListenableBuilder<double>(
        valueListenable: VolumeLevelBus.level,
        builder: (context, level, _) {
          final visualLevel = Curves.easeOut.transform(level.clamp(0, 1));
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(bars, (i) {
              final noise = 0.4 + 0.6 * math.sin(i * 1.7);
              final h = 10 + (100 * (visualLevel * noise)).clamp(10, 100);
              final height = h.toDouble();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                  width: barWidth,
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 8),
                    ],
                  ),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}