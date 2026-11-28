import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

/// A modal bottom sheet calculator. Shows a standard numeric pad with basic
/// arithmetic. The "Insert" button pastes the current display value into the
/// Quill document at the current cursor position.
class CalculatorSheet extends StatefulWidget {
  const CalculatorSheet({super.key, required this.controller});

  final QuillController controller;

  @override
  State<CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<CalculatorSheet> {
  /// What is shown in the display area.
  String _display = '0';

  /// The accumulated left-hand operand (as a string to avoid precision loss
  /// during building).
  double? _operand;

  /// The pending operator: '+', '-', '×', '÷'.
  String? _operator;

  /// True if the next digit press should start a fresh number.
  bool _awaitingOperand = false;

  // ── input handlers ──────────────────────────────────────────────────────

  void _onDigit(String d) {
    setState(() {
      if (_awaitingOperand) {
        _display = d;
        _awaitingOperand = false;
      } else {
        _display = _display == '0' ? d : _display + d;
      }
    });
  }

  void _onDot() {
    setState(() {
      if (_awaitingOperand) {
        _display = '0.';
        _awaitingOperand = false;
        return;
      }
      if (!_display.contains('.')) _display += '.';
    });
  }

  void _onOperator(String op) {
    _evaluate();
    setState(() {
      _operand = double.tryParse(_display);
      _operator = op;
      _awaitingOperand = true;
    });
  }

  void _evaluate() {
    if (_operator == null || _operand == null || _awaitingOperand) return;
    final right = double.tryParse(_display) ?? 0;
    double result;
    switch (_operator) {
      case '+':
        result = _operand! + right;
      case '-':
        result = _operand! - right;
      case '×':
        result = _operand! * right;
      case '÷':
        result = right == 0 ? double.nan : _operand! / right;
      default:
        return;
    }
    setState(() {
      _display = _formatResult(result);
      _operand = null;
      _operator = null;
      _awaitingOperand = true;
    });
  }

  void _onEquals() => _evaluate();

  void _onClear() {
    setState(() {
      _display = '0';
      _operand = null;
      _operator = null;
      _awaitingOperand = false;
    });
  }

  void _onBackspace() {
    if (_awaitingOperand) return;
    setState(() {
      _display = _display.length <= 1 ? '0' : _display.substring(0, _display.length - 1);
    });
  }

  void _onToggleSign() {
    setState(() {
      final v = double.tryParse(_display) ?? 0;
      _display = _formatResult(-v);
    });
  }

  void _onPercent() {
    setState(() {
      final v = double.tryParse(_display) ?? 0;
      _display = _formatResult(v / 100);
    });
  }

  String _formatResult(double v) {
    if (v.isNaN) return 'Error';
    if (v.isInfinite) return 'Error';
    // Show as integer if there's no fractional part.
    if (v == v.truncateToDouble() && !v.isInfinite) {
      return v.toInt().toString();
    }
    // Up to 10 significant digits, remove trailing zeros.
    final s = v.toStringAsPrecision(10);
    if (s.contains('.')) {
      return s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return s;
  }

  // ── insert into note ─────────────────────────────────────────────────────

  void _insertResult(BuildContext context) {
    final text = _display;
    if (text == 'Error') return;
    final ctrl = widget.controller;
    final sel = ctrl.selection;
    final offset = sel.isValid ? sel.baseOffset : ctrl.document.length - 1;
    ctrl.replaceText(offset, 0, text, TextSelection.collapsed(offset: offset + text.length));
    Navigator.of(context).pop();
  }

  // ── UI ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bool hasOperator = _operator != null;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── display ──
            Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (hasOperator)
                    Text(
                      '${_formatResult(_operand!)} $_operator',
                      style: TextStyle(fontSize: 13, color: cs.onSurface.withValues(alpha: 0.5)),
                    ),
                  Text(
                    _display,
                    style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w300),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            const SizedBox(height: 8),
            // ── button grid ──
            _buildGrid(cs),
            const SizedBox(height: 8),
            // ── insert button ──
            FilledButton.icon(
              onPressed: _display == 'Error' ? null : () => _insertResult(context),
              icon: const Icon(Icons.keyboard_return, size: 18),
              label: const Text('Infoga i anteckning'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(ColorScheme cs) {
    // Row layout: [label, onTap, style]
    // Styles: 'num' | 'op' | 'eq' | 'fn'
    final rows = [
      [('C', _onClear, 'fn'), ('±', _onToggleSign, 'fn'), ('%', _onPercent, 'fn'), ('÷', () => _onOperator('÷'), 'op')],
      [('7', () => _onDigit('7'), 'num'), ('8', () => _onDigit('8'), 'num'), ('9', () => _onDigit('9'), 'num'), ('×', () => _onOperator('×'), 'op')],
      [('4', () => _onDigit('4'), 'num'), ('5', () => _onDigit('5'), 'num'), ('6', () => _onDigit('6'), 'num'), ('−', () => _onOperator('-'), 'op')],
      [('1', () => _onDigit('1'), 'num'), ('2', () => _onDigit('2'), 'num'), ('3', () => _onDigit('3'), 'num'), ('+', () => _onOperator('+'), 'op')],
      [('⌫', _onBackspace, 'fn'), ('0', () => _onDigit('0'), 'num'), ('.', _onDot, 'num'), ('=', _onEquals, 'eq')],
    ];

    return Column(
      children: rows.map((row) {
        return Row(
          children: row.map((cell) {
            final label = cell.$1 as String;
            final onTap = cell.$2 as VoidCallback;
            final style = cell.$3 as String;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: _CalcButton(
                  label: label,
                  onTap: onTap,
                  style: style,
                  colorScheme: cs,
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _CalcButton extends StatelessWidget {
  const _CalcButton({
    required this.label,
    required this.onTap,
    required this.style,
    required this.colorScheme,
  });

  final String label;
  final VoidCallback onTap;
  final String style; // 'num' | 'op' | 'eq' | 'fn'
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    final cs = colorScheme;
    Color bg;
    Color fg;
    switch (style) {
      case 'op':
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
      case 'eq':
        bg = cs.primary;
        fg = cs.onPrimary;
      case 'fn':
        bg = cs.surfaceContainerHighest;
        fg = cs.onSurface;
      default: // num
        bg = cs.surfaceContainerLow;
        fg = cs.onSurface;
    }

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: SizedBox(
          height: 52,
          child: Center(
            child: Text(
              label,
              style: TextStyle(fontSize: 20, color: fg, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }
}
