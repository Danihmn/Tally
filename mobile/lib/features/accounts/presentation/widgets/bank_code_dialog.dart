import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mobile/l10n/app_localizations.dart';

/// Asks the COMPE code (3 digits) of the bank of a salary account. Returns the
/// code, or `null` when the person cancels.
Future<String?> showBankCodeDialog(BuildContext context, {String? initial}) =>
    showDialog<String>(
      context: context,
      builder: (context) => _BankCodeDialog(initial: initial),
    );

class _BankCodeDialog extends StatefulWidget {
  const _BankCodeDialog({required this.initial});

  final String? initial;

  @override
  State<_BankCodeDialog> createState() => _BankCodeDialogState();
}

class _BankCodeDialogState extends State<_BankCodeDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initial ?? '',
  );

  bool get _valid => RegExp(r'^\d{3}$').hasMatch(_controller.text);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_valid) Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.bankCodeDialogTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.bankCodeDialogText),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 3,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(labelText: l10n.bankCodeDialogLabel),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _confirm(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.bankCodeDialogCancel),
        ),
        FilledButton(
          onPressed: _valid ? _confirm : null,
          child: Text(l10n.bankCodeDialogConfirm),
        ),
      ],
    );
  }
}
