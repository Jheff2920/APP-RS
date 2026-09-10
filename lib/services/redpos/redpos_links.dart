import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openRedPosLink(BuildContext context, Uri uri) async {
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (ok || !context.mounted) return;
  } catch (_) {}
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text('No se pudo abrir ${uri.toString()}')),
  );
}
