import 'dart:async';
import 'package:flutter/material.dart';

/// A modal bottom sheet countdown/stopwatch timer.
/// The user can set a duration (minutes + seconds) and start/pause/reset it.
/// A simple stopwatch mode is also available (counts up from 0).
class TimerSheet extends StatefulWidget {
  const TimerSheet({super.key});

  @override
  State<TimerSheet> createState() => _TimerSheetState();
}

enum _TimerMode { countdown, stopwatch }

class _TimerSheetState extends State<TimerSheet> {
  _TimerMode _mode = _TimerMode.countdown;

  // ── countdown state ──────────────────────────────────────────────────────
  int _setMinutes = 5;
  int _setSeconds = 0;

  /// Remaining seconds for countdown / elapsed seconds for stopwatch.
  int _remainingSeconds = 5 * 60;
  bool _running = false;
  bool _finished = false;
  Timer? _ticker;

  // ── lifecycle ────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  // ── timer logic ──────────────────────────────────────────────────────────

  void _start() {
    if (_finished) _reset();
    setState(() => _running = true);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _ticker?.cancel();
        return;
      }
      setState(() {
        if (_mode == _TimerMode.countdown) {
          if (_remainingSeconds > 0) {
            _remainingSeconds--;
          } else {
            _finished = true;
            _running = false;
            _ticker?.cancel();
          }
        } else {
          _remainingSeconds++;
        }
      });
    });
  }

  void _pause() {
    _ticker?.cancel();
    setState(() => _running = false);
  }

  void _reset() {
    _ticker?.cancel();
    setState(() {
      _running = false;
      _finished = false;
      _remainingSeconds = _mode == _TimerMode.countdown
          ? _setMinutes * 60 + _setSeconds
          : 0;
    });
  }

  void _switchMode(_TimerMode mode) {
    _ticker?.cancel();
    setState(() {
      _mode = mode;
      _running = false;
      _finished = false;
      _remainingSeconds = mode == _TimerMode.countdown
          ? _setMinutes * 60 + _setSeconds
          : 0;
    });
  }

  // ── display helpers ──────────────────────────────────────────────────────

  String _formatTime(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCountdown = _mode == _TimerMode.countdown;
    final totalSet = _setMinutes * 60 + _setSeconds;
    final progress = isCountdown && totalSet > 0
        ? _remainingSeconds / totalSet
        : null; // null → no progress ring for stopwatch

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── mode toggle ──
            SegmentedButton<_TimerMode>(
              segments: const [
                ButtonSegment(
                  value: _TimerMode.countdown,
                  label: Text('Nedräkning'),
                  icon: Icon(Icons.hourglass_bottom_outlined, size: 16),
                ),
                ButtonSegment(
                  value: _TimerMode.stopwatch,
                  label: Text('Stoppur'),
                  icon: Icon(Icons.timer_outlined, size: 16),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => _switchMode(s.first),
            ),
            const SizedBox(height: 20),

            // ── clock face ──
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (progress != null)
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 6,
                        backgroundColor: cs.surfaceContainerHighest,
                        color: _finished ? cs.error : cs.primary,
                      ),
                    ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(_remainingSeconds),
                        style: TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w200,
                          color: _finished ? cs.error : cs.onSurface,
                          letterSpacing: 2,
                        ),
                      ),
                      if (_finished)
                        Text(
                          'Klar!',
                          style: TextStyle(color: cs.error, fontWeight: FontWeight.w600),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── set time (countdown only, only when stopped) ──
            if (isCountdown && !_running)
              _SetTimeRow(
                minutes: _setMinutes,
                seconds: _setSeconds,
                onChanged: (m, s) {
                  setState(() {
                    _setMinutes = m;
                    _setSeconds = s;
                    if (!_running) {
                      _remainingSeconds = m * 60 + s;
                      _finished = false;
                    }
                  });
                },
              ),

            const SizedBox(height: 16),

            // ── controls ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reset
                IconButton.outlined(
                  tooltip: 'Återställ',
                  onPressed: _reset,
                  icon: const Icon(Icons.replay),
                ),
                const SizedBox(width: 16),
                // Start / Pause
                FilledButton.icon(
                  onPressed: _running ? _pause : _start,
                  icon: Icon(_running ? Icons.pause : Icons.play_arrow),
                  label: Text(_running ? 'Pausa' : (_remainingSeconds == 0 && _mode == _TimerMode.countdown ? 'Starta om' : 'Starta')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A compact row of +/− steppers for setting minutes and seconds.
class _SetTimeRow extends StatelessWidget {
  const _SetTimeRow({
    required this.minutes,
    required this.seconds,
    required this.onChanged,
  });

  final int minutes;
  final int seconds;
  final void Function(int minutes, int seconds) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Stepper(
          label: 'min',
          value: minutes,
          onDecrement: minutes > 0 ? () => onChanged(minutes - 1, seconds) : null,
          onIncrement: minutes < 99 ? () => onChanged(minutes + 1, seconds) : null,
        ),
        const SizedBox(width: 8),
        Text(':', style: TextStyle(fontSize: 24, color: Theme.of(context).colorScheme.onSurface)),
        const SizedBox(width: 8),
        _Stepper(
          label: 'sek',
          value: seconds,
          onDecrement: seconds > 0 ? () => onChanged(minutes, seconds - 5 < 0 ? 0 : seconds - 5) : null,
          onIncrement: seconds < 55 ? () => onChanged(minutes, seconds + 5) : null,
        ),
      ],
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.onDecrement,
    required this.onIncrement,
  });

  final String label;
  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        Row(
          children: [
            IconButton(
              onPressed: onDecrement,
              icon: const Icon(Icons.remove, size: 18),
            ),
            SizedBox(
              width: 40,
              child: Text(
                value.toString().padLeft(2, '0'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w400),
              ),
            ),
            IconButton(
              onPressed: onIncrement,
              icon: const Icon(Icons.add, size: 18),
            ),
          ],
        ),
      ],
    );
  }
}
