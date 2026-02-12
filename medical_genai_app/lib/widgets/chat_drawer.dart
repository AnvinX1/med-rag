import 'package:flutter/material.dart';

class ChatDrawer extends StatelessWidget {
  const ChatDrawer({super.key});

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
                    Navigator.pop(context);
                    // TODO: Implement New Chat logic
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
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildHistorySection(context, 'Today', [
                  'Diabetes Symptoms & Treatment',
                  'ACE Inhibitors Mechanism',
                ]),
                _buildHistorySection(context, 'Yesterday', [
                  'Hypertension Guidelines 2024',
                  'Pediatric Dosage Calculation',
                  'Antibiotic Resistance Patterns',
                ]),
                _buildHistorySection(context, 'Previous 7 Days', [
                  'Differential Diagnosis: Chest Pain',
                  'Metformin Side Effects',
                ]),
              ],
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
                Column(
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
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(
      BuildContext context, String title, List<String> items) {
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
        ...items.map((item) => ListTile(
              dense: true,
              visualDensity: VisualDensity.compact,
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: Icon(Icons.chat_bubble_outline_rounded,
                  size: 16, color: cs.onSurfaceVariant.withAlpha(150)),
              minLeadingWidth: 20,
              title: Text(
                item,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurface.withAlpha(200),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () {
                // TODO: Load chat history
              },
            )),
        const SizedBox(height: 12),
      ],
    );
  }
}
