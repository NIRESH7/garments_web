import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/mobile_api_service.dart';
import '../../core/theme/color_palette.dart';

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
  bool _isTtsEnabled = true;

  final List<Map<String, dynamic>> _messages = [
    {
      'text': 'Hello! I am your Om Vinayaka AI Assistant. Ask me anything about your business data.',
      'isMe': false,
    }
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
    if (_isTamil) {
      await _flutterTts.setLanguage("ta-IN");
    } else {
      await _flutterTts.setLanguage("en-US");
    }
    await _flutterTts.speak(text);
  }

  void _startListening() async {
    if (!_speechEnabled) return;
    String localeId = _isTamil ? "ta_IN" : "en_US";
    await _speechToText.listen(
      onResult: (result) {
        setState(() {
          _messageController.text = result.recognizedWords;
        });
      },
      localeId: localeId,
    );
    setState(() => _isListening = true);
  }

  void _stopListening() async {
    await _speechToText.stop();
    setState(() => _isListening = false);
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'text': text, 'isMe': true});
      _messageController.clear();
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final response = await _api.chatWithAI(text, language: _isTamil ? 'ta' : 'en');
      final aiText = response['text'] ?? 'No response';
      
      setState(() {
        _messages.add({'text': aiText, 'isMe': false});
        _isLoading = false;
      });
      _scrollToBottom();
      _speak(aiText);
    } catch (e) {
      setState(() {
        _messages.add({'text': 'Error: Failed to get response.', 'isMe': false});
        _isLoading = false;
      });
    }
  }

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
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          Row(
            children: [
              const Text('TA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              Switch(
                value: _isTamil,
                onChanged: (val) {
                  setState(() => _isTamil = val);
                  _initSpeech(); // Re-init with locale if needed
                },
                activeColor: primaryColor,
              ),
            ],
          ),
          IconButton(
            icon: Icon(_isTtsEnabled ? LucideIcons.volume2 : LucideIcons.volumeX),
            onPressed: () => setState(() => _isTtsEnabled = !_isTtsEnabled),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _buildMessage(msg);
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            ),
          _buildInputBar(primaryColor),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> msg) {
    final isMe = msg['isMe'] ?? false;
    final primaryColor = Theme.of(context).primaryColor;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20).copyWith(
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(20),
            bottomLeft: isMe ? const Radius.circular(20) : const Radius.circular(0),
          ),
        ),
        child: Text(
          msg['text'],
          style: TextStyle(
            color: isMe ? Colors.white : Colors.black87,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isListening ? LucideIcons.mic : LucideIcons.micOff,
              color: _isListening ? Colors.red : Colors.grey,
            ),
            onPressed: _isListening ? _stopListening : _startListening,
          ),
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: _isTamil ? 'கேளுங்கள்...' : 'Ask me anything...',
                border: InputBorder.none,
                filled: false,
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(LucideIcons.send),
            color: primaryColor,
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
