import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/journal/dictation.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/theme/typography.dart';
import 'journal_actions.dart';
import 'journal_layout.dart';
import 'journal_presentation_model.dart';

/// The journal input writing line. The writing line is the capture; the list is the record.
class JournalWritingLine extends ConsumerStatefulWidget {
  const JournalWritingLine({super.key, this.dictation});

  /// Optional dictation instance for testing / fallback injection.
  final JournalDictation? dictation;

  /// Space the pager leaves above the surface switch for this line.
  static const double band = JournalLayoutInputs.writingLineBand;

  @override
  ConsumerState<JournalWritingLine> createState() => _JournalWritingLineState();
}

class _JournalWritingLineState extends ConsumerState<JournalWritingLine>
    with AutomaticKeepAliveClientMixin {
  late final TextEditingController _controller;
  late final FocusNode _focus;
  late final JournalDictation _dictation;
  var _listening = false;
  String _spokenBase = '';
  String? _submitError;
  bool _syncingController = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dictation = widget.dictation ?? JournalDictation();
    final initialState = ref.read(journalSubmissionStateProvider);
    _controller = TextEditingController(text: initialState.draftText);
    _submitError = initialState.submitError;
    _focus = FocusNode();

    // Check if a legacy draft was offered before mount
    final pendingLegacyDraft = ref.read(journalDraftProvider);
    if (pendingLegacyDraft != null) {
      _controller.text = pendingLegacyDraft.text;
      ref.read(journalSubmissionStateProvider.notifier).setDraft(
        text: pendingLegacyDraft.text,
        keepLocal: pendingLegacyDraft.keepLocal,
        replacesEntryId: pendingLegacyDraft.replacesEntryId,
        requestFocus: true,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focus.requestFocus();
          ref.read(journalDraftProvider.notifier).clear();
        }
      });
    } else if (initialState.isFocused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }

    _controller.addListener(_onTextChanged);
    _focus.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    if (_syncingController) return;
    ref.read(journalSubmissionStateProvider.notifier).setText(
      _controller.text,
      _controller.selection.baseOffset,
    );
  }

  void _onFocusChanged() {
    ref.read(journalSubmissionStateProvider.notifier).setFocus(_focus.hasFocus);
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _focus.removeListener(_onFocusChanged);
    _dictation.cancel();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit(String raw) async {
    final text = raw.trim();
    if (text.isEmpty) return;
    final actions = ref.read(journalActionsProvider);
    try {
      await actions.submit(text);
      if (!mounted) return;
      _controller.clear();
      setState(() => _submitError = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitError = e.toString());
    }
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      await _dictation.stop();
      if (mounted) {
        setState(() => _listening = false);
        ref.read(journalSubmissionStateProvider.notifier).setListening(false);
      }
      return;
    }
    _spokenBase = _controller.text.trimRight();
    final ok = await _dictation.start(
      onWords: (words, _) {
        if (!mounted) return;
        final spacer = _spokenBase.isEmpty || words.isEmpty ? '' : ' ';
        final text = '$_spokenBase$spacer$words';
        _controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      },
      onDone: () {
        if (mounted) {
          setState(() => _listening = false);
          ref.read(journalSubmissionStateProvider.notifier).setListening(false);
        }
      },
    );
    if (!mounted) return;
    if (!ok) {
      _focus.requestFocus();
      return;
    }
    setState(() => _listening = true);
    ref.read(journalSubmissionStateProvider.notifier).setListening(true);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    ref.watch(storeRevisionProvider);
    final persistError = ref.watch(storeProvider).lastPersistenceError;
    final subState = ref.watch(journalSubmissionStateProvider);
    final saveError = _submitError ?? subState.submitError ?? persistError;
    final keepLocal = subState.keepLocal;
    final isEditing = subState.replacesEntryId != null;

    // Listen to legacy journalDraftProvider
    ref.listen<JournalDraft?>(journalDraftProvider, (prev, next) {
      if (next == null) return;
      _syncingController = true;
      _controller.value = TextEditingValue(
        text: next.text,
        selection: TextSelection.collapsed(offset: next.text.length),
      );
      _syncingController = false;
      ref.read(journalSubmissionStateProvider.notifier).setDraft(
        text: next.text,
        keepLocal: next.keepLocal,
        replacesEntryId: next.replacesEntryId,
        requestFocus: true,
      );
      _focus.requestFocus();
      ref.read(journalDraftProvider.notifier).clear();
    });

    // Listen to submission state changes from outside
    ref.listen<JournalSubmissionState>(journalSubmissionStateProvider, (prev, next) {
      if (next.draftText != _controller.text) {
        _syncingController = true;
        _controller.value = TextEditingValue(
          text: next.draftText,
          selection: TextSelection.collapsed(offset: next.draftText.length),
        );
        _syncingController = false;
      }
      if (next.isFocused && !_focus.hasFocus) {
        _focus.requestFocus();
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isEditing)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              children: [
                Text('EDITING', style: Type.micro.copyWith(color: Inks.muted)),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    _controller.clear();
                    ref.read(journalActionsProvider).dropEdit();
                  },
                  child: Text(
                    S.drop,
                    style: Type.micro.copyWith(color: Inks.faint),
                  ),
                ),
              ],
            ),
          ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                style: Type.body.copyWith(color: Inks.strong),
                cursorColor: Inks.strong,
                textInputAction: TextInputAction.done,
                onSubmitted: _submit,
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: S.journalHint,
                  hintStyle: Type.body.copyWith(color: Inks.muted),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: keepLocal ? 'Keep local enabled' : 'Keep local disabled',
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  ref.read(journalActionsProvider).setKeepLocal(!keepLocal);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  child: Text(
                    keepLocal ? '[ LOCAL ]' : S.keepLocal,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.fade,
                    style: Type.label.copyWith(
                      color: keepLocal ? Inks.warm : Inks.faint,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Semantics(
              button: true,
              label: _listening ? 'Stop dictation' : 'Start dictation',
              child: GestureDetector(
                key: const ValueKey('journal-mic'),
                behavior: HitTestBehavior.opaque,
                onTap: _toggleMic,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 8, 0, 8),
                  child: CustomPaint(
                    size: const Size(14, 18),
                    painter: MicMark(_listening ? Inks.warm : Inks.body),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          height: Space.hairline,
          color: Inks.full.withValues(alpha: 0.4),
        ),
        if (saveError != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'NOT SAVED — $saveError',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Type.micro.copyWith(color: Inks.negative),
            ),
          ),
      ],
    );
  }
}

class MicMark extends CustomPainter {
  const MicMark(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.3, 0, w * 0.4, h * 0.55),
        Radius.circular(w * 0.2),
      ),
      p,
    );
    final path = Path()
      ..moveTo(w * 0.08, h * 0.42)
      ..arcToPoint(
        Offset(w * 0.92, h * 0.42),
        radius: Radius.circular(w * 0.45),
        clockwise: false,
      );
    canvas.drawPath(path, p);
    canvas.drawLine(Offset(w / 2, h * 0.78), Offset(w / 2, h), p);
  }

  @override
  bool shouldRepaint(MicMark old) => old.color != color;
}
