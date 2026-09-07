import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Device speech into the journal writing line. Logging stays on the
/// keyboard if the recognizer is missing, denied, or this platform
/// cannot listen.
class JournalDictation {
  JournalDictation({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;
  var _ready = false;

  bool get isListening => _speech.isListening;

  Future<bool> start({
    required void Function(String words, bool finalResult) onWords,
    required VoidCallback onDone,
  }) async {
    if (_speech.isListening) {
      await stop();
      return false;
    }
    try {
      if (!_ready) {
        final options = defaultTargetPlatform == TargetPlatform.android
            ? [
                SpeechToText.androidIntentLookup,
                SpeechToText.androidNoBluetooth,
              ]
            : <SpeechConfigOption>[];
        _ready = await _speech.initialize(
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') onDone();
          },
          onError: (_) => onDone(),
          options: options,
        );
      }
      if (!_ready) return false;
      await _speech.listen(
        onResult: (result) =>
            onWords(result.recognizedWords, result.finalResult),
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          partialResults: true,
          listenFor: const Duration(seconds: 28),
          pauseFor: const Duration(seconds: 3),
        ),
      );
      return true;
    } catch (_) {
      _ready = false;
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _speech.stop();
    } catch (_) {}
  }

  Future<void> cancel() async {
    try {
      await _speech.cancel();
    } catch (_) {}
  }
}
