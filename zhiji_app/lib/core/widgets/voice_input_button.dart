import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

/// 语音输入按钮
/// 按住说话，松手后语音转文字追加到输入框
class VoiceInputButton extends StatefulWidget {
  const VoiceInputButton({
    super.key,
    required this.onTextReady,
    this.size = 40,
  });

  /// 语音识别完成后的回调，传入识别出的文本
  final ValueChanged<String> onTextReady;
  final double size;

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton> {
  late final stt.SpeechToText _speech;
  bool _isListening = false;
  bool _available = false;

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    final available = await _speech.initialize(
      onStatus: (_) {},
      onError: (_) {},
    );
    if (mounted) setState(() => _available = available);
  }

  Future<void> _toggleListening() async {
    // 捕获 messenger 引用，避免跨越 async 使用 context
    final messenger = ScaffoldMessenger.of(context);
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('需要麦克风权限才能使用语音输入')),
      );
      return;
    }
    if (!_available) {
      messenger.showSnackBar(
        const SnackBar(content: Text('语音识别不可用，请检查权限')),
      );
      return;
    }
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      setState(() => _isListening = true);
      // ignore: deprecated_member_use
      await _speech.listen(
        onResult: (result) {
          if (result.finalResult) {
            widget.onTextReady(result.recognizedWords);
            setState(() => _isListening = false);
          }
        },
        localeId: 'zh_CN',
      );
    }
  }

  @override
  void dispose() {
    _speech.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _toggleListening,
          child: Container(
            width: widget.size,
            height: widget.size,
            decoration: BoxDecoration(
              color: _isListening ? cs.error : cs.primaryContainer,
              shape: BoxShape.circle,
              border: _isListening
                  ? Border.all(color: cs.error, width: 3)
                  : null,
            ),
            child: Icon(
              _isListening ? Icons.mic : Icons.mic_none,
              size: widget.size * 0.5,
              color: _isListening ? cs.error : cs.primary,
            ),
          ),
        ),
        if (_isListening)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '正在聆听…',
              style: TextStyle(fontSize: 10, color: cs.error),
            ),
          ),
      ],
    );
  }
}
