import 'package:flutter/material.dart';

/// 成員大頭貼 Widget（圓形，帶首字母）
class MemberAvatar extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final double size;
  final bool showBorder;
  final Color? borderColor;

  const MemberAvatar({
    super.key,
    required this.name,
    this.avatarUrl,
    this.size = 40,
    this.showBorder = false,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initial = name.isNotEmpty ? name.characters.first : '?';
    final color = _colorFromName(name);

    Widget avatar;
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(avatarUrl!),
      );
    } else {
      avatar = CircleAvatar(
        radius: size / 2,
        backgroundColor: color.withValues(alpha: 0.2),
        child: Text(
          initial,
          style: TextStyle(
            color: color,
            fontSize: size * 0.4,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (showBorder) {
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: borderColor ?? theme.colorScheme.primary,
            width: 2.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: avatar,
        ),
      );
    }

    return avatar;
  }

  /// 根據名稱產生一致的顏色
  static Color _colorFromName(String name) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.amber,
      Colors.cyan,
    ];
    final hash = name.codeUnits.fold(0, (prev, c) => prev + c);
    return colors[hash % colors.length];
  }
}
