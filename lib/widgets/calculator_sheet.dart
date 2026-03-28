import 'package:flutter/material.dart';

/// 簡易計算機 Bottom Sheet
/// 支援加減乘除，回傳計算結果
class CalculatorSheet extends StatefulWidget {
  final String initialValue;
  const CalculatorSheet({super.key, this.initialValue = ''});

  @override
  State<CalculatorSheet> createState() => _CalculatorSheetState();
}

class _CalculatorSheetState extends State<CalculatorSheet> {
  String _expression = '';
  String _result = '0';

  @override
  void initState() {
    super.initState();
    if (widget.initialValue.isNotEmpty) {
      _expression = widget.initialValue;
      _evaluate();
    }
  }

  void _onTap(String value) {
    setState(() {
      switch (value) {
        case 'C':
          _expression = '';
          _result = '0';
        case '⌫':
          if (_expression.isNotEmpty) {
            _expression = _expression.substring(0, _expression.length - 1);
            _evaluate();
          }
        case '=':
          _evaluate();
          if (_result != '錯誤') {
            Navigator.pop(context, _result);
          }
        default:
          // Prevent consecutive operators
          if (_isOperator(value) && _expression.isNotEmpty && _isOperator(_expression[_expression.length - 1])) {
            _expression = _expression.substring(0, _expression.length - 1) + value;
          } else {
            _expression += value;
          }
          _evaluate();
      }
    });
  }

  bool _isOperator(String c) => ['+', '-', '×', '÷'].contains(c);

  void _evaluate() {
    if (_expression.isEmpty) {
      _result = '0';
      return;
    }
    try {
      // Convert display operators to math operators
      final expr = _expression.replaceAll('×', '*').replaceAll('÷', '/');
      final value = _calculate(expr);
      if (value == value.roundToDouble()) {
        _result = value.round().toString();
      } else {
        _result = value.toStringAsFixed(2);
      }
    } catch (_) {
      // Don't show error while user is still typing
      if (!_isOperator(_expression[_expression.length - 1])) {
        _result = '錯誤';
      }
    }
  }

  /// Simple expression parser supporting +, -, *, /
  double _calculate(String expr) {
    // Tokenize
    final tokens = <String>[];
    var current = '';
    for (var i = 0; i < expr.length; i++) {
      final c = expr[i];
      if ('+-*/'.contains(c) && current.isNotEmpty) {
        tokens.add(current);
        tokens.add(c);
        current = '';
      } else {
        current += c;
      }
    }
    if (current.isNotEmpty) tokens.add(current);

    // Parse into numbers and operators
    final numbers = <double>[];
    final ops = <String>[];
    for (final t in tokens) {
      if ('+-*/'.contains(t)) {
        ops.add(t);
      } else {
        numbers.add(double.parse(t));
      }
    }

    // First pass: * and /
    var i = 0;
    while (i < ops.length) {
      if (ops[i] == '*' || ops[i] == '/') {
        final op = ops.removeAt(i);
        final right = numbers.removeAt(i + 1);
        numbers[i] = op == '*' ? numbers[i] * right : numbers[i] / right;
      } else {
        i++;
      }
    }

    // Second pass: + and -
    var result = numbers[0];
    for (i = 0; i < ops.length; i++) {
      result = ops[i] == '+' ? result + numbers[i + 1] : result - numbers[i + 1];
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(
              _expression.isEmpty ? '0' : _expression,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              'NT\$ $_result',
              style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
        const SizedBox(height: 12),
        // Buttons
        ..._buildButtonRows(theme),
      ]),
    );
  }

  List<Widget> _buildButtonRows(ThemeData theme) {
    final rows = [
      ['C', '⌫', '÷', '×'],
      ['7', '8', '9', '-'],
      ['4', '5', '6', '+'],
      ['1', '2', '3', '='],
      ['0'],
    ];

    return rows.map((row) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(children: row.map((btn) {
          final isOperator = ['÷', '×', '-', '+'].contains(btn);
          final isEquals = btn == '=';
          final isAction = btn == 'C' || btn == '⌫';
          final isZero = btn == '0';

          return Expanded(
            flex: isZero ? 3 : 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: () => _onTap(btn),
                  style: FilledButton.styleFrom(
                    backgroundColor: isEquals
                        ? theme.colorScheme.primary
                        : isOperator
                            ? theme.colorScheme.primaryContainer
                            : isAction
                                ? theme.colorScheme.errorContainer
                                : theme.colorScheme.surfaceContainerHighest,
                    foregroundColor: isEquals
                        ? theme.colorScheme.onPrimary
                        : isOperator
                            ? theme.colorScheme.onPrimaryContainer
                            : isAction
                                ? theme.colorScheme.onErrorContainer
                                : theme.colorScheme.onSurface,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(btn, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
          );
        }).toList()),
      );
    }).toList();
  }
}
