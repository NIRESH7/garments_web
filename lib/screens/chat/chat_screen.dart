import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/mobile_api_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final SpeechToText _speechToText = SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final _api = MobileApiService();

  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isLoading = false;
  bool _isTamil = false;
  bool _isTtsEnabled = false;

  final List<Map<String, dynamic>> _messages = [
    {
      'text': 'Hello! I am your Om Vinayaka Assistant. I can help you with product details, stock reports, and production status. Try asking "List all shirts" or "Show prices".',
      'isMe': false,
    }
  ];

  final List<String> _suggestions = [
    'Show all products',
    'List all shirts',
    'List all pants',
    'Check prices',
    'Current Stock',
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initTts();
  }

  void _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize();
      setState(() {});
    } catch (e) {
      debugPrint('Speech init error: $e');
    }
  }

  void _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    if (!_isTtsEnabled) return;
    await _flutterTts.setLanguage(_isTamil ? "ta-IN" : "en-US");
    await _flutterTts.speak(text);
  }

  void _startListening() async {
    if (!_speechEnabled) return;
    await _speechToText.listen(
      onResult: (result) => setState(() => _messageController.text = result.recognizedWords),
      localeId: _isTamil ? "ta_IN" : "en_US",
    );
    setState(() => _isListening = true);
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  void _sendMessage({String? customText}) async {
    final text = customText ?? _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      if (customText == null) _messageController.clear();
      _messages.add({'text': text, 'isMe': true});
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await _api.chatWithAI(text, language: _isTamil ? 'ta' : 'en');
      final aiText = response['text'] ?? 'I couldn\'t process that request.';
      
      setState(() {
        _messages.add({
          'text': aiText, 
          'isMe': false,
          'data': response['data'],
        });
        _isLoading = false;
      });
      _scrollToBottom();
      if (_isTtsEnabled) _speak(aiText);
    } catch (e) {
      setState(() {
        _messages.add({'text': 'Connectivity issue. Please try again.', 'isMe': false});
        _isLoading = false;
      });
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, color: Color(0xFF0F172A), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'AI ASSISTANT',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            letterSpacing: 1.2,
            color: const Color(0xFF0F172A),
          ),
        ),
        actions: [
          _buildLanguageToggle(primaryColor),
          IconButton(
            icon: Icon(_isTtsEnabled ? LucideIcons.volume2 : LucideIcons.volumeX, size: 18, color: const Color(0xFF64748B)),
            onPressed: () => setState(() => _isTtsEnabled = !_isTtsEnabled),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg, primaryColor);
              },
            ),
          ),
          if (_isLoading)
            _buildLoadingIndicator(primaryColor),
          if (_messages.length < 3 && !_isLoading)
            _buildSuggestions(),
          _buildInputArea(primaryColor),
        ],
      ),
    );
  }

  Widget _buildLanguageToggle(Color primaryColor) {
    return GestureDetector(
      onTap: () => setState(() => _isTamil = !_isTamil),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Text(
              _isTamil ? 'தமிழ்' : 'English',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF475569)),
            ),
            const SizedBox(width: 4),
            Icon(LucideIcons.languages, size: 12, color: primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, Color primaryColor) {
    final isMe = msg['isMe'] ?? false;
    final data = msg['data'] as List?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!isMe)
                Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8, bottom: 4),
                  decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                  child: Center(child: Icon(LucideIcons.bot, size: 14, color: primaryColor)),
                ),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isMe ? primaryColor : Colors.white,
                    borderRadius: BorderRadius.circular(16).copyWith(
                      bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
                      bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                    border: isMe ? null : Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    msg['text'],
                    style: GoogleFonts.inter(
                      color: isMe ? Colors.white : const Color(0xFF1E293B),
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (data != null && data.isNotEmpty)
            _buildDataDisplay(data, primaryColor),
        ],
      ),
    );
  }

  Widget _buildDataDisplay(List data, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(top: 12, left: 36),
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: data.length,
        itemBuilder: (context, i) {
          final item = data[i];
          return Container(
            width: 200,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: primaryColor.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'] ?? 'Item',
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const Spacer(),
                Text(
                  '₹${item['price'] ?? 0}',
                  style: GoogleFonts.outfit(fontWeight: FontWeight.w800, color: primaryColor, fontSize: 16),
                ),
                Text(
                  item['category'] ?? '',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      height: 40,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _suggestions.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ActionChip(
            label: Text(_suggestions[i], style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600)),
            backgroundColor: Colors.white,
            side: const BorderSide(color: Color(0xFFE2E8F0)),
            onPressed: () => _sendMessage(customText: _suggestions[i]),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
          ),
          const SizedBox(width: 8),
          Text(
            'Analyzing database...',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              icon: Icon(_isListening ? LucideIcons.mic : LucideIcons.micOff, size: 20, color: _isListening ? Colors.red : const Color(0xFF64748B)),
              onPressed: _isListening ? _stopListening : _startListening,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
              child: TextField(
                controller: _messageController,
                style: GoogleFonts.inter(fontSize: 14),
                decoration: InputDecoration(
                  hintText: _isTamil ? 'கேளுங்கள்...' : 'Type your message...',
                  border: InputBorder.none,
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(12)),
            child: IconButton(
              icon: const Icon(LucideIcons.send, color: Colors.white, size: 20),
              onPressed: _sendMessage,
            ),
          ),
        ],
      ),
    );
  }
}
