import 'package:flutter/material.dart';
import '../models.dart';
import '../services/database_service.dart';
import 'package:intl/intl.dart';

class ChatDrawer extends StatefulWidget {
  final VoidCallback onNewChat;
  final Function(String) onSessionSelected;
  final String? currentSessionId;

  const ChatDrawer({
    super.key,
    required this.onNewChat,
    required this.onSessionSelected,
    this.currentSessionId,
  });

  @override
  State<ChatDrawer> createState() => _ChatDrawerState();
}

class _ChatDrawerState extends State<ChatDrawer> {
  final _db = DatabaseService();
  late Future<List<ChatSession>> _sessionsFuture;

  @override
  void initState() {
    super.initState();
    _refreshSessions();
  }

  void _refreshSessions() {
    setState(() {
      _sessionsFuture = _db.getSessions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Drawer(
      backgroundColor: cs.surface,
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 16),
            decoration: BoxDecoration(
              color: cs.surfaceContainerLow,
              border: Border(bottom: BorderSide(color: cs.outlineVariant)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context); // Close drawer
                    widget.onNewChat(); // Trigger new chat
                  },
                  icon: const Icon(Icons.add_rounded, size: 20),
                  label: const Text('New Chat'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: cs.primary.withAlpha(50)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // History List
          Expanded(
            child: FutureBuilder<List<ChatSession>>(
              future: _sessionsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Text(
                      'No history yet',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  );
                }

                final sessions = snapshot.data!;
                final grouped = _groupSessions(sessions);

                return ListView(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  children: grouped.entries.map((entry) {
                    return _buildHistorySection(context, entry.key, entry.value);
                  }).toList(),
                );
              },
            ),
          ),

          // Footer (User Profile)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: cs.outlineVariant)),
              color: cs.surfaceContainerLow.withAlpha(100),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    'DR',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. User',
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Pro Plan',
                        style: textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
                  tooltip: 'Delete Session',
                  onPressed: widget.currentSessionId == null
                      ? null
                      : () async {
                          if (widget.currentSessionId != null) {
                            await _db.deleteSession(widget.currentSessionId!);
                            _refreshSessions();
                            widget.onNewChat(); // Reset to new chat
                            if (context.mounted) Navigator.pop(context);
                          }
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<ChatSession>> _groupSessions(List<ChatSession> sessions) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final lastWeek = today.subtract(const Duration(days: 7));

    final Map<String, List<ChatSession>> groups = {};

    for (var session in sessions) {
      final date = session.timestamp;
      final sessionDate = DateTime(date.year, date.month, date.day);

      String key;
      if (sessionDate == today || sessionDate.isAfter(today)) {
        key = 'Today';
      } else if (sessionDate == yesterday) {
        key = 'Yesterday';
      } else if (sessionDate.isAfter(lastWeek)) {
        key = 'Previous 7 Days';
      } else {
        key = 'Older';
      }

      groups.putIfAbsent(key, () => []).add(session);
    }
    return groups;
  }

  Widget _buildHistorySection(
      BuildContext context, String title, List<ChatSession> items) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.calendar_today_outlined,
                  size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        ...items.map((session) {
          final isSelected = session.id == widget.currentSessionId;
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
            selected: isSelected,
            selectedTileColor: cs.primaryContainer.withAlpha(50),
            leading: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 16,
              color: isSelected ? cs.primary : cs.onSurfaceVariant.withAlpha(150),
            ),
            minLeadingWidth: 20,
            title: Text(
              session.title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? cs.primary : cs.onSurface.withAlpha(200),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () {
              Navigator.pop(context);
              widget.onSessionSelected(session.id);
            },
            trailing: isSelected
                ? Icon(Icons.check, size: 14, color: cs.primary)
                : null,
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }
}
