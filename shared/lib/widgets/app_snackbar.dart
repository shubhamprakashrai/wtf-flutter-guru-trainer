import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Spec section 8: "Error surfacing: Snackbars with human copy + a
/// 'Copy error' action." Success snackbars just show the message; error
/// snackbars additionally offer a working "Copy error" action that puts the
/// raw message on the clipboard for bug reports.
void showAppSnackBar(BuildContext context, {required String message, bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: isError ? const Color(0xFFD92D20) : const Color(0xFF12B76A),
    behavior: SnackBarBehavior.floating,
    action: isError
        ? SnackBarAction(
            label: 'Copy error',
            textColor: Colors.white,
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: message));
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Error copied to clipboard.'),
                behavior: SnackBarBehavior.floating,
              ));
            },
          )
        : null,
  ));
}
