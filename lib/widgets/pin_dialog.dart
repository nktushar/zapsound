import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Asks for a new 4-digit PIN with confirmation. Returns the PIN or null.
Future<String?> showPinSetupDialog(BuildContext context) async {
  final first = await _askPin(context, 'Set anti-theft PIN', 'You\'ll need this PIN to stop the alarm');
  if (first == null) return null;
  if (!context.mounted) return null;
  final second = await _askPin(context, 'Confirm PIN', 'Enter the same 4 digits again');
  if (second == null) return null;
  if (first != second) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PINs didn\'t match — try again.')),
      );
    }
    return null;
  }
  return first;
}

Future<String?> _askPin(BuildContext context, String title, String subtitle) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: ZapTheme.textLg, fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(subtitle, style: const TextStyle(fontSize: ZapTheme.textSm, color: ZapColors.textSecondary)),
        const SizedBox(height: ZapTheme.space4),
        TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.w700),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: const InputDecoration(counterText: ''),
          onSubmitted: (v) {
            if (v.length == 4) Navigator.pop(ctx, v);
          },
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () {
            if (controller.text.length == 4) Navigator.pop(ctx, controller.text);
          },
          child: const Text('OK', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ),
  );
}
