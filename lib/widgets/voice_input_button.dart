import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

/// 語音輸入按鈕 — 按住說話，放開停止
class VoiceInputButton extends StatefulWidget {
  final void Function(String text) onResult;
  final void Function(String error)? onError;

  const VoiceInputButton({
    super.key,
    required this.onResult,
    this.onError,
  });

  @override
  State<VoiceInputButton> createState() => _VoiceInputButtonState();
}

class _VoiceInputButtonState extends State<VoiceInputButton>
    with SingleTickerProviderStateMixin {
  final _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isAvailable = false;
  String _currentText = '';
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    _isAvailable = await _speech.initialize(
      onError: (error) {
        setState(() => _isListening = false);
        _pulseController.stop();
        if (error.errorMsg == 'error_no_match' && _currentText.isNotEmpty) {
          widget.onResult(_currentText);
        } else if (error.errorMsg != 'error_no_match') {
          widget.onError?.call('語音辨識錯誤：${error.errorMsg}');
        }
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _startListening() async {
    if (!_isAvailable) {
      widget.onError?.call('語音辨識不可用');
      return;
    }

    _currentText = '';
    setState(() => _isListening = true);
    _pulseController.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) {
        _currentText = result.recognizedWords;
        if (result.finalResult && _currentText.isNotEmpty) {
          _stopListening();
          widget.onResult(_currentText);
        }
      },
      localeId: 'zh_TW',
      listenMode: stt.ListenMode.dictation,
    );
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    _pulseController.stop();
    _pulseController.reset();
    if (mounted) setState(() => _isListening = false);
  }

  @override
  void dispose() {
    _speech.stop();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final scale = _isListening ? 1.0 + _pulseController.value * 0.15 : 1.0;
        return Transform.scale(
          scale: scale,
          child: FloatingActionButton.small(
            heroTag: 'voice_input',
            onPressed: _isListening ? _stopListening : _startListening,
            backgroundColor: _isListening
                ? theme.colorScheme.error
                : theme.colorScheme.primaryContainer,
            foregroundColor: _isListening
                ? theme.colorScheme.onError
                : theme.colorScheme.onPrimaryContainer,
            child: Icon(_isListening ? Icons.stop : Icons.mic),
          ),
        );
      },
    );
  }
}
