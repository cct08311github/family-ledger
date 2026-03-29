import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../services/log_service.dart';

class DebugLogPage extends StatefulWidget {
  const DebugLogPage({super.key});

  @override
  State<DebugLogPage> createState() => _DebugLogPageState();
}

class _DebugLogPageState extends State<DebugLogPage> {
  LogTag? _filterTag;
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: '複製全部',
            onPressed: () {
              final text = LogService.instance.exportAll();
              Clipboard.setData(ClipboardData(text: text));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已複製到剪貼簿')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '清除',
            onPressed: () {
              LogService.instance.clear();
              setState(() {});
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Tag filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip(theme, null, '全部'),
                for (final tag in LogTag.values)
                  _buildFilterChip(theme, tag, tag.name),
              ],
            ),
          ),
          const Divider(height: 1),
          // Log list
          Expanded(
            child: StreamBuilder<List<LogEntry>>(
              stream: LogService.instance.stream,
              initialData: LogService.instance.entries,
              builder: (context, snapshot) {
                final allEntries = snapshot.data ?? [];
                final entries = _filterTag == null
                    ? allEntries
                    : allEntries.where((e) => e.tag == _filterTag).toList();

                if (entries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.terminal, size: 64,
                            color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                        const SizedBox(height: 16),
                        Text('尚無 Log 記錄', style: theme.textTheme.titleMedium),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  reverse: true,
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[entries.length - 1 - index];
                    return _buildLogTile(theme, entry);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(ThemeData theme, LogTag? tag, String label) {
    final selected = _filterTag == tag;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filterTag = tag),
      ),
    );
  }

  Widget _buildLogTile(ThemeData theme, LogEntry entry) {
    final (icon, color) = switch (entry.level) {
      LogLevel.error => (Icons.error_outline, theme.colorScheme.error),
      LogLevel.warning => (Icons.warning_amber, Colors.orange),
      LogLevel.info => (Icons.info_outline, theme.colorScheme.primary),
      LogLevel.debug => (Icons.bug_report_outlined, Colors.grey),
    };

    final time = DateFormat('HH:mm:ss').format(entry.timestamp);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(time,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontFamily: 'monospace',
                  fontSize: 11)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(entry.tag.name,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.message,
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace', fontSize: 12)),
                if (entry.error != null)
                  Text(entry.error!,
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 11,
                          color: theme.colorScheme.error)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
