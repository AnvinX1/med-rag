import 'package:flutter/material.dart';
import '../models.dart';
import '../services/api_service.dart';
import '../widgets/message_bubble.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/chat_drawer.dart';
import '../services/database_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _api = ApiService();
  final _db = DatabaseService();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  String? _currentSessionId;

  static const _suggestions = [
    'What are the symptoms of diabetes?',
    'Explain ACE inhibitors',
    'Heart failure treatment guidelines',
    'Mechanism of action of NSAIDs',
  ];

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _initSession();
  }

  Future<void> _initSession() async {
    final sessions = await _db.getSessions();
    if (sessions.isNotEmpty) {
      _currentSessionId = sessions.first.id;
      await _loadMessages(_currentSessionId!);
    } else {
      await _startNewChat();
    }
  }

  Future<void> _loadMessages(String sessionId) async {
    final messages = await _db.getMessages(sessionId);
    setState(() {
      _messages.clear();
      _messages.addAll(messages);
      _currentSessionId = sessionId;
    });
    if (_messages.isNotEmpty) {
      _scrollToBottom();
    }
  }

  Future<void> _startNewChat() async {
    final newId = await _db.createSession();
    setState(() {
      _currentSessionId = newId;
      _messages.clear();
      _isLoading = false;
      _controller.clear();
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().length < 3 || _isLoading) return;
    if (_currentSessionId == null) await _startNewChat();

    // Update title if first message
    if (_messages.isEmpty) {
      await _db.updateSessionTitle(_currentSessionId!, text.trim());
    }

    final userMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionId: _currentSessionId!,
      role: 'user',
      content: text.trim(),
    );

    setState(() {
      _messages.add(userMsg);
      _isLoading = true;
      _controller.clear();
    });
    _scrollToBottom();
    await _db.insertMessage(userMsg);

    try {
      final response = await _api.askQuestion(text.trim());
      final aiMsg = ChatMessage(
        id: '${DateTime.now().millisecondsSinceEpoch}_ai',
        sessionId: _currentSessionId!,
        role: 'assistant',
        content: response.answer,
        sources: response.sources,
        processingTime: response.processingTime,
      );

      setState(() {
        _messages.add(aiMsg);
      });
      await _db.insertMessage(aiMsg);
    } catch (e) {
      setState(() {
        _messages.add(
          ChatMessage(
            id: '${DateTime.now().millisecondsSinceEpoch}_err',
            sessionId: _currentSessionId!,
            role: 'assistant',
            content: 'Error: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        );
      });
    } finally {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: ChatDrawer(
        currentSessionId: _currentSessionId,
        onNewChat: _startNewChat,
        onSessionSelected: (sessionId) {
          _loadMessages(sessionId);
        },
      ),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.monitor_heart, color: cs.onPrimary, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Medical GenAI',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  'RAG-powered assistant',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined, size: 20),
            onPressed: _startNewChat,
            tooltip: 'New Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: _messages.isEmpty ? _buildWelcome(cs) : _buildMessageList(),
          ),
          // Input
          _buildInput(cs),
        ],
      ),
    );
  }

  Widget _buildWelcome(ColorScheme cs) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cs.primary.withAlpha(30),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.monitor_heart, size: 48, color: cs.primary),
            ),
            const SizedBox(height: 20),
            Text(
              'Medical GenAI Assistant',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ask questions about diabetes, cardiovascular diseases, pharmacology and more.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: cs.onSurface.withAlpha(150),
              ),
            ),
            const SizedBox(height: 28),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _suggestions
                  .map(
                    (s) => ActionChip(
                      label: Text(s, style: const TextStyle(fontSize: 12)),
                      avatar: Icon(
                        Icons.auto_awesome,
                        size: 14,
                        color: cs.primary,
                      ),
                      backgroundColor: cs.surfaceContainerHighest,
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      onPressed: () => _sendMessage(s),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: _messages.length + (_isLoading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _messages.length && _isLoading) {
          return const TypingIndicator();
        }
        return MessageBubble(message: _messages[index]);
      },
    );
  }

  Widget _buildInput(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant.withAlpha(50))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    maxLines: 3,
                    minLines: 1,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (v) => _sendMessage(v),
                    decoration: InputDecoration(
                      hintText: 'Ask a medical question...',
                      hintStyle: TextStyle(color: cs.onSurface.withAlpha(100)),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest.withAlpha(100),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FloatingActionButton.small(
                  onPressed: _isLoading
                      ? null
                      : () => _sendMessage(_controller.text),
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  elevation: 0,
                  child: _isLoading
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: cs.onPrimary,
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '⚠️ For educational purposes only. Not medical advice.',
              style: TextStyle(fontSize: 10, color: cs.onSurface.withAlpha(80)),
            ),
          ],
        ),
      ),
    );
  }
}
