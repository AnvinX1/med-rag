import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class TypewriterMarkdown extends StatefulWidget {
  final String text;
  final Duration duration;
  final VoidCallback? onComplete;

  const TypewriterMarkdown({
    super.key,
    required this.text,
    this.duration = const Duration(milliseconds: 30),
    this.onComplete,
  });

  @override
  State<TypewriterMarkdown> createState() => _TypewriterMarkdownState();
}

class _TypewriterMarkdownState extends State<TypewriterMarkdown> {
  String _displayedText = '';
  Timer? _timer;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _startAnimation();
  }

  @override
  void didUpdateWidget(TypewriterMarkdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _displayedText = '';
      _currentIndex = 0;
      _startAnimation();
    }
  }

  void _startAnimation() {
    _timer?.cancel();
    _timer = Timer.periodic(widget.duration, (timer) {
      if (_currentIndex < widget.text.length) {
        setState(() {
          _displayedText += widget.text[_currentIndex];
          _currentIndex++;
        });
      } else {
        _timer?.cancel();
        widget.onComplete?.call();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Determine if we should show the cursor
    final isComplete = _currentIndex >= widget.text.length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MarkdownBody(
          data: _displayedText,
          styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
            p: Theme.of(context).textTheme.bodyMedium?.copyWith(
              height: 1.5,
              fontSize: 14.5,
            ),
            h1: Theme.of(context).textTheme.headlineMedium?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0D9488), // Teal for headers
            ),
            h2: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF0F172A),
            ),
            h3: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            code: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              backgroundColor: const Color(0xFFF1F5F9),
              color: const Color(0xFF0F172A),
            ),
            codeblockDecoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            blockquoteDecoration: BoxDecoration(
              color: const Color(0xFFF0FDFA),
              borderRadius: BorderRadius.circular(4),
              border: Border(left: BorderSide(color: const Color(0xFF0D9488), width: 4)),
            ),
          ),
        ),
        if (!isComplete)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 8,
              height: 14,
              decoration: const BoxDecoration(
                color: Color(0xFF0D9488),
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
