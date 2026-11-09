import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Asks for a new 4-digit PIN, then asks again to confirm. A mismatch shows an
/// inline error and restarts at the first step. Returns the PIN or null.
Future<String?> showPinSetupDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _PinDialog(),
  );
}

class _PinDialog extends StatefulWidget {
  const _PinDialog();
  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _first;
  String? _error;

  bool get _confirming => _first != null;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _error = null);
    if (v.length < 4) return;
    if (!_confirming) {
      Future.delayed(const Duration(milliseconds: 140), () {
        if (!mounted) return;
        setState(() => _first = v);
        _controller.clear();
      });
    } else if (v == _first) {
      HapticFeedback.lightImpact();
      Navigator.pop(context, v);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _first = null;
        _error = 'The PINs didn\'t match. Enter a new one.';
      });
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final z = context.zap;
    final digits = _controller.text.length;

    return AlertDialog(
      title: AnimatedSwitcher(
        duration: ZapTheme.fast,
        child: Text(_confirming ? 'Enter it again' : 'Choose a 4-digit PIN', key: ValueKey(_confirming)),
      ),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          _confirming ? 'Confirm your PIN.' : 'You\'ll enter this PIN to stop the alarm.',
          style: TextStyle(fontSize: 14.5, color: z.inkMuted),
        ),
        const SizedBox(height: ZapTheme.space5),
        GestureDetector(
          onTap: () => _focus.requestFocus(),
          child: Stack(children: [
            // Hidden field drives input; the boxes below render it.
            Opacity(
              opacity: 0,
              child: SizedBox(
                height: 56,
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  showCursor: false,
                  enableInteractiveSelection: false,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                  onChanged: _onChanged,
                ),
              ),
            ),
            IgnorePointer(
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                for (var i = 0; i < 4; i++)
                  AnimatedContainer(
                    duration: ZapTheme.fast,
                    width: 52,
                    height: 56,
                    decoration: BoxDecoration(
                      color: z.surfaceHigh,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _error != null ? z.danger : (i == digits ? z.ink : Colors.transparent),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: AnimatedScale(
                        duration: ZapTheme.fast,
                        curve: Curves.easeOutBack,
                        scale: i < digits ? 1 : 0,
                        child: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(color: z.ink, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
        AnimatedSize(
          duration: ZapTheme.fast,
          child: _error == null
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: ZapTheme.space3),
                  child: Text(_error!, style: TextStyle(fontSize: ZapTheme.textSm, color: z.danger)),
                ),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(foregroundColor: z.inkMuted),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
