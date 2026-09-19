import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/strings.dart';
import '../../core/journal/dictation.dart';
import '../../core/state/app_providers.dart';
import '../../core/theme/typography.dart';
import 'journal_actions.dart';
import 'entry_presentation.dart';
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
  bool _syncingController = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _dictation = widget.dictation ?? JournalDictation();
    final initialState = ref.read(journalSubmissionStateProvider);
    _controller = TextEditingController.fromValue(
      TextEditingValue(
        text: initialState.draftText,
        selection: TextSelection.collapsed(
          offset: initialState.cursorPosition.clamp(
            0,
            initialState.draftText.length,
          ),
        ),
      ),
    );
    _focus = FocusNode();

    // Check if a legacy draft was offered before mount
    final pendingLegacyDraft = ref.read(journalDraftProvider);
    if (pendingLegacyDraft != null) {
      _controller.text = pendingLegacyDraft.text;
      ref
          .read(journalSubmissionStateProvider.notifier)
          .setDraft(
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
    ref
        .read(journalSubmissionStateProvider.notifier)
        .setText(_controller.text, _controller.selection.baseOffset);
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
    if (text.isEmpty || ref.read(journalSubmissionStateProvider).isSubmitting) {
      return;
    }
    final actions = ref.read(journalActionsProvider);
    try {
      await actions.submit(text);
      if (!mounted) return;
      _controller.clear();
    } catch (_) {
      // JournalActions retains the draft and publishes the failure for retry.
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
    final saveError = subState.submitError ?? persistError;
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
      ref
          .read(journalSubmissionStateProvider.notifier)
          .setDraft(
            text: next.text,
            keepLocal: next.keepLocal,
            replacesEntryId: next.replacesEntryId,
            requestFocus: true,
          );
      _focus.requestFocus();
      ref.read(journalDraftProvider.notifier).clear();
    });

    // Listen to submission state changes from outside
    ref.listen<JournalSubmissionState>(journalSubmissionStateProvider, (
      prev,
      next,
    ) {
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

    final reduced = MediaQuery.disableAnimationsOf(context);
    final scale = MediaQuery.textScalerOf(context).scale(10) / 10;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedContainer(
          duration: Duration(milliseconds: reduced ? 0 : 160),
          height: 1,
          color: _focus.hasFocus || _listening
              ? Inks.warm.withValues(alpha: 0.7)
              : Inks.body,
        ),
        if (isEditing)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              'EDITING',
              style: Type.micro.copyWith(color: Inks.warm),
            ),
          ),
        SizedBox(
          height: JournalLayoutInputs.fieldHeight(scale),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  readOnly: subState.isSubmitting,
                  style: Type.body.copyWith(color: Inks.strong, height: 1.5),
                  cursorColor: Inks.warm,
                  cursorWidth: 1,
                  cursorOpacityAnimates: !reduced,
                  textInputAction: TextInputAction.done,
                  onSubmitted: _submit,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: isEditing ? 'Revise this line…' : S.journalHint,
                    hintStyle: Type.body.copyWith(color: Inks.body),
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: _listening ? 'Stop dictation' : 'Start dictation',
                child: GestureDetector(
                  key: const ValueKey('journal-mic'),
                  behavior: HitTestBehavior.opaque,
                  onTap: subState.isSubmitting ? null : _toggleMic,
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: CustomPaint(
                        size: const Size(14, 18),
                        painter: MicMark(_listening ? Inks.warm : Inks.body),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Row(
          children: [
            Flexible(
              child: Semantics(
                button: true,
                toggled: keepLocal,
                label: keepLocal ? 'Keep local enabled' : 'Keep local disabled',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: subState.isSubmitting
                      ? null
                      : () => ref
                            .read(journalActionsProvider)
                            .setKeepLocal(!keepLocal),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 44),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      widthFactor: 1,
                      child: Text(
                        keepLocal ? 'LOCAL ONLY' : S.keepLocal,
                        style: Type.label.copyWith(
                          color: keepLocal ? Inks.warm : Inks.body,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const Spacer(),
            if (isEditing)
              JournalWord(
                S.drop,
                faint: true,
                onTap: () {
                  if (subState.isSubmitting) return;
                  _controller.clear();
                  ref.read(journalActionsProvider).dropEdit();
                },
              ),
            Semantics(
              button: true,
              enabled:
                  subState.draftText.trim().isNotEmpty &&
                  !subState.isSubmitting,
              child: GestureDetector(
                key: const ValueKey('journal-save'),
                behavior: HitTestBehavior.opaque,
                onTap:
                    subState.draftText.trim().isEmpty || subState.isSubmitting
                    ? null
                    : () => _submit(_controller.text),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: 44,
                    minWidth: 44,
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    widthFactor: 1,
                    child: Text(
                      subState.isSubmitting ? 'SAVING' : 'SAVE',
                      style: Type.label.copyWith(
                        color: subState.draftText.trim().isEmpty
                            ? Inks.muted
                            : Inks.strong,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        if (saveError != null)
          Semantics(
            liveRegion: true,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4),
              child: Text(
                'NOT SAVED — $saveError',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Type.micro.copyWith(color: Inks.negative, height: 1.4),
              ),
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
