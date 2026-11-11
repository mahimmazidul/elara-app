import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens a web address, and says something useful when it cannot.
///
/// The old call sites asked `canLaunchUrl` first and showed "Could not open …"
/// when it said no. On Android 11 that question is answered from a list of
/// intents the app has declared it can *see*, and Elara had declared none — so
/// the answer was no for every address, on phones with three browsers installed.
/// The manifest now declares the two VIEW intents (see the `<queries>` block and
/// `check_link_visibility` in `tool/check_manifest.py`), and this no longer
/// asks: it tries, and treats a failure as a failure.
///
/// Falling back to the clipboard rather than to an error is the point. The
/// address is the thing the reader wanted; if no browser will take it, the next
/// best outcome is having it somewhere they can paste from, with a message that
/// says that is what happened.
Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  var opened = false;
  if (uri != null) {
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
  }
  if (opened || !context.mounted) return;

  await Clipboard.setData(ClipboardData(text: url));
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text(
        'No browser would take that link, so the address is on your clipboard.',
      ),
    ),
  );
}
